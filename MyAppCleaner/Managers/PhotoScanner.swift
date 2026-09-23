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
        
        // 1. Time Clustering (All time)
        var timeBuckets: [[PHAsset]] = []
        if allAssets.count > 1 {
            timeBuckets.append(allAssets)
        }
        
        // 2. Vision Processing
        var groups: [AssetGroup] = []
        var featurePrintsCache: [String: VNFeaturePrintObservation] = [:]
        
        for bucket in timeBuckets {
            var processedAssets: Set<String> = []
            
            for i in 0..<bucket.count {
                let asset1 = bucket[i]
                if processedAssets.contains(asset1.localIdentifier) { continue }
                
                var currentSimilarGroup: [PHAsset] = [asset1]
                processedAssets.insert(asset1.localIdentifier)
                
                let print1: VNFeaturePrintObservation
                if let cached = featurePrintsCache[asset1.localIdentifier] {
                    print1 = cached
                } else if let p = try? await getFeaturePrint(for: asset1) {
                    featurePrintsCache[asset1.localIdentifier] = p
                    print1 = p
                } else {
                    continue
                }
                
                for j in (i+1)..<bucket.count {
                    let asset2 = bucket[j]
                    if processedAssets.contains(asset2.localIdentifier) { continue }
                    
                    let print2: VNFeaturePrintObservation
                    if let cached = featurePrintsCache[asset2.localIdentifier] {
                        print2 = cached
                    } else if let p = try? await getFeaturePrint(for: asset2) {
                        featurePrintsCache[asset2.localIdentifier] = p
                        print2 = p
                    } else {
                        continue
                    }
                    
                    var distance: Float = 0
                    do {
                        try print1.computeDistance(&distance, to: print2)
                        print("Debug: Distance between \(asset1.localIdentifier) and \(asset2.localIdentifier) is \(distance)")
                        
                        // Lowered threshold to 1.0 for stricter similarity
                        if distance < 1.0 {
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
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true
            
            let targetSize = CGSize(width: 256, height: 256)
            
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                guard let cgImage = image?.cgImage else {
                    print("Debug: Failed to get cgImage for asset \(asset.localIdentifier)")
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
                        print("Debug: No feature print generated for asset \(asset.localIdentifier)")
                        continuation.resume(throwing: NSError(domain: "PhotoScanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "No feature print"]))
                    }
                } catch {
                    print("Debug: requestHandler perform failed with error: \(error)")
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
