import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query private var accounts: [Account]
    @State private var destinationView: ReportDestination?
    @State private var navigateToAccounts = false
    
    private enum ReportDestination: Identifiable {
        case ledger, cashFlow, spending, projections, calendar
        
        var id: Int {
            switch self {
            case .ledger: return 0
            case .cashFlow: return 1
            case .spending: return 2
            case .projections: return 3
            case .calendar: return 4
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Ledger
                    Button {
                        if !accounts.isEmpty {
                            destinationView = .ledger
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ledger")
                                    .font(.headline)
                                Text("Transaction History")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Cash Flow
                    Button {
                        if !accounts.isEmpty {
                            destinationView = .cashFlow
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.pie.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cash Flow")
                                    .font(.headline)
                                Text("Monthly Income vs Expenses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Spending
                    Button {
                        if !accounts.isEmpty {
                            destinationView = .spending
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Spending")
                                    .font(.headline)
                                Text("Spending by Category")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Projections
                    Button {
                        if !accounts.isEmpty {
                            destinationView = .projections
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Projections")
                                    .font(.headline)
                                Text("12 Month Balance Projection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Calendar
                    Button {
                        if !accounts.isEmpty {
                            destinationView = .calendar
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar")
                                    .font(.headline)
                                Text("Scheduled Transactions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationDestination(item: $destinationView) { destination in
                switch destination {
                case .ledger:
                    LedgerView()
                case .cashFlow:
                    CashFlowView()
                case .spending:
                    SpendingView()
                case .projections:
                    ProjectionsView()
                case .calendar:
                    CalendarReportView()
                }
            }
            .navigationDestination(isPresented: $navigateToAccounts) {
                AccountListView()
            }
        }
    }
} 