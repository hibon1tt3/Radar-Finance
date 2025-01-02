import SwiftUI
import SwiftData

private struct QuickTransactionSheet: Identifiable {
    let id = UUID()
    let type: TransactionType
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @State private var showingAddAccount = false
    @State private var selectedTransaction: Transaction?
    @State private var transactionToComplete: TransactionToComplete?
    @State private var showingQuickTransactionSheet = false
    @State private var quickTransactionSheet: QuickTransactionSheet?
    @State private var upcomingTransactions: [TransactionOccurrence] = []
    
    // Create a struct to hold both transaction and date
    private struct TransactionToComplete: Identifiable {
        let id = UUID()
        let transaction: Transaction
        let occurrenceDate: Date
    }
    
    var totalBalance: Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + account.safeBalance
        }
    }
    
    var next30Days: ClosedRange<Date> {
        let now = Calendar.current.startOfDay(for: Date())
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 29, to: now) ?? now
        return now...thirtyDaysLater
    }
    
    var upcomingIncome: Decimal {
        upcomingTransactions
            .filter { $0.transaction?.type == .income }
            .reduce(Decimal.zero) { total, occurrence in
                total + occurrence.amount
            }
    }
    
    var upcomingExpenses: Decimal {
        upcomingTransactions
            .filter { $0.transaction?.type == .expense }
            .reduce(Decimal.zero) { total, occurrence in
                total + occurrence.amount
            }
    }
    
    private func getPendingTransactions() -> [Transaction] {
        return transactions.filter { transaction in
            transaction.status == .pending
        }
    }
    
    private func generateAllOccurrences(from transactions: [Transaction]) -> [TransactionOccurrence] {
        transactions.flatMap { transaction -> [TransactionOccurrence] in
            transaction.generateUpcomingOccurrences()
        }
    }
    
    private func filterValidOccurrences(_ occurrences: [TransactionOccurrence]) -> [TransactionOccurrence] {
        let today = Date().startOfDay
        
        return occurrences.filter { occurrence in
            guard let transaction = occurrence.transaction else { return false }
            let isNotCompleted = !transaction.completedOccurrences.contains(occurrence.dueDate)
            let isPastDue = occurrence.dueDate < today
            let isInNext30Days = next30Days.contains(occurrence.dueDate)
            return isNotCompleted && (isPastDue || isInNext30Days)
        }.sorted { first, second in
            let firstIsPastDue = first.dueDate < today
            let secondIsPastDue = second.dueDate < today
            
            if firstIsPastDue != secondIsPastDue {
                return firstIsPastDue
            }
            return first.dueDate < second.dueDate
        }
    }
    
    private func updateUpcomingTransactions() {
        let pendingTransactions = getPendingTransactions()
        let allOccurrences = generateAllOccurrences(from: pendingTransactions)
        let validOccurrences = filterValidOccurrences(allOccurrences)
        upcomingTransactions = validOccurrences.sorted { $0.dueDate < $1.dueDate }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    // Break down the upcoming transactions section into a separate view
    private struct UpcomingTransactionsList: View {
        let transactions: [TransactionOccurrence]
        let onTransactionSelected: (Transaction, Date) -> Void
        
        var body: some View {
            ForEach(transactions) { occurrence in
                if let transaction = occurrence.transaction {
                    UpcomingTransactionRow(
                        occurrence: occurrence,
                        onSelect: { onTransactionSelected(transaction, occurrence.dueDate) }
                    )
                }
            }
        }
    }
    
    // Break down the transaction row into its own view
    private struct UpcomingTransactionRow: View {
        let occurrence: TransactionOccurrence
        let onSelect: () -> Void
        
        private var displayAmount: Decimal {
            guard let transaction = occurrence.transaction else { return 0 }
            return transaction.type == .expense ? -occurrence.amount : occurrence.amount
        }
        
        var body: some View {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(occurrence.transaction?.title ?? "")
                            .font(.subheadline)
                        
                        if let category = occurrence.transaction?.category {
                            Label(category.rawValue, systemImage: category.icon)
                                .font(.caption)
                                .foregroundColor(Color(hex: category.color))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(displayAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundColor(occurrence.transaction?.type == .income ? .green : .red)
                        
                        let daysUntilDue = Calendar.current.dateComponents([.day], 
                            from: Date().startOfDay, 
                            to: occurrence.dueDate.startOfDay).day ?? 0
                        
                        Text(daysUntilDue < 0 ? "Past Due" :
                             daysUntilDue == 0 ? "Due Today" :
                             "Due in \(daysUntilDue) days")
                            .font(.subheadline)
                            .foregroundColor(
                                daysUntilDue < 0 ? .red :
                                daysUntilDue == 0 ? .orange : .secondary
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // Break down the due date view
    private struct DueDateView: View {
        let dueDate: Date
        
        var body: some View {
            let daysUntilDue = Calendar.current.dateComponents(
                [.day],
                from: Date().startOfDay,
                to: dueDate.startOfDay
            ).day ?? 0
            
            Group {
                if daysUntilDue < 0 {
                    Text("Past Due")
                        .foregroundColor(.red)
                } else if daysUntilDue == 0 {
                    Text("Due Today")
                        .foregroundColor(.orange)
                } else {
                    Text("Due in \(daysUntilDue) days")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Accounts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Accounts")
                                .font(.title2)
                                .bold()
                            
                            Spacer()
                            
                            Text(totalBalance.formatted(.currency(code: "USD")))
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        if accounts.isEmpty {
                            NavigationLink(destination: AccountListView()) {
                                HStack {
                                    Label("No Accounts - Tap to Add", systemImage: "banknote")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        } else {
                            ForEach(accounts) { account in
                                AccountRowView(account: account)
                                    .padding(.horizontal)
                                if account.id != accounts.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(cardBackground)
                    .padding(.horizontal)
                    
                    // Upcoming Totals Section
                    HStack(spacing: 15) {
                        // Upcoming Income Tile
                        VStack(spacing: 8) {
                            Text("Upcoming Income")
                                .font(.headline)
                            
                            Text(upcomingIncome.formatted(.currency(code: "USD")))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.95)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                        )
                        
                        // Upcoming Expenses Tile
                        VStack(spacing: 8) {
                            Text("Upcoming Bills")
                                .font(.headline)
                            
                            Text(upcomingExpenses.formatted(.currency(code: "USD")))
                                .font(.title2)
                                .bold()
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.95)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Upcoming Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming Transactions")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if upcomingTransactions.isEmpty {
                            HStack {
                                Label("No Upcoming Transactions", systemImage: "calendar")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(upcomingTransactions) { occurrence in
                                    if let transaction = occurrence.transaction {
                                        Button(action: {
                                            transactionToComplete = TransactionToComplete(
                                                transaction: transaction,
                                                occurrenceDate: occurrence.dueDate
                                            )
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(transaction.title)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                    
                                                    if let category = transaction.category {
                                                        Label(category.rawValue, systemImage: category.icon)
                                                            .font(.subheadline)
                                                            .foregroundColor(Color(hex: category.color))
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing) {
                                                    Text(transaction.type == .expense ? 
                                                         (-transaction.amount).formatted(.currency(code: "USD")) :
                                                         transaction.amount.formatted(.currency(code: "USD")))
                                                        .font(.headline)
                                                        .foregroundColor(transaction.type == .income ? .green : .red)
                                                    
                                                    let daysUntilDue = Calendar.current.dateComponents([.day], 
                                                        from: Date().startOfDay, 
                                                        to: occurrence.dueDate.startOfDay).day ?? 0
                                                    
                                                    Text(daysUntilDue < 0 ? "Past Due" :
                                                         daysUntilDue == 0 ? "Due Today" :
                                                         "Due in \(daysUntilDue) days")
                                                        .font(.subheadline)
                                                        .foregroundColor(
                                                            daysUntilDue < 0 ? .red :
                                                            daysUntilDue == 0 ? .orange : .secondary
                                                        )
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if occurrence.id != upcomingTransactions.last?.id {
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(cardBackground)
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
            .sheet(item: $transactionToComplete) { toComplete in
                CompleteTransactionView(
                    transaction: toComplete.transaction,
                    occurrenceDate: toComplete.occurrenceDate
                )
                .modelContainer(modelContext.container)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingQuickTransactionSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
            .confirmationDialog("Add Quick Transaction", 
                              isPresented: $showingQuickTransactionSheet,
                              titleVisibility: .visible) {
                Button("Add Quick Income") {
                    quickTransactionSheet = QuickTransactionSheet(type: .income)
                }
                Button("Add Quick Expense") {
                    quickTransactionSheet = QuickTransactionSheet(type: .expense)
                }
                Button("Cancel", role: .cancel) {
                    quickTransactionSheet = nil
                }
            }
            .sheet(item: $quickTransactionSheet) { sheet in
                QuickTransactionView(transactionType: sheet.type)
            }
        }
        .onAppear {
            updateUpcomingTransactions()
        }
        .onChange(of: transactions) { _, _ in
            updateUpcomingTransactions()
        }
    }
} 