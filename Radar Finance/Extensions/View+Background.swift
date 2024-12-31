import SwiftUI

struct AnimatedBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Static gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.2),
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            content
        }
    }
}

extension View {
    func animatedBackground() -> some View {
        modifier(AnimatedBackgroundModifier())
    }
} 