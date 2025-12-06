import SwiftUI
import SwiftData

struct TimeEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Client.bedrijfsnaam) private var clients: [Client]
    @Query private var settings: [BusinessSettings]

    let entry: TimeEntry?

    // Form State
    @State private var datum: Date = Date()
    @State private var selectedClient: Client?
    @State private var code: String = "WDAGPRAKTIJK_70"
    @State private var activiteit: String = "Waarneming Dagpraktijk"
    @State private var locatie: String = ""
    @State private var uren: Decimal = 9.00
    @State private var retourafstand: Int = 0
    @State private var visiteKm: Decimal = 0
    @State private var uurtarief: Decimal = 70.00
    @State private var kmtarief: Decimal = 0.23
    @State private var isBillable: Bool = true
    @State private var isStandby: Bool = false
    @State private var isSharedShift: Bool = false
    @State private var verdeelfactor: Double = 1.0
    @State private var opmerkingen: String = ""
    @State private var showingDeleteAlert: Bool = false
    @State private var saveError: AppError?

    private var isEditing: Bool { entry != nil }

    private var totaalUren: Decimal { uren * uurtarief }
    private var totaalKm: Decimal { (Decimal(retourafstand) + visiteKm) * kmtarief }
    private var totaal: Decimal { isBillable ? (totaalUren + totaalKm) : 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form Content
            Form {
                // Date & Client Section
                Section("Basisgegevens") {
                    DatePicker("Datum", selection: $datum, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nl_NL"))

                    Picker("Klant", selection: $selectedClient) {
                        Text("Selecteer klant...").tag(nil as Client?)
                        ForEach(clients.filter { $0.isActive }) { client in
                            Text(client.displayName).tag(client as Client?)
                        }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        applyClientDefaults(newClient)
                    }

                    Picker("Activiteit", selection: $code) {
                        ForEach(ActivityCode.allCases, id: \.rawValue) { activity in
                            Text(activity.displayName).tag(activity.rawValue)
                        }
                        Divider()
                        Text("Anders...").tag("CUSTOM")
                    }
                    .onChange(of: code) { _, newCode in
                        if newCode != "CUSTOM" {
                            applyActivityDefaults(newCode)
                        }
                    }

                    if code == "CUSTOM" {
                        TextField("Omschrijving activiteit", text: $activiteit)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Locatie", text: $locatie)
                }

                // Hours & Rates Section
                Section("Uren en Tarieven") {
                    LabeledContent("Uren") {
                        TextField("", value: $uren, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Uurtarief") {
                        TextField("", value: $uurtarief, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Factureerbaar", isOn: $isBillable)

                    Toggle(isOn: $isStandby) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Geen werkuren")
                            Text("Bijv. achterwacht, toeslag, bereikbaarheid - telt niet mee voor urencriterium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Vink aan als deze uren niet meetellen voor de 1.225 uur zelfstandigenaftrek")

                    Toggle(isOn: $isSharedShift) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gedeelde dienst")
                            Text("Meerdere klanten betalen voor dezelfde dienst")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Voor diensten waarbij meerdere klanten betalen (bijv. HOED, vakantiewaarneming)")

                    if isSharedShift {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Aandeel deze klant")
                                Spacer()
                                Slider(value: $verdeelfactor, in: 0.05...1.0, step: 0.05)
                                    .frame(width: 150)
                                Text("\(Int(verdeelfactor * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }

                            HStack {
                                Text("Te factureren")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\((uren * Decimal(verdeelfactor)).asDecimal) uur")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                Text("van \(uren.asDecimal) totaal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Kilometers Section
                Section("Kilometers") {
                    LabeledContent("Retourafstand") {
                        HStack(spacing: 4) {
                            TextField("", value: $retourafstand, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Extra visitekilometers") {
                        HStack(spacing: 4) {
                            TextField("", value: $visiteKm, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Kilometertarief") {
                        TextField("", value: $kmtarief, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Notes Section
                Section("Opmerkingen") {
                    TextEditor(text: $opmerkingen)
                        .frame(height: 60)
                }

                // Calculation Preview
                Section("Berekening") {
                    calculationPreview
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer with buttons
            footer
        }
        .frame(width: 500, height: 700)
        .onAppear {
            if let entry {
                loadEntry(entry)
            } else {
                applyDefaults()
            }
        }
        .errorAlert($saveError)
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text(isEditing ? "Urenregistratie bewerken" : "Nieuwe urenregistratie")
                .font(.headline)
            Spacer()
            Button("Annuleren") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    // MARK: - Calculation Preview
    private var calculationPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Uren")
                Spacer()
                Text("\(uren.asDecimal) x \(uurtarief.asCurrency)")
                    .foregroundStyle(.secondary)
                Text("=")
                Text(totaalUren.asCurrency)
                    .monospacedDigit()
            }

            HStack {
                Text("Kilometers")
                Spacer()
                Text("\(retourafstand + Int(truncating: visiteKm as NSDecimalNumber)) x \(kmtarief.asCurrency)")
                    .foregroundStyle(.secondary)
                Text("=")
                Text(totaalKm.asCurrency)
                    .monospacedDigit()
            }

            Divider()

            HStack {
                Text("Totaal")
                    .fontWeight(.semibold)
                Spacer()
                Text(totaal.asCurrency)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(isBillable ? .primary : .secondary)
            }

            if !isBillable {
                Text("Niet factureerbaar")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if isStandby {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.xmark")
                        .foregroundStyle(.purple)
                    Text("Geen werkuren - telt niet mee voor urencriterium (1.225 uur)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
        }
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
                saveEntry()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Urenregistratie verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Weet je zeker dat je deze urenregistratie wilt verwijderen? Dit kan niet ongedaan worden gemaakt.")
        }
    }

    // MARK: - Methods

    private func applyDefaults() {
        if let defaultSettings = settings.first {
            uurtarief = defaultSettings.standaardUurtariefDag
            kmtarief = defaultSettings.standaardKilometertarief
        }
    }

    private func applyClientDefaults(_ client: Client?) {
        guard let client else { return }
        uurtarief = client.standaardUurtarief
        kmtarief = client.standaardKmTarief
        retourafstand = client.afstandRetour
        locatie = extractCity(from: client.postcodeplaats)

        // Update code and activity based on client type
        switch client.clientType {
        case .dagpraktijk:
            code = "WDAGPRAKTIJK_70"
            activiteit = "Waarneming Dagpraktijk"
            isBillable = true
        case .anwDienst:
            code = "ANW_GR_WEEKEND_DAG"
            activiteit = "ANW Dienst"
            uurtarief = 124.00
            isBillable = true
        case .administratie:
            code = "Admin"
            activiteit = "Administratie"
            uurtarief = 0
            kmtarief = 0
            retourafstand = 0
            isBillable = false
        case .zakelijk:
            activiteit = "Werkzaamheden"
            isBillable = true
        case .particulier:
            activiteit = "Dienstverlening"
            isBillable = true
        case .overheid:
            activiteit = "Opdracht"
            isBillable = true
        }
    }

    private func applyActivityDefaults(_ code: String) {
        guard let activity = ActivityCode(rawValue: code) else { return }
        activiteit = activity.displayName
        uurtarief = activity.hourlyRate
        isBillable = activity.isBillable

        if !isBillable {
            retourafstand = 0
            locatie = "Thuis"
        }
    }

    private func extractCity(from postcodeplaats: String) -> String {
        let components = postcodeplaats.components(separatedBy: " ")
        if components.count >= 3 {
            return components.dropFirst(2).joined(separator: " ")
        }
        return postcodeplaats
    }

    private func loadEntry(_ entry: TimeEntry) {
        datum = entry.datum
        selectedClient = entry.client
        code = entry.code
        activiteit = entry.activiteit
        locatie = entry.locatie
        uren = entry.uren
        retourafstand = entry.retourafstandWoonWerk
        visiteKm = entry.visiteKilometers ?? 0
        uurtarief = entry.uurtarief
        kmtarief = entry.kilometertarief
        isBillable = entry.isBillable
        isStandby = entry.isStandby
        opmerkingen = entry.opmerkingen ?? ""
    }

    private func saveEntry() {
        // Calculate actual hours to save (apply verdeelfactor for shared shifts)
        let actualUren = isSharedShift ? uren * Decimal(verdeelfactor) : uren

        // Build notes with verdeelfactor info if shared
        var notes = opmerkingen
        if isSharedShift {
            let shareNote = "Gedeelde dienst - \(Int(verdeelfactor * 100))% aandeel"
            notes = notes.isEmpty ? shareNote : "\(notes)\n\(shareNote)"
        }

        if let entry {
            // Update existing
            entry.datum = datum
            entry.client = selectedClient
            entry.code = code
            entry.activiteit = activiteit
            entry.locatie = locatie
            entry.uren = actualUren
            entry.retourafstandWoonWerk = retourafstand
            entry.visiteKilometers = visiteKm > 0 ? visiteKm : nil
            entry.uurtarief = uurtarief
            entry.kilometertarief = kmtarief
            entry.isBillable = isBillable
            entry.isStandby = isStandby
            entry.opmerkingen = notes.isEmpty ? nil : notes
            entry.updateTimestamp()
        } else {
            // Create new
            let newEntry = TimeEntry(
                datum: datum,
                code: code,
                activiteit: activiteit,
                locatie: locatie,
                uren: actualUren,
                visiteKilometers: visiteKm > 0 ? visiteKm : nil,
                retourafstandWoonWerk: retourafstand,
                uurtarief: uurtarief,
                kilometertarief: kmtarief,
                opmerkingen: notes.isEmpty ? nil : notes,
                isBillable: isBillable,
                isStandby: isStandby,
                client: selectedClient
            )
            modelContext.insert(newEntry)
        }

        do {
            try modelContext.safeSave(entity: "Urenregistratie")
            dismiss()
        } catch let error as AppError {
            saveError = error
        } catch {
            saveError = .saveFailed(entity: "Urenregistratie", reason: error.localizedDescription)
        }
    }

    private func deleteEntry() {
        guard let entry else { return }
        do {
            try modelContext.safeDelete(entry)
            dismiss()
        } catch let error as AppError {
            saveError = error
        } catch {
            saveError = .deleteFailed(entity: "Urenregistratie", reason: error.localizedDescription)
        }
    }
}

// MARK: - Preview
#Preview {
    TimeEntryFormView(entry: nil)
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
