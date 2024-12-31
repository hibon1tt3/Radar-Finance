import SwiftUI

struct AccountRowView: View {
    let account: Account
    
    var body: some View {
        HStack {
            Image(systemName: account.icon)
                .foregroundColor(Color(hex: account.color))
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(account.name)
                Text(account.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(account.safeBalance.formatted(.currency(code: "USD")))
                .font(.subheadline)
        }
    }
} 