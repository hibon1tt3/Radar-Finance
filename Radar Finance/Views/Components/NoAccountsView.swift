import SwiftUI

struct NoAccountsView: View {
    @Binding var showingAddAccount: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Top section
                VStack(spacing: 20) {
                    Image(systemName: "banknote")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("Welcome to Radar Finance")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                
                // Features list with fixed layout width
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green,
                        title: "Track Spending",
                        description: "Keep track of your expenses and income with easy-to-use transaction management"
                    )
                    .frame(maxWidth: .infinity) // Ensure full width
                    
                    FeatureRow(
                        icon: "bell.badge",
                        color: .blue,
                        title: "Never Miss a Payment",
                        description: "Set up bill reminders and recurring transactions to stay on top of your finances"
                    )
                    .frame(maxWidth: .infinity) // Ensure full width
                    
                    FeatureRow(
                        icon: "chart.pie",
                        color: .purple,
                        title: "Powerful Insights",
                        description: "Visualize your spending patterns and track your financial goals with detailed reports"
                    )
                    .frame(maxWidth: .infinity) // Ensure full width
                }
                .padding(.horizontal)
                
                // Message above button
                Text("Add your first bank, credit card, or other account to start tracking your finances")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action button
                Button(action: { showingAddAccount = true }) {
                    Label("Add Account", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isAnimating = true
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon container with fixed size
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true) // Allow text to wrap
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Ensure text container uses full width
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 15,
                    x: 0,
                    y: 5
                )
        )
    }
}

#Preview {
    NoAccountsView(showingAddAccount: .constant(false))
} 
