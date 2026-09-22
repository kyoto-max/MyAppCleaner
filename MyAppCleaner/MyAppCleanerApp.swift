import SwiftUI

@main
struct MyAppCleanerApp: App {
    @State private var permissionManager = PermissionManager()
    @State private var storageManager = StorageManager()
    @State private var photoScanner = PhotoScanner()
    @State private var contactScanner = ContactScanner()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(permissionManager)
                .environment(storageManager)
                .environment(photoScanner)
                .environment(contactScanner)
        }
    }
}
