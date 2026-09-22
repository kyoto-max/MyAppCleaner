import SwiftUI
import Photos

struct ReviewCleanView: View {
    let assetsToDelete: [PHAsset]
    let title: String
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Review Selection")
                    .font(.largeTitle)
                    .bold()
                
                Text("You have selected \(assetsToDelete.count) \(title.lowercased()) to delete.")
                    .font(.title3)
                
                let totalSize = assetsToDelete.reduce(0) { sum, asset in
                    sum + getAssetSize(asset: asset)
                }
                
                Text("Space to be freed: \(formatBytes(totalSize))")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Confirm Delete")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func getAssetSize(asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.reduce(0) { $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0) }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
