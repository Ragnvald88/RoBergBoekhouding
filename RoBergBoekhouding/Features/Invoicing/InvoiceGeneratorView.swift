import SwiftUI
import SwiftData

struct InvoiceGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Client.bedrijfsnaam) private var clients: [Client]
    @Query(sort: \TimeEntry.datum, order: .reverse) private var allEntries: [TimeEntry]
    @Query private var settings: [BusinessSettings]

    @State private var selectedClient: Client?
    @State private var selectedEntries: Set<TimeEntry.ID> = []
    @State private var factuurdatum: Date = Date()
    @State private var notities: String = ""
    @State private var btwTarief: BTWTarief = .vrijgesteld

    private var unbilledEntries: [TimeEntry] {
        guard let client = selectedClient else { return [] }
        return allEntries.filter { entry in
            entry.client?.id == client.id &&
            entry.isBillable &&
            !entry.isInvoiced
        }.sortedByDate
    }

    private var selectedEntriesArray: [TimeEntry] {
        unbilledEntries.filter { selectedEntries.contains($0.id) }
    }

    private var totaalUren: Decimal {
        selectedEntriesArray.totalHours
    }

    private var totaalUrenBedrag: Decimal {
        selectedEntriesArray.reduce(0) { $0 + $1.totaalbedragUren }
    }

    private var totaalKm: Int {
        selectedEntriesArray.totalKilometers
    }

    private var totaalKmBedrag: Decimal {
        selectedEntriesArray.reduce(0) { $0 + $1.totaalbedragKm }
    }

    private var subtotaal: Decimal {
        totaalUrenBedrag + totaalKmBedrag
    }

    private var btwBedrag: Decimal {
        subtotaal * btwTarief.percentage
    }

    private var totaalbedrag: Decimal {
        subtotaal + btwBedrag
    }

    private var canCreate: Bool {
        selectedClient != nil && !selectedEntries.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            HSplitView {
                // Left: Client & Entry Selection
                VStack(spacing: 0) {
                    // Client Picker
                    HStack {
                        Text("Klant")
                            .font(.headline)
                        Spacer()
                        Picker("Klant", selection: $selectedClient) {
                            Text("Selecteer klant...").tag(nil as Client?)
                            ForEach(clients.filter { $0.isActive && !($0.unbilledEntries.isEmpty) }) { client in
                                HStack {
                                    Text(client.bedrijfsnaam)
                                    Text("(\(client.unbilledEntries.count))")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(client as Client?)
                            }
                        }
                        .frame(width: 250)
                    }
                    .padding()

                    Divider()

                    // Entries Table
                    if selectedClient == nil {
                        ContentUnavailableView(
                            "Selecteer een klant",
                            systemImage: "person.2",
                            description: Text("Kies een klant om openstaande uren te zien")
                        )
                    } else if unbilledEntries.isEmpty {
                        ContentUnavailableView(
                            "Geen openstaande uren",
                            systemImage: "checkmark.circle",
                            description: Text("Alle uren voor deze klant zijn al gefactureerd")
                        )
                    } else {
                        VStack(spacing: 0) {
                            // Select All
                            HStack {
                                Button(selectedEntries.count == unbilledEntries.count ? "Deselecteer alles" : "Selecteer alles") {
                                    if selectedEntries.count == unbilledEntries.count {
                                        selectedEntries.removeAll()
                                    } else {
                                        selectedEntries = Set(unbilledEntries.map { $0.id })
                                    }
                                }
                                .font(.caption)

                                Spacer()

                                Text("\(unbilledEntries.count) openstaande registraties")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                            Divider()

                            // Entry List
                            List(unbilledEntries, selection: $selectedEntries) { entry in
                                EntrySelectionRow(entry: entry, isSelected: selectedEntries.contains(entry.id))
                            }
                        }
                    }
                }
                .frame(minWidth: 400)

                // Right: Invoice Preview
                VStack(spacing: 0) {
                    Text("Factuurvoorbeeld")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    Divider()

                    if selectedEntries.isEmpty {
                        ContentUnavailableView(
                            "Selecteer registraties",
                            systemImage: "doc.text",
                            description: Text("Selecteer registraties om een factuur te maken")
                        )
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Invoice Meta
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Factuurdatum")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        DatePicker("", selection: $factuurdatum, displayedComponents: .date)
                                            .labelsHidden()
                                            .environment(\.locale, Locale(identifier: "nl_NL"))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text("Factuurnummer")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(nextInvoiceNumber)
                                            .font(.headline)
                                    }
                                }

                                Divider()

                                // Client
                                if let client = selectedClient {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let contact = client.contactpersoon {
                                            Text(contact)
                                        }
                                        Text(client.bedrijfsnaam)
                                            .fontWeight(.medium)
                                        Text(client.fullAddress)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Divider()

                                // BTW Selection
                                HStack {
                                    Text("BTW-tarief")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Picker("BTW", selection: $btwTarief) {
                                        ForEach(BTWTarief.allCases, id: \.self) { tarief in
                                            Text(tarief.displayName).tag(tarief)
                                        }
                                    }
                                    .frame(width: 140)
                                    .accessibilityLabel("BTW tarief selectie")
                                }

                                Divider()

                                // Summary
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Uren")
                                        Spacer()
                                        Text("\(totaalUren.asDecimal) uur")
                                        Text(totaalUrenBedrag.asCurrency)
                                            .frame(width: 90, alignment: .trailing)
                                    }

                                    HStack {
                                        Text("Kilometers")
                                        Spacer()
                                        Text("\(totaalKm) km")
                                        Text(totaalKmBedrag.asCurrency)
                                            .frame(width: 90, alignment: .trailing)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Subtotaal")
                                        Spacer()
                                        Text(subtotaal.asCurrency)
                                            .frame(width: 90, alignment: .trailing)
                                    }

                                    if btwTarief != .vrijgesteld {
                                        HStack {
                                            Text("BTW \(btwTarief.percentageFormatted)")
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(btwBedrag.asCurrency)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 90, alignment: .trailing)
                                        }
                                    }

                                    Divider()

                                    HStack {
                                        Text("TOTAAL\(btwTarief != .vrijgesteld ? " incl. BTW" : "")")
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text(totaalbedrag.asCurrency)
                                            .font(.title2.weight(.bold))
                                    }

                                    if btwTarief == .vrijgesteld {
                                        Text("BTW vrijgesteld")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)

                                // Notes
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notities")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextEditor(text: $notities)
                                        .frame(height: 60)
                                        .font(.caption)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(minWidth: 300)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 900, height: 600)
        .onChange(of: selectedClient) { _, _ in
            selectedEntries.removeAll()
        }
        .onAppear {
            // Initialize BTW tarief from settings
            if let businessSettings = settings.first {
                btwTarief = businessSettings.standaardBTWTarief
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Nieuwe factuur maken")
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
            if !selectedEntries.isEmpty {
                Text("\(selectedEntries.count) registraties geselecteerd")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Factuur aanmaken") {
                createInvoice()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreate)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Computed Properties
    /// Preview-only invoice number (does NOT increment the counter)
    private var nextInvoiceNumber: String {
        guard let businessSettings = settings.first else {
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)-001"
        }
        // Preview only - don't call generateNextInvoiceNumber() as that increments the counter
        let year = Calendar.current.component(.year, from: factuurdatum)
        let nextNum = businessSettings.laatsteFactuurnummer + 1
        return String(format: "%d-%03d", year, nextNum)
    }

    // MARK: - Methods
    private func createInvoice() {
        guard let client = selectedClient, !selectedEntries.isEmpty else { return }

        // Get or create settings
        let businessSettings = settings.first ?? BusinessSettings.ensureSettingsExist(in: modelContext)

        // Generate invoice number
        let invoiceNumber = businessSettings.generateNextInvoiceNumber()

        // Create invoice with BTW
        let invoice = Invoice(
            factuurnummer: invoiceNumber,
            factuurdatum: factuurdatum,
            betalingstermijn: businessSettings.standaardBetalingstermijn,
            status: .concept,
            client: client,
            notities: notities.isEmpty ? nil : notities,
            btwTarief: btwTarief
        )

        modelContext.insert(invoice)

        // Add selected entries
        let entriesToAdd = unbilledEntries.filter { selectedEntries.contains($0.id) }
        invoice.addTimeEntries(entriesToAdd)

        try? modelContext.save()

        // Post notification
        NotificationCenter.default.post(name: .invoiceCreated, object: invoice)

        dismiss()
    }
}

// MARK: - Entry Selection Row
struct EntrySelectionRow: View {
    let entry: TimeEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.datumFormatted)
                    .font(.subheadline.weight(.medium))
                Text(entry.activiteit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.uren.asDecimal) uur")
                    .font(.subheadline)
                if entry.totaalKilometers > 0 {
                    Text("\(entry.totaalKilometers) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(entry.totaalbedrag.asCurrency)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    InvoiceGeneratorView()
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
