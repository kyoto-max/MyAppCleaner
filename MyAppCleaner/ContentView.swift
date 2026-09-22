import SwiftUI

struct ContentView: View {
    @Environment(PermissionManager.self) var permissionManager
    @Environment(PhotoScanner.self) var photoScanner
    @Environment(ContactScanner.self) var contactScanner

    var body: some View {
        if permissionManager.hasPhotoAccess && permissionManager.hasContactAccess {
            DashboardView()
                .onAppear {
                    Task {
                        await photoScanner.scanAll()
                        await contactScanner.scanContacts()
                    }
                }
        } else {
            PermissionsView()
        }
    }
}

struct PermissionsView: View {
    @Environment(PermissionManager.self) var permissionManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to MyAppCleaner")
                .font(.largeTitle)
                .bold()
            
            Text("To help you free up space, we need access to your Photos and Contacts.")
                .multilineTextAlignment(.center)
                .padding()

            Button("Allow Photos Access") {
                Task { await permissionManager.requestPhotoAccess() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(permissionManager.hasPhotoAccess)
            .overlay(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .opacity(permissionManager.hasPhotoAccess ? 1 : 0)
                    .offset(x: 100),
                alignment: .trailing
            )

            Button("Allow Contacts Access") {
                Task { await permissionManager.requestContactAccess() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(permissionManager.hasContactAccess)
            .overlay(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .opacity(permissionManager.hasContactAccess ? 1 : 0)
                    .offset(x: 100),
                alignment: .trailing
            )
        }
        .padding()
    }
}
