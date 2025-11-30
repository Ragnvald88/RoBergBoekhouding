import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Expense.datum, order: .reverse) private var allExpenses: [Expense]

    @State private var selectedExpense: Expense?
    @State private var categoryFilter: ExpenseCategory?

    private var filteredExpenses: [Expense] {
        var expenses = allExpenses.filterByYear(appState.selectedYear)

        if let category = categoryFilter {
            expenses = expenses.filterByCategory(category)
        }

        if !appState.searchText.isEmpty {
            expenses = expenses.filter {
                $0.omschrijving.localizedCaseInsensitiveContains(appState.searchText) ||
                $0.leverancier?.localizedCaseInsensitiveContains(appState.searchText) == true
            }
        }

        return expenses
    }

    var body: some View {
        HSplitView {
            // Expense List
            VStack(spacing: 0) {
                // Summary
                summaryBar

                Divider()

                // Category Filter
                categoryFilterBar

                Divider()

                // List
                if filteredExpenses.isEmpty {
                    ContentUnavailableView(
                        "Geen uitgaven",
                        systemImage: "creditcard",
                        description: Text("Klik op 'Nieuwe Uitgave' om te beginnen")
                    )
                } else {
                    List(filteredExpenses, selection: $selectedExpense) { expense in
                        ExpenseRow(expense: expense)
                            .tag(expense)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 350)

            // Detail View
            if let expense = selectedExpense {
                ExpenseDetailView(expense: expense)
            } else {
                ContentUnavailableView(
                    "Selecteer een uitgave",
                    systemImage: "creditcard",
                    description: Text("Kies een uitgave uit de lijst om details te bekijken")
                )
            }
        }
        .navigationTitle("Uitgaven")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Jaar", selection: $appState.selectedYear) {
                    ForEach(appState.availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 80)

                Button("Nieuwe Uitgave", systemImage: "plus") {
                    appState.showNewExpense = true
                }
            }
        }
        .searchable(text: $appState.searchText, prompt: "Zoek uitgave")
        .sheet(isPresented: $appState.showNewExpense) {
            ExpenseFormView(expense: nil)
        }
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Totaal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredExpenses.totalAmount.asCurrency)
                    .font(.subheadline.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Zakelijk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredExpenses.totalBusinessAmount.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Maandelijks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredExpenses.monthlyRecurringTotal.asCurrency)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "Alle",
                    isSelected: categoryFilter == nil,
                    action: { categoryFilter = nil }
                )

                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    let count = filteredExpenses.filterByCategory(category).count
                    if count > 0 || categoryFilter == category {
                        FilterChip(
                            label: shortCategoryName(category),
                            count: count,
                            isSelected: categoryFilter == category,
                            action: { categoryFilter = category }
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func shortCategoryName(_ category: ExpenseCategory) -> String {
        switch category {
        case .accountancy: return "Accountancy"
        case .verzekeringen: return "Verzekeringen"
        case .pensioenpremie: return "Pensioen"
        case .lidmaatschappen: return "Lidmaatschap"
        case .investeringen: return "Investeringen"
        case .kleineAankopen: return "Aankopen"
        case .telefoonInternet: return "Telecom"
        case .representatie: return "Representatie"
        case .opleidingskosten: return "Opleiding"
        case .reiskosten: return "Reiskosten"
        case .bankkosten: return "Bank"
        case .overig: return "Overig"
        }
    }
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: expense.categorie.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.omschrijving)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    Text(expense.zakelijkBedrag.asCurrency)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                }

                HStack {
                    if let leverancier = expense.leverancier {
                        Text(leverancier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(expense.datumShort)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if expense.hasReceipt {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .help("Bon toegevoegd")
                    }

                    if expense.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if expense.hasReceipt {
                Button {
                    expense.openReceipt()
                } label: {
                    Label("Open bon", systemImage: "doc.fill")
                }
            }
        }
    }
}

// MARK: - Expense Detail View
struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let expense: Expense

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: expense.categorie.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.omschrijving)
                            .font(.title2.weight(.semibold))

                        if let leverancier = expense.leverancier {
                            Text(leverancier)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Label(expense.categorie.displayName, systemImage: "tag")
                            if expense.isRecurring {
                                Label("Maandelijks", systemImage: "repeat")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // Amounts
                VStack(spacing: 12) {
                    HStack {
                        Text("Bedrag")
                        Spacer()
                        Text(expense.bedrag.asCurrency)
                            .font(.headline)
                    }

                    if expense.zakelijkPercentage < 100 {
                        HStack {
                            Text("Zakelijk percentage")
                            Spacer()
                            Text(expense.zakelijkPercentage.asPercentage)
                        }

                        HStack {
                            Text("Zakelijk bedrag")
                            Spacer()
                            Text(expense.zakelijkBedrag.asCurrency)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack {
                        Text("Datum")
                        Spacer()
                        Text(expense.datumFormatted)
                    }

                    HStack {
                        Text("Belastingcategorie")
                        Spacer()
                        Text(expense.categorie.taxCategory)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)

                // Receipt section
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bon / Factuur")
                        .font(.headline)

                    if expense.hasReceipt {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.green)
                            Text("Bon toegevoegd")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Open") {
                                expense.openReceipt()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(.secondary)
                            Text("Geen bon toegevoegd")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Bewerk uitgave om bon toe te voegen")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let notities = expense.notities, !notities.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notities")
                            .font(.headline)
                        Text(notities)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Bewerken") {
                        showingEditSheet = true
                    }

                    Divider()

                    Button("Verwijderen", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Label("Acties", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ExpenseFormView(expense: expense)
        }
        .alert("Uitgave verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteExpense()
            }
        } message: {
            Text("Weet je zeker dat je deze uitgave wilt verwijderen?")
        }
    }

    private func deleteExpense() {
        modelContext.delete(expense)
        try? modelContext.save()
    }
}

// MARK: - Preview
#Preview {
    ExpenseListView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
