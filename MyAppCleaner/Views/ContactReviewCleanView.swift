import SwiftUI
import Contacts

struct ContactReviewCleanView: View {
    let contactsToDelete: [CNContact]
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Review Selection")
                    .font(.largeTitle)
                    .bold()
                
                Text("You have selected \(contactsToDelete.count) contacts to delete.")
                    .font(.title3)
                
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
}
