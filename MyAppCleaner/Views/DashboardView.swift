import SwiftUI

struct DashboardView: View {
    @Environment(StorageManager.self) var storageManager
    @Environment(PhotoScanner.self) var photoScanner
    @Environment(ContactScanner.self) var contactScanner
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Storage Overview")) {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(storageManager.formatBytes(storageManager.usedSpace))
                    }
                    HStack {
                        Text("Free")
                        Spacer()
                        Text(storageManager.formatBytes(storageManager.freeSpace))
                    }
                }
                
                Section(header: Text("Clean Up")) {
                    NavigationLink(destination: ScreenshotsView()) {
                        HStack {
                            Text("Screenshots")
                            Spacer()
                            Text("\(photoScanner.screenshots.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: LargeVideosView()) {
                        HStack {
                            Text("Large Videos")
                            Spacer()
                            Text("\(photoScanner.largeVideos.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: SimilarPhotosView()) {
                        HStack {
                            Text("Similar Photos")
                            Spacer()
                            Text("\(photoScanner.similarPhotoGroups.count) groups")
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: DuplicateContactsView()) {
                        HStack {
                            Text("Duplicate Contacts")
                            Spacer()
                            Text("\(contactScanner.duplicateGroups.count) groups")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("MyAppCleaner")
            .overlay {
                if photoScanner.isScanning || contactScanner.isScanning {
                    ProgressView("Scanning...")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .refreshable {
                await photoScanner.scanAll()
                await contactScanner.scanContacts()
                storageManager.updateStorageInfo()
            }
        }
    }
}
