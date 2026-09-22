import Foundation
import Contacts
import Observation

struct ContactGroup: Identifiable {
    let id = UUID()
    var name: String
    var contacts: [CNContact]
}

@Observable
class ContactScanner {
    var duplicateGroups: [ContactGroup] = []
    var isScanning = false
    
    func scanContacts() async {
        await MainActor.run { isScanning = true }
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var allContacts: [CNContact] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                allContacts.append(contact)
            }
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
        
        let grouped = Dictionary(grouping: allContacts) { contact -> String in
            return "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        }
        
        var resultGroups: [ContactGroup] = []
        for (name, contacts) in grouped {
            if contacts.count > 1 && !name.isEmpty {
                resultGroups.append(ContactGroup(name: name, contacts: contacts))
            }
        }
        
        await MainActor.run {
            self.duplicateGroups = resultGroups
            self.isScanning = false
        }
    }
    
    func delete(contacts: [CNContact]) async {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        for contact in contacts {
            guard let mutableContact = contact.mutableCopy() as? CNMutableContact else { continue }
            saveRequest.delete(mutableContact)
        }
        do {
            try store.execute(saveRequest)
            await scanContacts()
        } catch {
            print("Failed to delete contacts: \(error)")
        }
    }
}
