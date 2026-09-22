import SwiftUI
import Photos

struct AssetThumbnailView: View {
    let asset: PHAsset
    let size: CGSize
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
            if let result = result {
                self.image = result
            }
        }
    }
}
