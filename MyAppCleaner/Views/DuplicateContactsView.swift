import SwiftUI
import Contacts

struct DuplicateContactsView: View {
    @Environment(ContactScanner.self) var contactScanner
    @State private var selectedGroups: Set<UUID> = []
    @State private var showingReview = false
    
    var body: some View {
        List {
            ForEach(contactScanner.duplicateGroups) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.contacts, id: \.identifier) { contact in
                        Text(contact.givenName + " " + contact.familyName)
                    }
                }
                .listRowBackground(selectedGroups.contains(group.id) ? Color.red.opacity(0.2) : Color(.systemBackground))
                .onTapGesture {
                    if selectedGroups.contains(group.id) {
                        selectedGroups.remove(group.id)
                    } else {
                        selectedGroups.insert(group.id)
                    }
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Merge/Delete Selected") {
                    showingReview = true
                }
                .disabled(selectedGroups.isEmpty)
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingReview) {
            let toDelete = getContactsToDelete()
            ContactReviewCleanView(contactsToDelete: toDelete) {
                Task {
                    await contactScanner.delete(contacts: toDelete)
                    selectedGroups.removeAll()
                }
            }
        }
    }
    
    func getContactsToDelete() -> [CNContact] {
        var toDelete: [CNContact] = []
        for groupID in selectedGroups {
            if let group = contactScanner.duplicateGroups.first(where: { $0.id == groupID }) {
                if group.contacts.count > 1 {
                    let contactsToDelete = Array(group.contacts.dropFirst())
                    toDelete.append(contentsOf: contactsToDelete)
                }
            }
        }
        return toDelete
    }
}
