import SwiftUI

struct AnimatedBackgroundModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        ZStack {
            // Animated gradient background
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
            .hueRotation(.degrees(isAnimating ? 45 : 0))
            .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: isAnimating)
            
            content
        }
        .onAppear {
            isAnimating = true
        }
    }
}

extension View {
    func animatedBackground() -> some View {
        modifier(AnimatedBackgroundModifier())
    }
} 