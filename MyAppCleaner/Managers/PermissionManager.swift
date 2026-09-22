import Foundation
import Photos
import Contacts
import Observation

@Observable
class PermissionManager {
    var hasPhotoAccess = false
    var hasContactAccess = false

    init() {
        checkPhotoAccess()
        checkContactAccess()
    }

    func checkPhotoAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        hasPhotoAccess = (status == .authorized || status == .limited)
    }

    func checkContactAccess() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        hasContactAccess = (status == .authorized)
    }

    func requestPhotoAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.hasPhotoAccess = (status == .authorized || status == .limited)
        }
    }

    func requestContactAccess() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                self.hasContactAccess = granted
            }
        } catch {
            await MainActor.run {
                self.hasContactAccess = false
            }
        }
    }
}
