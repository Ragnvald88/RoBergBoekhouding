import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: Expense?

    // Form State
    @State private var datum: Date = Date()
    @State private var omschrijving: String = ""
    @State private var bedrag: Decimal = 0
    @State private var categorie: ExpenseCategory = .overig
    @State private var leverancier: String = ""
    @State private var zakelijkPercentage: Decimal = 100
    @State private var isRecurring: Bool = false
    @State private var notities: String = ""
    @State private var receiptError: String?
    @State private var pendingReceiptURL: URL? // For new expenses - receipt to attach after save
    @State private var showingDeleteAlert: Bool = false

    private var isEditing: Bool { expense != nil }
    private var canSave: Bool { !omschrijving.isEmpty && bedrag > 0 }

    private var zakelijkBedrag: Decimal {
        bedrag * (zakelijkPercentage / 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form
            Form {
                Section("Basisgegevens") {
                    DatePicker("Datum", selection: $datum, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nl_NL"))

                    TextField("Omschrijving *", text: $omschrijving)

                    TextField("Leverancier", text: $leverancier)

                    Picker("Categorie", selection: $categorie) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }

                Section("Bedrag") {
                    LabeledContent("Bedrag") {
                        TextField("", value: $bedrag, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Zakelijk percentage") {
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { Double(truncating: zakelijkPercentage as NSDecimalNumber) },
                                set: { zakelijkPercentage = Decimal($0) }
                            ), in: 0...100, step: 5)
                            .frame(width: 150)
                            Text("\(Int(truncating: zakelijkPercentage as NSDecimalNumber))%")
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                        }
                    }

                    if zakelijkPercentage < 100 {
                        LabeledContent("Zakelijk bedrag") {
                            Text(zakelijkBedrag.asCurrency)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }

                    Toggle("Maandelijks terugkerend", isOn: $isRecurring)
                }

                Section("Notities") {
                    TextEditor(text: $notities)
                        .frame(height: 60)
                }

                // Receipt section
                Section("Bonnetje / Factuur") {
                    if let expense, expense.hasReceipt {
                        // Existing expense with receipt
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.green)
                            Text("Bon toegevoegd")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Bekijk") {
                                expense.openReceipt()
                            }
                            Button("Verwijder", role: .destructive) {
                                removeReceipt()
                            }
                        }
                    } else if pendingReceiptURL != nil {
                        // New expense with pending receipt
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)
                            Text("Bon geselecteerd")
                                .foregroundStyle(.blue)
                            Spacer()
                            Button("Verwijder", role: .destructive) {
                                pendingReceiptURL = nil
                            }
                        }
                    } else {
                        // No receipt
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(.secondary)
                            Text("Geen bon toegevoegd")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Voeg bon toe...") {
                                selectReceipt()
                            }
                        }
                    }

                    if let error = receiptError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            footer
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if let expense {
                loadExpense(expense)
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text(isEditing ? "Uitgave bewerken" : "Nieuwe uitgave")
                .font(.headline)
            Spacer()
            Button("Annuleren") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    // MARK: - Footer
    private var footer: some View {
        HStack {
            if isEditing {
                Button("Verwijderen", role: .destructive) {
                    showingDeleteAlert = true
                }
            }

            Spacer()

            Button("Opslaan") {
                saveExpense()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
        .alert("Uitgave verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteExpense()
            }
        } message: {
            Text("Weet je zeker dat je '\(omschrijving)' wilt verwijderen? Dit kan niet ongedaan worden gemaakt.")
        }
    }

    // MARK: - Methods
    private func loadExpense(_ expense: Expense) {
        datum = expense.datum
        omschrijving = expense.omschrijving
        bedrag = expense.bedrag
        categorie = expense.categorie
        leverancier = expense.leverancier ?? ""
        zakelijkPercentage = expense.zakelijkPercentage
        isRecurring = expense.isRecurring
        notities = expense.notities ?? ""
    }

    private func saveExpense() {
        if let expense {
            // Update existing
            expense.datum = datum
            expense.omschrijving = omschrijving
            expense.bedrag = bedrag
            expense.categorie = categorie
            expense.leverancier = leverancier.isEmpty ? nil : leverancier
            expense.zakelijkPercentage = zakelijkPercentage
            expense.isRecurring = isRecurring
            expense.notities = notities.isEmpty ? nil : notities
            expense.updateTimestamp()
        } else {
            // Create new
            let newExpense = Expense(
                datum: datum,
                omschrijving: omschrijving,
                bedrag: bedrag,
                categorie: categorie,
                leverancier: leverancier.isEmpty ? nil : leverancier,
                zakelijkPercentage: zakelijkPercentage,
                isRecurring: isRecurring,
                notities: notities.isEmpty ? nil : notities
            )
            modelContext.insert(newExpense)

            // Attach pending receipt if any
            if let receiptURL = pendingReceiptURL {
                try? newExpense.attachReceipt(from: receiptURL)
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteExpense() {
        guard let expense else { return }
        // Also delete the receipt if it exists
        if expense.hasReceipt {
            try? expense.removeReceipt()
        }
        modelContext.delete(expense)
        try? modelContext.save()
        dismiss()
    }

    private func selectReceipt() {
        receiptError = nil

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .png, .jpeg]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Selecteer bon of factuur"

        if panel.runModal() == .OK, let url = panel.url {
            if let expense {
                // Existing expense - attach immediately
                do {
                    try expense.attachReceipt(from: url)
                    try modelContext.save()
                } catch {
                    receiptError = "Kon bon niet toevoegen: \(error.localizedDescription)"
                }
            } else {
                // New expense - store URL for later attachment
                pendingReceiptURL = url
            }
        }
    }

    private func removeReceipt() {
        guard let expense else { return }
        receiptError = nil

        do {
            try expense.removeReceipt()
            try modelContext.save()
        } catch {
            receiptError = "Kon bon niet verwijderen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
#Preview {
    ExpenseFormView(expense: nil)
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
