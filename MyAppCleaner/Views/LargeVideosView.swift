import SwiftUI
import Photos

struct LargeVideosView: View {
    @Environment(PhotoScanner.self) var photoScanner
    @State private var selectedAssets: Set<String> = []
    @State private var showingReview = false
    
    var body: some View {
        List {
            ForEach(photoScanner.largeVideos, id: \.localIdentifier) { video in
                HStack {
                    AssetThumbnailView(asset: video, size: CGSize(width: 60, height: 60))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text("Video")
                            .font(.headline)
                        Text(formatBytes(photoScanner.getAssetSize(asset: video)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: selectedAssets.contains(video.localIdentifier) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedAssets.contains(video.localIdentifier) ? .blue : .gray)
                        .onTapGesture {
                            if selectedAssets.contains(video.localIdentifier) {
                                selectedAssets.remove(video.localIdentifier)
                            } else {
                                selectedAssets.insert(video.localIdentifier)
                            }
                        }
                }
            }
        }
        .navigationTitle("Large Videos")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Delete Selected") {
                    showingReview = true
                }
                .disabled(selectedAssets.isEmpty)
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingReview) {
            let toDelete = photoScanner.largeVideos.filter { selectedAssets.contains($0.localIdentifier) }
            ReviewCleanView(assetsToDelete: toDelete, title: "Videos") {
                Task {
                    await photoScanner.deleteAssets(toDelete)
                    selectedAssets.removeAll()
                }
            }
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
