import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @Query private var allSettings: [BusinessSettings]

    @State private var settings: BusinessSettings?

    // Form State
    @State private var bedrijfsnaam: String = ""
    @State private var eigenaar: String = ""
    @State private var adres: String = ""
    @State private var postcodeplaats: String = ""
    @State private var telefoon: String = ""
    @State private var email: String = ""
    @State private var kvkNummer: String = ""
    @State private var iban: String = ""
    @State private var bank: String = ""

    @State private var standaardUurtariefDag: Decimal = 70
    @State private var standaardUurtariefANW: Decimal = 124
    @State private var standaardKilometertarief: Decimal = 0.23
    @State private var standaardBetalingstermijn: Int = 14

    @State private var hasChanges = false
    @State private var showingSaveAlert = false

    var body: some View {
        Form {
            // Business Information
            Section("Bedrijfsgegevens") {
                TextField("Bedrijfsnaam", text: $bedrijfsnaam)
                TextField("Eigenaar", text: $eigenaar)
                TextField("Adres", text: $adres)
                TextField("Postcode en plaats", text: $postcodeplaats)
            }

            Section("Contactgegevens") {
                TextField("Telefoon", text: $telefoon)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
            }

            Section("Bedrijfsregistratie") {
                TextField("KvK-nummer", text: $kvkNummer)
                TextField("Bank", text: $bank)
                TextField("IBAN", text: $iban)
            }

            Section("Standaard tarieven") {
                HStack {
                    Text("Uurtarief dagpraktijk")
                    Spacer()
                    TextField("Tarief", value: $standaardUurtariefDag, format: .currency(code: "EUR"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Uurtarief ANW-dienst")
                    Spacer()
                    TextField("Tarief", value: $standaardUurtariefANW, format: .currency(code: "EUR"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Kilometertarief")
                    Spacer()
                    TextField("Tarief", value: $standaardKilometertarief, format: .currency(code: "EUR"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }

                Stepper("Betalingstermijn: \(standaardBetalingstermijn) dagen", value: $standaardBetalingstermijn, in: 7...60)
            }

            Section("Factuurnummering") {
                if let settings {
                    HStack {
                        Text("Huidige prefix")
                        Spacer()
                        Text(settings.factuurnummerPrefix)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Laatst gebruikte nummer")
                        Spacer()
                        Text("\(settings.laatsteFactuurnummer)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Volgend factuurnummer")
                        Spacer()
                        Text("\(settings.factuurnummerPrefix)\(String(format: "%03d", settings.laatsteFactuurnummer + 1))")
                            .fontWeight(.medium)
                    }
                }
            }

            Section("Belasting") {
                HStack {
                    Text("BTW-status")
                    Spacer()
                    Text("Vrijgesteld (medische diensten)")
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Urendrempel zelfstandigenaftrek")
                    Spacer()
                    Text("1.225 uur")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Data") {
                Button("Importeer klanten (CSV)") {
                    appState.showImportSheet = true
                }

                Button("Importeer urenregistraties (CSV)") {
                    appState.showImportSheet = true
                }
            }

            Section("Documentopslag") {
                if let settings {
                    HStack {
                        Text("Locatie")
                        Spacer()
                        Text(settings.resolvedDataDirectory.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack {
                        Text("Opslaggebruik")
                        Spacer()
                        Text(settings.formattedStorageUsed)
                            .foregroundStyle(.secondary)
                    }

                    Button("Open documentenmap") {
                        settings.openDocumentsFolder()
                    }

                    Button("Wijzig locatie...") {
                        selectDocumentDirectory()
                    }

                    if settings.dataDirectory != nil && !settings.dataDirectory!.isEmpty {
                        Button("Herstel standaard locatie") {
                            settings.dataDirectory = nil
                            settings.updateTimestamp()
                            try? modelContext.save()
                            hasChanges = false
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }

            Section("Over") {
                HStack {
                    Text("Versie")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Ontwikkeld voor")
                    Spacer()
                    Text("RoBerg huisartswaarnemer")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Instellingen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Opslaan") {
                    saveSettings()
                }
                .disabled(!hasChanges)
            }
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: bedrijfsnaam) { _, _ in hasChanges = true }
        .onChange(of: eigenaar) { _, _ in hasChanges = true }
        .onChange(of: adres) { _, _ in hasChanges = true }
        .onChange(of: postcodeplaats) { _, _ in hasChanges = true }
        .onChange(of: telefoon) { _, _ in hasChanges = true }
        .onChange(of: email) { _, _ in hasChanges = true }
        .onChange(of: kvkNummer) { _, _ in hasChanges = true }
        .onChange(of: iban) { _, _ in hasChanges = true }
        .onChange(of: bank) { _, _ in hasChanges = true }
        .onChange(of: standaardUurtariefDag) { _, _ in hasChanges = true }
        .onChange(of: standaardUurtariefANW) { _, _ in hasChanges = true }
        .onChange(of: standaardKilometertarief) { _, _ in hasChanges = true }
        .onChange(of: standaardBetalingstermijn) { _, _ in hasChanges = true }
        .alert("Instellingen opgeslagen", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $appState.showImportSheet) {
            ImportView()
        }
    }

    private func loadSettings() {
        settings = BusinessSettings.ensureSettingsExist(in: modelContext)

        guard let settings else { return }

        bedrijfsnaam = settings.bedrijfsnaam
        eigenaar = settings.eigenaar
        adres = settings.adres
        postcodeplaats = settings.postcodeplaats
        telefoon = settings.telefoon
        email = settings.email
        kvkNummer = settings.kvkNummer
        iban = settings.iban
        bank = settings.bank
        standaardUurtariefDag = settings.standaardUurtariefDag
        standaardUurtariefANW = settings.standaardUurtariefANW
        standaardKilometertarief = settings.standaardKilometertarief
        standaardBetalingstermijn = settings.standaardBetalingstermijn

        hasChanges = false
    }

    private func saveSettings() {
        guard let settings else { return }

        settings.bedrijfsnaam = bedrijfsnaam
        settings.eigenaar = eigenaar
        settings.adres = adres
        settings.postcodeplaats = postcodeplaats
        settings.telefoon = telefoon
        settings.email = email
        settings.kvkNummer = kvkNummer
        settings.iban = iban
        settings.bank = bank
        settings.standaardUurtariefDag = standaardUurtariefDag
        settings.standaardUurtariefANW = standaardUurtariefANW
        settings.standaardKilometertarief = standaardKilometertarief
        settings.standaardBetalingstermijn = standaardBetalingstermijn
        settings.updateTimestamp()

        try? modelContext.save()

        hasChanges = false
        showingSaveAlert = true

        NotificationCenter.default.post(name: .settingsUpdated, object: nil)
    }

    private func selectDocumentDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Selecteer een map voor documentopslag"
        panel.prompt = "Selecteer"

        if panel.runModal() == .OK, let url = panel.url {
            settings?.dataDirectory = url.path
            settings?.updateTimestamp()
            try? modelContext.save()

            // Ensure directory structure exists in new location
            try? DocumentStorageService.shared.ensureDirectoryStructure(customBasePath: url.path)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
