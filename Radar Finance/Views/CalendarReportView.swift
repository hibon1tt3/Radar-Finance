import SwiftUI
import SwiftData

fileprivate struct DayMarker: Hashable {
    let date: Date
    let hasIncome: Bool
    let hasExpenses: Bool
}

struct CalendarReportView: View {
    @Query private var transactions: [Transaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var selectedAccount: Account?
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAddAccount = false
    @State private var cachedTransactions: [DayTransactions] = []
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private struct DayTransactions: Identifiable {
        let id = UUID()
        let date: Date
        let transactions: [TransactionOccurrence]
        var totalIncome: Decimal
        var totalExpenses: Decimal
        
        var hasTransactions: Bool {
            !transactions.isEmpty
        }
    }
    
    private var monthTransactions: [DayTransactions] {
        cachedTransactions
    }
    
    private var markedDays: Set<DayMarker> {
        Set(monthTransactions.filter { $0.hasTransactions }.map { day in
            DayMarker(
                date: day.date,
                hasIncome: day.totalIncome > 0,
                hasExpenses: day.totalExpenses > 0
            )
        })
    }
    
    private var selectedDayTransactions: DayTransactions? {
        let calendar = Calendar.current
        return monthTransactions.first { day in
            calendar.isDate(day.date, equalTo: selectedDate, toGranularity: .day)
        }
    }
    
    var body: some View {
        ScrollView {
            if accounts.isEmpty {
                NoAccountsView(showingAddAccount: $showingAddAccount)
            } else {
                VStack(spacing: 20) {
                    // Account Picker
                    AccountPickerView(selectedAccount: $selectedAccount)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    
                    // Custom Calendar View
                    CustomCalendarView(
                        selectedDate: $selectedDate,
                        displayedMonth: $displayedMonth,
                        markedDates: markedDays
                    )
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // Selected Day Transactions List
                    if let dayTransactions = selectedDayTransactions,
                       dayTransactions.hasTransactions {
                        VStack(alignment: .leading, spacing: 4) {
                            // Keep the header with date and totals
                            Text(dayTransactions.date.formatted(.dateTime.month().day().weekday()))
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if dayTransactions.totalIncome > 0 {
                                    Text("Income: \(dayTransactions.totalIncome.formatted(.currency(code: "USD")))")
                                        .foregroundColor(.green)
                                }
                                if dayTransactions.totalExpenses > 0 {
                                    Text("Expenses: \(dayTransactions.totalExpenses.formatted(.currency(code: "USD")))")
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Add a divider between header and transactions
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Transactions list styled like expenses view
                            VStack(spacing: 0) {
                                ForEach(dayTransactions.transactions) { occurrence in
                                    if let transaction = occurrence.transaction {
                                        TransactionRowView(
                                            transaction: transaction,
                                            showOccurrenceDate: true,
                                            occurrenceDate: occurrence.dueDate
                                        )
                                        
                                        if occurrence.id != dayTransactions.transactions.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Calendar")
        .scrollContentBackground(.hidden)
        .animatedBackground()
        .onAppear {
            if selectedAccount == nil && !accounts.isEmpty {
                selectedAccount = defaultAccount ?? accounts[0]
            }
            updateTransactions()
        }
        .onChange(of: selectedAccount) { _, _ in
            updateTransactions()
        }
        .onChange(of: displayedMonth) { _, _ in
            updateTransactions()
        }
    }
    
    private func getMonthTransactions() -> [DayTransactions] {
        guard let account = selectedAccount else { return [] }
        
        let calendar = Calendar.current
        
        // Get start of displayed month and end of 12th month from there
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let endDate = calendar.date(byAdding: DateComponents(month: 12), to: startOfMonth),
              let endOfPeriod = calendar.date(byAdding: .day, value: -1, to: endDate) else {
            return []
        }
        
        // Filter transactions for selected account
        let accountTransactions = transactions.filter { transaction in
            transaction.account == account && 
            transaction.status == .pending && 
            transaction.schedule != nil
        }
        
        // Generate all occurrences for the next 12 months
        var allOccurrences: [TransactionOccurrence] = []
        
        for transaction in accountTransactions {
            if let schedule = transaction.schedule {
                // Use DateHelper to generate occurrences
                let dates = DateHelper.generateOccurrences(
                    for: schedule,
                    startingFrom: startOfMonth,
                    endDate: endOfPeriod
                )
                
                // Create TransactionOccurrence for each date
                let occurrences = dates.map { date in
                    TransactionOccurrence(
                        transaction: transaction,
                        dueDate: date,
                        amount: transaction.amount
                    )
                }
                
                allOccurrences.append(contentsOf: occurrences)
            }
        }
        
        // Group by day
        var dayGroups: [Date: [TransactionOccurrence]] = [:]
        for occurrence in allOccurrences {
            let day = calendar.startOfDay(for: occurrence.dueDate)
            dayGroups[day, default: []].append(occurrence)
        }
        
        // Create array of days
        var days: [DayTransactions] = []
        var currentDay = startOfMonth
        
        while currentDay <= endOfPeriod {
            let dayStart = calendar.startOfDay(for: currentDay)
            let dayTransactions = dayGroups[dayStart] ?? []
            
            let income = dayTransactions
                .filter { $0.transaction?.type == .income }
                .reduce(Decimal.zero) { $0 + ($1.amount) }
            
            let expenses = dayTransactions
                .filter { $0.transaction?.type == .expense }
                .reduce(Decimal.zero) { $0 + ($1.amount) }
            
            days.append(DayTransactions(
                date: currentDay,
                transactions: dayTransactions,
                totalIncome: income,
                totalExpenses: expenses
            ))
            
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) {
                currentDay = nextDay
            } else {
                break
            }
        }
        
        return days
    }
    
    private func updateTransactions() {
        cachedTransactions = getMonthTransactions()
    }
}

fileprivate struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    let markedDates: Set<DayMarker>
    
    private let calendar = Calendar.current
    private let daysInWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    init(selectedDate: Binding<Date>, displayedMonth: Binding<Date>, markedDates: Set<DayMarker>) {
        self._selectedDate = selectedDate
        self._displayedMonth = displayedMonth
        self.markedDates = markedDates
    }
    
    private var month: Date {
        displayedMonth
    }
    
    private var daysInMonth: [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }
        
        let firstDay = monthInterval.start
        let lastDay = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end) ?? monthInterval.end
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let numberOfDays = calendar.component(.day, from: lastDay)
        
        var days: [[Date?]] = []
        var week: [Date?] = []
        
        // Add empty spaces for days before the first of the month
        for _ in 1..<firstWeekday {
            week.append(nil)
        }
        
        // Add all days of the month
        for day in 1...numberOfDays {
            if let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: month),
                month: calendar.component(.month, from: month),
                day: day
            )) {
                week.append(date)
                
                if week.count == 7 {
                    days.append(week)
                    week = []
                }
            }
        }
        
        // Fill in the rest of the last week with nil
        while week.count < 7 && !week.isEmpty {
            week.append(nil)
        }
        
        if !week.isEmpty {
            days.append(week)
        }
        
        return days
    }
    
    private var canGoToPreviousMonth: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.startOfMonth(for: Date())
        let displayedMonthStart = calendar.startOfMonth(for: displayedMonth)
        
        // Only allow going back if we're not in the current month
        return displayedMonthStart > currentMonth
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month/Year header with navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoToPreviousMonth)
                .opacity(canGoToPreviousMonth ? 1 : 0.3)
                
                Spacer()
                
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            
            // Day headers
            HStack {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            VStack(spacing: 8) {
                ForEach(daysInMonth.indices, id: \.self) { weekIndex in
                    HStack {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let date = daysInMonth[weekIndex][dayIndex] {
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, equalTo: selectedDate, toGranularity: .day),
                                    isCurrentMonth: true,
                                    dayMarker: markedDates.first { calendar.isDate($0.date, equalTo: date, toGranularity: .day) }
                                )
                                .onTapGesture {
                                    selectedDate = date
                                }
                            } else {
                                // Empty cell for days outside the month
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func previousMonth() {
        if canGoToPreviousMonth,
           let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
}

fileprivate struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let dayMarker: DayMarker?
    private let calendar = Calendar.current
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            // Background for selected or current date
            Circle()
                .fill(backgroundColor)
                .opacity(backgroundOpacity)
            
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                
                if let marker = dayMarker {
                    HStack(spacing: 4) {
                        if marker.hasIncome {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                        if marker.hasExpenses {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .gray
        }
        return .clear
    }
    
    private var backgroundOpacity: Double {
        if isSelected || isToday {
            return 0.2
        }
        return 0
    }
    
    private var textColor: Color {
        if isToday {
            return .primary
        }
        return isCurrentMonth ? .primary : .secondary
    }
} 