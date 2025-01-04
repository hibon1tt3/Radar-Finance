import SwiftUI
import UIKit

struct CustomTextField: View {
    let text: Binding<String>
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .environment(\.sizeCategory, .medium)
            .dynamicTypeSize(.medium)
    }
} 