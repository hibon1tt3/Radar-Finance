import SwiftUI

struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    @State private var confirmationText = ""
    let title: String
    let message: String
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                TextField("Type 'Delete' to confirm", text: $confirmationText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding()
                
                Button(action: {
                    if confirmationText == "Delete" {
                        onConfirm()
                        isPresented = false
                    }
                }) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(confirmationText == "Delete" ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(confirmationText != "Delete")
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
} 