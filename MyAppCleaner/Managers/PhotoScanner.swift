import Foundation
import Photos
import Observation
import Vision

struct AssetGroup: Identifiable {
    let id = UUID()
    var assets: [PHAsset]
    var bestAsset: PHAsset?
}

@Observable
class PhotoScanner {
    var screenshots: [PHAsset] = []
    var largeVideos: [PHAsset] = []
    var similarPhotoGroups: [AssetGroup] = []
    var isScanning = false
    
    func scanAll() async {
        await MainActor.run { isScanning = true }
        
        await scanScreenshots()
        await scanLargeVideos()
        await scanSimilarPhotos()
        
        await MainActor.run { isScanning = false }
    }
    
    func scanScreenshots() async {
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if let screenshotAlbum = smartAlbums.firstObject {
            let assets = PHAsset.fetchAssets(in: screenshotAlbum, options: fetchOptions)
            var result: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                result.append(asset)
            }
            await MainActor.run { self.screenshots = result }
        }
    }
    
    func scanLargeVideos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        
        var videoSizes: [String: Int64] = [:]
        for asset in result {
            let resources = PHAssetResource.assetResources(for: asset)
            let size = resources.reduce(0) { $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0) }
            videoSizes[asset.localIdentifier] = size
        }
        
        result.sort {
            let size1 = videoSizes[$0.localIdentifier] ?? 0
            let size2 = videoSizes[$1.localIdentifier] ?? 0
            return size1 > size2
        }
        
        let large = result.filter { (videoSizes[$0.localIdentifier] ?? 0) > 10 * 1024 * 1024 }
        await MainActor.run { self.largeVideos = large }
    }
    
    func scanSimilarPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        var allAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            allAssets.append(asset)
        }
        
        // 1. Time Clustering (24 hours)
        var timeBuckets: [[PHAsset]] = []
        var currentBucket: [PHAsset] = []
        
        for asset in allAssets {
            if currentBucket.isEmpty {
                currentBucket.append(asset)
                continue
            }
            let last = currentBucket.first!
            if let date1 = last.creationDate, let date2 = asset.creationDate {
                if abs(date2.timeIntervalSince(date1)) <= 86400 {
                    currentBucket.append(asset)
                } else {
                    if currentBucket.count > 1 {
                        timeBuckets.append(currentBucket)
                    }
                    currentBucket = [asset]
                }
            }
        }
        if currentBucket.count > 1 {
            timeBuckets.append(currentBucket)
        }
        
        // 2. Vision Processing
        var groups: [AssetGroup] = []
        
        for bucket in timeBuckets {
            var processedAssets: Set<String> = []
            
            for i in 0..<bucket.count {
                let asset1 = bucket[i]
                if processedAssets.contains(asset1.localIdentifier) { continue }
                
                var currentSimilarGroup: [PHAsset] = [asset1]
                processedAssets.insert(asset1.localIdentifier)
                
                guard let print1 = try? await getFeaturePrint(for: asset1) else { continue }
                
                for j in (i+1)..<bucket.count {
                    let asset2 = bucket[j]
                    if processedAssets.contains(asset2.localIdentifier) { continue }
                    
                    guard let print2 = try? await getFeaturePrint(for: asset2) else { continue }
                    
                    var distance: Float = 0
                    do {
                        try print1.computeDistance(&distance, to: print2)
                        // Distance < 10.0 indicates high visual similarity
                        if distance < 10.0 {
                            currentSimilarGroup.append(asset2)
                            processedAssets.insert(asset2.localIdentifier)
                        }
                    } catch {
                        print("Error computing distance: \(error)")
                    }
                }
                
                if currentSimilarGroup.count > 1 {
                    groups.append(AssetGroup(assets: currentSimilarGroup, bestAsset: currentSimilarGroup.first))
                }
            }
        }
        
        await MainActor.run { self.similarPhotoGroups = groups }
    }
    
    func getFeaturePrint(for asset: PHAsset) async throws -> VNFeaturePrintObservation {
        return try await withCheckedThrowingContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            
            let targetSize = CGSize(width: 256, height: 256)
            
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                guard let cgImage = image?.cgImage else {
                    continuation.resume(throwing: NSError(domain: "PhotoScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get CGImage"]))
                    return
                }
                
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNGenerateImageFeaturePrintRequest()
                
                do {
                    try requestHandler.perform([request])
                    if let result = request.results?.first as? VNFeaturePrintObservation {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PhotoScanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "No feature print"]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getAssetSize(asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.reduce(0) { $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0) }
    }
    
    func deleteAssets(_ assets: [PHAsset]) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            await scanAll()
        } catch {
            print("Failed to delete assets: \(error)")
        }
    }
}
