import SwiftUI
import SwiftData

struct AnnualReportView: View {
    @EnvironmentObject var appState: AppState

    @Query private var timeEntries: [TimeEntry]
    @Query private var invoices: [Invoice]
    @Query private var expenses: [Expense]

    private var yearEntries: [TimeEntry] {
        timeEntries.filterByYear(appState.selectedYear)
    }

    private var yearInvoices: [Invoice] {
        invoices.filterByYear(appState.selectedYear)
    }

    private var yearExpenses: [Expense] {
        expenses.filterByYear(appState.selectedYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Jaaroverzicht \(appState.selectedYear)")
                    .font(.title.weight(.bold))

                // Revenue Section
                revenueSection

                Divider()

                // Hours Section
                hoursSection

                Divider()

                // Expenses Section
                expensesSection

                Divider()

                // Result Section
                resultSection
            }
            .padding(24)
        }
        .navigationTitle("Jaaroverzicht")
    }

    // MARK: - Revenue Section
    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inkomsten")
                .font(.headline)

            // Monthly breakdown
            let monthlyData = (1...12).map { month -> (month: Int, name: String, revenue: Decimal, hours: Decimal) in
                let entries = yearEntries.filterByMonth(month, year: appState.selectedYear)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "nl_NL")
                let monthName = formatter.monthSymbols[month - 1].capitalized
                return (month, monthName, entries.totalRevenue, entries.totalHours)
            }

            // Table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Maand")
                        .frame(width: 100, alignment: .leading)
                    Text("Uren")
                        .frame(width: 80, alignment: .trailing)
                    Text("Omzet")
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

                Divider()

                ForEach(monthlyData, id: \.month) { data in
                    HStack {
                        Text(data.name)
                            .frame(width: 100, alignment: .leading)
                        Text(data.hours.asDecimal)
                            .frame(width: 80, alignment: .trailing)
                        Text(data.revenue.asCurrency)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 4)
                }

                Divider()

                // Total
                HStack {
                    Text("Totaal")
                        .fontWeight(.semibold)
                        .frame(width: 100, alignment: .leading)
                    Text(yearEntries.totalHours.asDecimal)
                        .frame(width: 80, alignment: .trailing)
                    Text(yearEntries.totalRevenue.asCurrency)
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Hours Section
    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uren voor zelfstandigenaftrek")
                .font(.headline)

            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Totaal gewerkte uren")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(yearEntries.totalHours.asDecimal)
                        .font(.title2.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Factureerbare uren")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(yearEntries.totalBillableHours.asDecimal)
                        .font(.title2.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Drempel (1.225 uur)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // NOTE: For zelfstandigenaftrek, ALL worked hours count (not just billable)
                    let hours = yearEntries.totalHours
                    let threshold: Decimal = 1225
                    let met = hours >= threshold

                    HStack {
                        Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(met ? .green : .red)
                        Text(met ? "Behaald" : "Niet behaald")
                    }
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(met ? .green : .red)
                }
            }
        }
    }

    // MARK: - Expenses Section
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uitgaven per categorie")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(yearExpenses.summaryByCategory, id: \.category) { item in
                    HStack {
                        Label(item.category.displayName, systemImage: item.category.icon)
                        Spacer()
                        Text(item.total.asCurrency)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)

                    if item.category != yearExpenses.summaryByCategory.last?.category {
                        Divider()
                    }
                }

                Divider()

                HStack {
                    Text("Totaal zakelijke uitgaven")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(yearExpenses.totalBusinessAmount.asCurrency)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .padding(.vertical, 8)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Result Section
    private var resultSection: some View {
        let revenue = yearEntries.totalRevenue
        let expenses = yearExpenses.totalBusinessAmount
        let profit = revenue - expenses

        return VStack(alignment: .leading, spacing: 16) {
            Text("Resultaat")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Bruto omzet")
                    Spacer()
                    Text(revenue.asCurrency)
                        .monospacedDigit()
                }

                HStack {
                    Text("Totaal kosten")
                    Spacer()
                    Text("-\(expenses.asCurrency)")
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }

                Divider()

                HStack {
                    Text("Netto resultaat")
                        .font(.headline)
                    Spacer()
                    Text(profit.asCurrency)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(profit >= 0 ? .green : .red)
                }
            }
            .font(.subheadline)
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview
#Preview {
    AnnualReportView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
