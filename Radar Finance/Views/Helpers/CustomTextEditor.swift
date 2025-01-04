import SwiftUI
import UIKit

struct CustomTextEditor: View {
    let text: Binding<String>
    
    var body: some View {
        TextEditor(text: text)
            .environment(\.sizeCategory, .medium)
            .dynamicTypeSize(.medium)
    }
} 