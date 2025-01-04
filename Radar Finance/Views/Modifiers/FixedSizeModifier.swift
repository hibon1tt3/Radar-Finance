import SwiftUI

struct FixedSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.sizeCategory, .medium)
            .dynamicTypeSize(.medium)
    }
}

extension View {
    func fixedSize() -> some View {
        modifier(FixedSizeModifier())
    }
} 