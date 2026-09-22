import SwiftUI
import Photos

struct ScreenshotsView: View {
    @Environment(PhotoScanner.self) var photoScanner
    @State private var selectedAssets: Set<String> = []
    @State private var showingReview = false
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photoScanner.screenshots, id: \.localIdentifier) { asset in
                    ZStack(alignment: .bottomTrailing) {
                        AssetThumbnailView(asset: asset, size: CGSize(width: 150, height: 150))
                        
                        Image(systemName: selectedAssets.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedAssets.contains(asset.localIdentifier) ? .blue : .white)
                            .padding(4)
                    }
                    .onTapGesture {
                        if selectedAssets.contains(asset.localIdentifier) {
                            selectedAssets.remove(asset.localIdentifier)
                        } else {
                            selectedAssets.insert(asset.localIdentifier)
                        }
                    }
                }
            }
        }
        .navigationTitle("Screenshots")
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
            let toDelete = photoScanner.screenshots.filter { selectedAssets.contains($0.localIdentifier) }
            ReviewCleanView(assetsToDelete: toDelete, title: "Screenshots") {
                Task {
                    await photoScanner.deleteAssets(toDelete)
                    selectedAssets.removeAll()
                }
            }
        }
    }
}
