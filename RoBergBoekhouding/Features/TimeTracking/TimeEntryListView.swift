import SwiftUI
import SwiftData

struct TimeEntryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TimeEntry.datum, order: .reverse) private var allEntries: [TimeEntry]

    @State private var selectedEntries: Set<TimeEntry.ID> = []
    @State private var showingDeleteAlert = false
    @State private var entriesToDelete: [TimeEntry] = []

    private var filteredEntries: [TimeEntry] {
        var entries = allEntries.filterByYear(appState.selectedYear)

        if let month = appState.selectedMonth {
            entries = entries.filterByMonth(month, year: appState.selectedYear)
        }

        if !appState.searchText.isEmpty {
            entries = entries.filter {
                $0.client?.bedrijfsnaam.localizedCaseInsensitiveContains(appState.searchText) == true ||
                $0.activiteit.localizedCaseInsensitiveContains(appState.searchText) ||
                $0.locatie.localizedCaseInsensitiveContains(appState.searchText)
            }
        }

        return entries
    }

    /// Entries grouped by week (week number -> entries)
    private var entriesByWeek: [(week: Int, year: Int, entries: [TimeEntry])] {
        let calendar = Calendar(identifier: .iso8601)
        var grouped: [String: (week: Int, year: Int, entries: [TimeEntry])] = [:]

        for entry in filteredEntries {
            let weekOfYear = calendar.component(.weekOfYear, from: entry.datum)
            let year = calendar.component(.yearForWeekOfYear, from: entry.datum)
            let key = "\(year)-\(weekOfYear)"

            if grouped[key] == nil {
                grouped[key] = (week: weekOfYear, year: year, entries: [])
            }
            grouped[key]?.entries.append(entry)
        }

        // Sort by year desc, then week desc
        return grouped.values
            .sorted { ($0.year, $0.week) > ($1.year, $1.week) }
    }

    /// Format week range (e.g., "2-8 dec")
    private func weekDateRange(week: Int, year: Int) -> String {
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 2 // Monday

        guard let monday = calendar.date(from: components) else { return "" }
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")

        // Check if same month
        let mondayMonth = calendar.component(.month, from: monday)
        let sundayMonth = calendar.component(.month, from: sunday)

        if mondayMonth == sundayMonth {
            formatter.dateFormat = "d"
            let start = formatter.string(from: monday)
            formatter.dateFormat = "d MMM"
            let end = formatter.string(from: sunday)
            return "\(start)-\(end)"
        } else {
            formatter.dateFormat = "d MMM"
            return "\(formatter.string(from: monday)) - \(formatter.string(from: sunday))"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary Bar
            summaryBar

            Divider()

            // Content
            if filteredEntries.isEmpty {
                EmptyStateView(
                    icon: "clock.fill",
                    title: "Geen urenregistraties",
                    description: "Begin met het registreren van je werkuren. Deze worden automatisch gekoppeld aan klanten.",
                    actionTitle: "Eerste registratie"
                ) {
                    appState.selectedTimeEntry = nil
                    appState.showNewTimeEntry = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedEntries) {
                    ForEach(entriesByWeek, id: \.week) { weekGroup in
                        Section {
                            ForEach(weekGroup.entries.sorted { $0.datum > $1.datum }) { entry in
                                TimeEntryRow(entry: entry)
                                    .tag(entry.id)
                                    .contextMenu {
                                        entryContextMenu(for: entry)
                                    }
                            }
                        } header: {
                            WeekHeaderView(
                                week: weekGroup.week,
                                dateRange: weekDateRange(week: weekGroup.week, year: weekGroup.year),
                                totalHours: weekGroup.entries.reduce(0) { $0 + $1.uren },
                                totalAmount: weekGroup.entries.reduce(0) { $0 + $1.totaalbedrag }
                            )
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: TimeEntry.ID.self) { selection in
                    let selectedItems = filteredEntries.filter { selection.contains($0.id) }
                    bulkContextMenu(for: selectedItems)
                } primaryAction: { selection in
                    if selection.count == 1, let id = selection.first,
                       let entry = filteredEntries.first(where: { $0.id == id }) {
                        appState.selectedTimeEntry = entry
                        appState.showNewTimeEntry = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Urenregistratie")
        .toolbar {
            // Delete button when items selected
            ToolbarItemGroup(placement: .destructiveAction) {
                if !selectedEntries.isEmpty {
                    Button(role: .destructive) {
                        let items = filteredEntries.filter { selectedEntries.contains($0.id) }
                        entriesToDelete = items
                        showingDeleteAlert = true
                    } label: {
                        Label("Verwijder (\(selectedEntries.count))", systemImage: "trash")
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Year Picker
                Picker("Jaar", selection: $appState.selectedYear) {
                    ForEach(appState.availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 80)

                // Month Picker
                Picker("Maand", selection: $appState.selectedMonth) {
                    Text("Alle maanden").tag(nil as Int?)
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month as Int?)
                    }
                }
                .frame(width: 120)
                .help("Filter op maand")

                Button {
                    appState.selectedTimeEntry = nil
                    appState.showNewTimeEntry = true
                } label: {
                    Label("Nieuwe Registratie", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .help("Registreer nieuwe uren (⌘N)")
            }
        }
        .searchable(text: $appState.searchText, prompt: "Zoek op klant of locatie")
        .sheet(isPresented: $appState.showNewTimeEntry) {
            TimeEntryFormView(entry: appState.selectedTimeEntry)
        }
        .alert(
            entriesToDelete.count == 1 ? "Registratie verwijderen" : "\(entriesToDelete.count) registraties verwijderen",
            isPresented: $showingDeleteAlert
        ) {
            Button("Annuleren", role: .cancel) {
                entriesToDelete = []
            }
            Button("Verwijderen", role: .destructive) {
                deleteEntries(entriesToDelete)
            }
        } message: {
            if entriesToDelete.count == 1 {
                Text("Weet je zeker dat je deze registratie wilt verwijderen?")
            } else {
                Text("Weet je zeker dat je \(entriesToDelete.count) registraties wilt verwijderen?")
            }
        }
        .onChange(of: appState.selectedYear) { _, _ in
            // Reset month filter when year changes to avoid confusion
            appState.selectedMonth = nil
        }
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack(spacing: 24) {
            StatItem(label: "Registraties", value: "\(filteredEntries.count)")
            StatItem(label: "Uren", value: filteredEntries.totalHours.asDecimal)
            StatItem(label: "Kilometers", value: "\(filteredEntries.totalKilometers.formatted) km")
            StatItem(label: "Omzet", value: filteredEntries.totalRevenue.asCurrency)

            Spacer()

            if !selectedEntries.isEmpty {
                Text("\(selectedEntries.count) geselecteerd")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Context Menus
    @ViewBuilder
    private func entryContextMenu(for entry: TimeEntry) -> some View {
        Button {
            appState.selectedTimeEntry = entry
            appState.showNewTimeEntry = true
        } label: {
            Label("Bewerken", systemImage: "pencil")
        }

        if let client = entry.client {
            Button {
                duplicateEntryForClient(entry, client: client)
            } label: {
                Label("Kopieer voor \(client.bedrijfsnaam)", systemImage: "doc.on.doc")
            }
        }

        if entry.isBillable && !entry.isInvoiced {
            Divider()
            Button {
                createInvoiceFromEntries([entry])
            } label: {
                Label("Factureer", systemImage: "doc.text")
            }
        }

        Divider()

        Button(role: .destructive) {
            entriesToDelete = [entry]
            showingDeleteAlert = true
        } label: {
            Label("Verwijderen", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func bulkContextMenu(for selectedItems: [TimeEntry]) -> some View {
        Button {
            appState.selectedTimeEntry = nil
            appState.showNewTimeEntry = true
        } label: {
            Label("Nieuwe registratie", systemImage: "plus")
        }

        if selectedItems.count == 1, let entry = selectedItems.first {
            Button {
                appState.selectedTimeEntry = entry
                appState.showNewTimeEntry = true
            } label: {
                Label("Bewerken", systemImage: "pencil")
            }

            if let client = entry.client {
                Button {
                    duplicateEntryForClient(entry, client: client)
                } label: {
                    Label("Kopieer voor \(client.bedrijfsnaam)", systemImage: "doc.on.doc")
                }
            }
        }

        let unbilledItems = selectedItems.filter { $0.isBillable && !$0.isInvoiced }
        if !unbilledItems.isEmpty {
            Divider()
            Button {
                createInvoiceFromEntries(unbilledItems)
            } label: {
                Label(unbilledItems.count == 1 ? "Factureer" : "Factureer \(unbilledItems.count) items", systemImage: "doc.text")
            }
        }

        if !selectedItems.isEmpty {
            Divider()
            Button(role: .destructive) {
                entriesToDelete = selectedItems
                showingDeleteAlert = true
            } label: {
                Label(selectedItems.count == 1 ? "Verwijderen" : "Verwijder \(selectedItems.count) items", systemImage: "trash")
            }
        }
    }

    // MARK: - Helper Methods
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols[month - 1].capitalized
    }

    private func deleteEntries(_ entries: [TimeEntry]) {
        for entry in entries {
            // Remove from selection
            selectedEntries.remove(entry.id)
            // Delete entry
            modelContext.delete(entry)
        }
        try? modelContext.save()
        entriesToDelete = []
    }

    private func duplicateEntryForClient(_ entry: TimeEntry, client: Client) {
        let newEntry = TimeEntry(
            datum: Date(),
            code: entry.code,
            activiteit: entry.activiteit,
            locatie: entry.locatie,
            uren: entry.uren,
            visiteKilometers: entry.visiteKilometers,
            retourafstandWoonWerk: entry.retourafstandWoonWerk,
            uurtarief: entry.uurtarief,
            kilometertarief: entry.kilometertarief,
            isBillable: entry.isBillable,
            client: client
        )
        modelContext.insert(newEntry)
        try? modelContext.save()

        // Open the new entry for editing
        appState.selectedTimeEntry = newEntry
        appState.showNewTimeEntry = true
    }

    private func createInvoiceFromEntries(_ entries: [TimeEntry]) {
        // Navigate to invoice creation with these entries pre-selected
        appState.selectedSidebarItem = .facturen
        appState.showNewInvoice = true
        // Note: The InvoiceGeneratorView will need to be updated to accept pre-selected entries
        // For now, this just navigates to the invoice section
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - Week Header View
struct WeekHeaderView: View {
    let week: Int
    let dateRange: String
    let totalHours: Decimal
    let totalAmount: Decimal

    var body: some View {
        HStack(spacing: 12) {
            // Week badge
            Text("Week \(week)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(.accent)
                .clipShape(Capsule())

            Text(dateRange)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Week totals
            HStack(spacing: 16) {
                Label(totalHours.asDecimal + " uur", systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(totalAmount.asCurrency)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Time Entry Row
struct TimeEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.datum, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(entry.datum, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline.weight(.medium))
            }
            .frame(width: 50, alignment: .leading)

            // Client & Activity
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.bedrijfsnaam ?? entry.activiteit)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.locatie)
                    if entry.isStandby {
                        Text("•")
                        Text("Achterwacht")
                            .foregroundStyle(.purple)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Hours
            Text(entry.uren.asDecimal)
                .font(.subheadline.monospacedDigit())
                .frame(width: 40, alignment: .trailing)

            // Km
            Text(entry.totaalKilometers > 0 ? "\(entry.totaalKilometers)" : "-")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(entry.totaalKilometers > 0 ? .primary : .tertiary)
                .frame(width: 40, alignment: .trailing)

            // Amount
            Text(entry.totaalbedrag.asCurrency)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(entry.isBillable ? .primary : .secondary)
                .frame(width: 80, alignment: .trailing)

            // Status indicator
            Group {
                if entry.isInvoiced {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if !entry.isBillable {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
            .frame(width: 24)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    TimeEntryListView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
