import SwiftUI
import Photos

struct SimilarPhotosView: View {
    @Environment(PhotoScanner.self) var photoScanner
    @State private var selectedAssets: Set<String> = []
    @State private var showingReview = false
    
    var body: some View {
        List {
            ForEach(photoScanner.similarPhotoGroups) { group in
                Section(header: Text("Group of \(group.assets.count) similar photos")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(group.assets, id: \.localIdentifier) { asset in
                                ZStack(alignment: .bottomTrailing) {
                                    AssetThumbnailView(asset: asset, size: CGSize(width: 120, height: 120))
                                    
                                    if asset == group.bestAsset {
                                        Text("Best")
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .padding(4)
                                    } else {
                                        Image(systemName: selectedAssets.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedAssets.contains(asset.localIdentifier) ? .blue : .white)
                                            .padding(4)
                                    }
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
                }
            }
        }
        .navigationTitle("Similar Photos")
        .onAppear {
            for group in photoScanner.similarPhotoGroups {
                for asset in group.assets where asset != group.bestAsset {
                    selectedAssets.insert(asset.localIdentifier)
                }
            }
        }
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
            let toDelete = photoScanner.similarPhotoGroups
                .flatMap { $0.assets }
                .filter { selectedAssets.contains($0.localIdentifier) }
            ReviewCleanView(assetsToDelete: toDelete, title: "Similar Photos") {
                Task {
                    await photoScanner.deleteAssets(toDelete)
                    selectedAssets.removeAll()
                }
            }
        }
    }
}
