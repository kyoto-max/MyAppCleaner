import Foundation
import Photos
import Observation

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
        
        var groups: [AssetGroup] = []
        var currentGroup: [PHAsset] = []
        
        for i in 0..<allAssets.count {
            let asset = allAssets[i]
            if currentGroup.isEmpty {
                currentGroup.append(asset)
                continue
            }
            
            let last = currentGroup.last!
            if let date1 = last.creationDate, let date2 = asset.creationDate {
                if abs(date2.timeIntervalSince(date1)) < 5 {
                    currentGroup.append(asset)
                } else {
                    if currentGroup.count > 1 {
                        groups.append(AssetGroup(assets: currentGroup, bestAsset: currentGroup.first))
                    }
                    currentGroup = [asset]
                }
            }
        }
        
        if currentGroup.count > 1 {
            groups.append(AssetGroup(assets: currentGroup, bestAsset: currentGroup.first))
        }
        
        await MainActor.run { self.similarPhotoGroups = groups }
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
