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

    var body: some View {
        VStack(spacing: 0) {
            // Summary Bar
            summaryBar

            Divider()

            // Content
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "Geen urenregistraties",
                    systemImage: "clock",
                    description: Text("Klik op 'Nieuwe Registratie' om te beginnen")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredEntries, selection: $selectedEntries) {
                    TableColumn("Datum") { entry in
                        Text(entry.datumFormatted)
                            .font(.subheadline)
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn("Klant") { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.client?.bedrijfsnaam ?? entry.activiteit)
                                .font(.subheadline.weight(.medium))
                            Text(entry.locatie)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("Uren") { entry in
                        Text(entry.uren.asDecimal)
                            .font(.subheadline.monospacedDigit())
                    }
                    .width(60)

                    TableColumn("Km") { entry in
                        Text("\(entry.totaalKilometers)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(entry.totaalKilometers > 0 ? .primary : .secondary)
                    }
                    .width(50)

                    TableColumn("Bedrag") { entry in
                        Text(entry.totaalbedrag.asCurrency)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(entry.isBillable ? .primary : .secondary)
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn("Status") { entry in
                        HStack(spacing: 4) {
                            if entry.isInvoiced {
                                Label("Gefactureerd", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else if !entry.isBillable {
                                Label("Niet factureerbaar", systemImage: "minus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("Open", systemImage: "circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .width(min: 100, ideal: 120)
                }
                .contextMenu(forSelectionType: TimeEntry.ID.self) { selection in
                    let selectedItems = filteredEntries.filter { selection.contains($0.id) }

                    if selectedItems.count == 1, let entry = selectedItems.first {
                        Button {
                            appState.selectedTimeEntry = entry
                            appState.showNewTimeEntry = true
                        } label: {
                            Label("Bewerken", systemImage: "pencil")
                        }

                        Divider()
                    }

                    if !selectedItems.isEmpty {
                        Button(role: .destructive) {
                            entriesToDelete = selectedItems
                            showingDeleteAlert = true
                        } label: {
                            Label(selectedItems.count == 1 ? "Verwijderen" : "Verwijder \(selectedItems.count) items", systemImage: "trash")
                        }
                    }
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

                Button("Nieuwe Registratie", systemImage: "plus") {
                    appState.selectedTimeEntry = nil
                    appState.showNewTimeEntry = true
                }
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

// MARK: - Preview
#Preview {
    TimeEntryListView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
