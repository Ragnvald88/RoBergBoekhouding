import SwiftUI
import SwiftData

struct AssetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [BusinessSettings]

    let asset: Asset?
    let linkedExpense: Expense?

    // Form State
    @State private var naam: String = ""
    @State private var omschrijving: String = ""
    @State private var aanschafdatum: Date = Date()
    @State private var inGebruikDatum: Date = Date()
    @State private var aanschafwaarde: Decimal = 0
    @State private var btwBedrag: Decimal = 0
    @State private var restwaarde: Decimal = 0
    @State private var afschrijvingsjaren: Int = 5
    @State private var categorie: AssetCategory = .overig
    @State private var leverancier: String = ""
    @State private var factuurNummer: String = ""
    @State private var zakelijkPercentage: Decimal = 100
    @State private var notities: String = ""
    @State private var showingDeleteAlert = false

    private var isEditing: Bool { asset != nil }

    private var businessSettings: BusinessSettings? {
        settings.first
    }

    private var canSave: Bool {
        !naam.isEmpty && aanschafwaarde > 0
    }

    // Computed depreciation preview
    private var jaarlijkseAfschrijving: Decimal {
        guard aanschafwaarde > restwaarde, afschrijvingsjaren > 0 else { return 0 }
        let depreciable = aanschafwaarde - restwaarde
        let annual = depreciable / Decimal(afschrijvingsjaren)
        return annual * (zakelijkPercentage / 100)
    }

    private var boekwaardeNaJaar1: Decimal {
        let businessPortion = aanschafwaarde * (zakelijkPercentage / 100)
        return businessPortion - jaarlijkseAfschrijving
    }

    init(asset: Asset? = nil, linkedExpense: Expense? = nil) {
        self.asset = asset
        self.linkedExpense = linkedExpense
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                // Basic Info
                Section("Basisgegevens") {
                    TextField("Naam *", text: $naam)
                        .help("Bijv. 'MacBook Pro 16 inch' of 'Bureau IKEA'")

                    TextField("Omschrijving", text: $omschrijving)

                    Picker("Categorie", selection: $categorie) {
                        ForEach(AssetCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .onChange(of: categorie) { _, newCat in
                        // Update default years based on category
                        if !isEditing {
                            afschrijvingsjaren = newCat.defaultYears
                        }
                    }
                }

                // Purchase Info
                Section("Aanschaf") {
                    DatePicker("Aanschafdatum", selection: $aanschafdatum, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nl_NL"))

                    DatePicker("In gebruik vanaf", selection: $inGebruikDatum, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nl_NL"))

                    LabeledContent("Aanschafwaarde (excl. BTW)") {
                        TextField("", value: $aanschafwaarde, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: aanschafwaarde) { _, newValue in
                                // Update default restwaarde (10%)
                                if let settings = businessSettings {
                                    restwaarde = settings.defaultRestwaarde(for: newValue)
                                }
                            }
                    }

                    LabeledContent("BTW bedrag") {
                        TextField("", value: $btwBedrag, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("Leverancier", text: $leverancier)

                    TextField("Factuurnummer leverancier", text: $factuurNummer)
                }

                // Depreciation Settings
                Section("Afschrijving") {
                    LabeledContent("Restwaarde") {
                        TextField("", value: $restwaarde, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Afschrijvingstermijn") {
                        HStack(spacing: 4) {
                            TextField("", value: $afschrijvingsjaren, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("jaar")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let settings = businessSettings, afschrijvingsjaren < settings.afschrijvingMinJaren {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Minimum is \(settings.afschrijvingMinJaren) jaar volgens fiscale regels")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
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
                }

                // Depreciation Preview
                Section("Afschrijvingsoverzicht") {
                    LabeledContent("Af te schrijven bedrag") {
                        Text((aanschafwaarde - restwaarde).asCurrency)
                            .fontWeight(.medium)
                    }

                    LabeledContent("Jaarlijkse afschrijving") {
                        Text(jaarlijkseAfschrijving.asCurrency)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }

                    LabeledContent("Boekwaarde na 1 jaar") {
                        Text(boekwaardeNaJaar1.asCurrency)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Volledig afgeschreven") {
                        let endDate = Calendar.current.date(byAdding: .year, value: afschrijvingsjaren, to: inGebruikDatum) ?? inGebruikDatum
                        Text(endDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }

                // Notes
                Section("Notities") {
                    TextEditor(text: $notities)
                        .frame(height: 60)
                }
            }
            .formStyle(.grouped)

            Divider()

            footer
        }
        .frame(width: 500, height: 700)
        .onAppear {
            if let asset {
                loadAsset(asset)
            } else if let expense = linkedExpense {
                loadFromExpense(expense)
            } else {
                // Set defaults from settings
                if let settings = businessSettings {
                    afschrijvingsjaren = settings.afschrijvingMinJaren
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text(isEditing ? "Bedrijfsmiddel bewerken" : "Nieuw bedrijfsmiddel")
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
                saveAsset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
        .alert("Bedrijfsmiddel verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteAsset()
            }
        } message: {
            Text("Weet je zeker dat je '\(naam)' wilt verwijderen? Dit kan niet ongedaan worden gemaakt.")
        }
    }

    // MARK: - Methods
    private func loadAsset(_ asset: Asset) {
        naam = asset.naam
        omschrijving = asset.omschrijving ?? ""
        aanschafdatum = asset.aanschafdatum
        inGebruikDatum = asset.inGebruikDatum
        aanschafwaarde = asset.aanschafwaarde
        btwBedrag = asset.btwBedrag
        restwaarde = asset.restwaarde
        afschrijvingsjaren = asset.afschrijvingsjaren
        categorie = asset.categorie
        leverancier = asset.leverancier ?? ""
        factuurNummer = asset.factuurNummer ?? ""
        zakelijkPercentage = asset.zakelijkPercentage
        notities = asset.notities ?? ""
    }

    private func loadFromExpense(_ expense: Expense) {
        naam = expense.omschrijving
        aanschafdatum = expense.datum
        inGebruikDatum = expense.datum
        aanschafwaarde = expense.bedrag
        leverancier = expense.leverancier ?? ""
        factuurNummer = expense.factuurNummer ?? ""
        zakelijkPercentage = expense.zakelijkPercentage

        // Set default restwaarde
        if let settings = businessSettings {
            restwaarde = settings.defaultRestwaarde(for: expense.bedrag)
            afschrijvingsjaren = settings.afschrijvingMinJaren
        }
    }

    private func saveAsset() {
        // Validate years
        let validatedYears = businessSettings?.validateDepreciationYears(afschrijvingsjaren) ?? afschrijvingsjaren

        if let asset {
            // Update existing
            asset.naam = naam
            asset.omschrijving = omschrijving.isEmpty ? nil : omschrijving
            asset.aanschafdatum = aanschafdatum
            asset.inGebruikDatum = inGebruikDatum
            asset.aanschafwaarde = aanschafwaarde
            asset.btwBedrag = btwBedrag
            asset.restwaarde = restwaarde
            asset.afschrijvingsjaren = validatedYears
            asset.categorie = categorie
            asset.leverancier = leverancier.isEmpty ? nil : leverancier
            asset.factuurNummer = factuurNummer.isEmpty ? nil : factuurNummer
            asset.zakelijkPercentage = zakelijkPercentage
            asset.notities = notities.isEmpty ? nil : notities
            asset.updateTimestamp()
        } else {
            // Create new
            let newAsset = Asset(
                naam: naam,
                omschrijving: omschrijving.isEmpty ? nil : omschrijving,
                aanschafdatum: aanschafdatum,
                inGebruikDatum: inGebruikDatum,
                aanschafwaarde: aanschafwaarde,
                btwBedrag: btwBedrag,
                restwaarde: restwaarde,
                afschrijvingsjaren: validatedYears,
                categorie: categorie,
                leverancier: leverancier.isEmpty ? nil : leverancier,
                factuurNummer: factuurNummer.isEmpty ? nil : factuurNummer,
                zakelijkPercentage: zakelijkPercentage,
                notities: notities.isEmpty ? nil : notities
            )

            // Link to expense if provided
            if let expense = linkedExpense {
                newAsset.expense = expense
                expense.asset = newAsset
                expense.isDepreciable = true
            }

            modelContext.insert(newAsset)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteAsset() {
        guard let asset else { return }

        // Unlink from expense
        if let expense = asset.expense {
            expense.asset = nil
            expense.isDepreciable = false
        }

        modelContext.delete(asset)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    AssetFormView()
        .modelContainer(for: [Asset.self, Expense.self, BusinessSettings.self], inMemory: true)
}
