import SwiftUI
import SwiftData

struct WeekOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @Query(sort: \TimeEntry.datum, order: .reverse) private var allEntries: [TimeEntry]

    @State private var selectedWeek: Date = Date()

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = selectedWeek.startOfWeek
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }

    private var weekEntries: [Date: [TimeEntry]] {
        let calendar = Calendar.current
        let startOfWeek = selectedWeek.startOfWeek
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return [:]
        }

        let entries = allEntries.filter { entry in
            entry.datum >= startOfWeek && entry.datum < endOfWeek
        }

        return Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.datum)
        }
    }

    private var weekTotals: (hours: Decimal, revenue: Decimal, km: Int) {
        let entries = weekEntries.values.flatMap { $0 }
        return (
            entries.totalHours,
            entries.totalRevenue,
            entries.totalKilometers
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week Navigation
            weekNavigationBar

            Divider()

            // Week Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(weekDates, id: \.self) { date in
                        DayCard(
                            date: date,
                            entries: weekEntries[Calendar.current.startOfDay(for: date)] ?? [],
                            onTap: {
                                // Open new entry for this date
                            }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Week Summary
            weekSummaryBar
        }
    }

    // MARK: - Week Navigation Bar
    private var weekNavigationBar: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(weekRangeText)
                .font(.headline)

            Spacer()

            Button(action: nextWeek) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Button("Vandaag") {
                selectedWeek = Date()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Week Summary Bar
    private var weekSummaryBar: some View {
        HStack(spacing: 24) {
            StatItem(label: "Uren", value: weekTotals.hours.asDecimal)
            StatItem(label: "Kilometers", value: "\(weekTotals.km.formatted) km")
            StatItem(label: "Omzet", value: weekTotals.revenue.asCurrency)
            Spacer()
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Helper Methods
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"

        let startOfWeek = selectedWeek.startOfWeek
        guard let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return ""
        }

        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek)) \(Calendar.current.component(.year, from: startOfWeek))"
    }

    private func previousWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedWeek) {
            selectedWeek = newDate
        }
    }

    private func nextWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedWeek) {
            selectedWeek = newDate
        }
    }
}

// MARK: - Day Card
struct DayCard: View {
    let date: Date
    let entries: [TimeEntry]
    let onTap: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var totalHours: Decimal {
        entries.totalHours
    }

    private var totalRevenue: Decimal {
        entries.totalRevenue
    }

    var body: some View {
        VStack(spacing: 8) {
            // Day Header
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dayNumber)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isToday ? .blue : .primary)
            }

            Divider()

            // Entries
            if entries.isEmpty {
                Spacer()
                Image(systemName: "plus.circle.dashed")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(entries) { entry in
                            DayEntryRow(entry: entry)
                        }
                    }
                }

                Divider()

                // Day Totals
                VStack(spacing: 2) {
                    Text("\(totalHours.asDecimal) uur")
                        .font(.caption.weight(.medium))
                    Text(totalRevenue.asCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .frame(minHeight: 200)
        .background(isToday ? Color.blue.opacity(0.05) : Color.clear)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Day Entry Row
struct DayEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.isBillable ? Color.green : Color.gray)
                .frame(width: 6, height: 6)

            Text(entry.client?.bedrijfsnaam ?? entry.activiteit)
                .font(.caption2)
                .lineLimit(1)

            Spacer()

            Text("\(entry.uren.asDecimal)u")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Preview
#Preview {
    WeekOverviewView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
