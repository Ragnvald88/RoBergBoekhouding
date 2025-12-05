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
    @State private var standaardBTWTarief: BTWTarief = .vrijgesteld

    @State private var hasChanges = false
    @State private var showingSaveAlert = false
    @State private var showingAboutView = false

    var body: some View {
        settingsForm
            .sheet(isPresented: $showingAboutView) {
                AboutView()
            }
            .sheet(isPresented: $appState.showImportSheet) {
                ImportView()
            }
            .alert("Instellingen opgeslagen", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            }
    }

    private var settingsForm: some View {
        Form {
            bedrijfsgegevensSection
            contactSection
            registratieSection
            tarievenSection
            factuurnummeringSection
            belastingSection
            dataSection
            documentopslagSection
            overDeAppSection
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
        .onAppear(perform: loadSettings)
        .onChange(of: bedrijfsnaam) { markChanged() }
        .onChange(of: eigenaar) { markChanged() }
        .onChange(of: adres) { markChanged() }
        .onChange(of: postcodeplaats) { markChanged() }
        .onChange(of: telefoon) { markChanged() }
        .onChange(of: email) { markChanged() }
        .onChange(of: kvkNummer) { markChanged() }
        .onChange(of: iban) { markChanged() }
        .onChange(of: bank) { markChanged() }
        .onChange(of: standaardUurtariefDag) { markChanged() }
        .onChange(of: standaardUurtariefANW) { markChanged() }
        .onChange(of: standaardKilometertarief) { markChanged() }
        .onChange(of: standaardBetalingstermijn) { markChanged() }
        .onChange(of: standaardBTWTarief) { markChanged() }
    }

    private func markChanged() {
        hasChanges = true
    }

    // MARK: - Extracted Sections

    private var bedrijfsgegevensSection: some View {
        Section("Bedrijfsgegevens") {
            TextField("Bedrijfsnaam", text: $bedrijfsnaam)
            TextField("Eigenaar", text: $eigenaar)
            TextField("Adres", text: $adres)
            TextField("Postcode en plaats", text: $postcodeplaats)
        }
    }

    private var contactSection: some View {
        Section("Contactgegevens") {
            TextField("Telefoon", text: $telefoon)
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
        }
    }

    private var registratieSection: some View {
        Section("Bedrijfsregistratie") {
            TextField("KvK-nummer", text: $kvkNummer)
            TextField("Bank", text: $bank)
            TextField("IBAN", text: $iban)
        }
    }

    private var tarievenSection: some View {
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
    }

    private var factuurnummeringSection: some View {
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
    }

    private var belastingSection: some View {
        Section("Belasting") {
            Picker("Standaard BTW-tarief", selection: $standaardBTWTarief) {
                ForEach(BTWTarief.allCases, id: \.self) { tarief in
                    Text(tarief.displayName).tag(tarief)
                }
            }
            if standaardBTWTarief == .vrijgesteld {
                Text("BTW-vrijgestelde diensten volgens artikel 11, lid 1, onderdeel g, Wet OB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Urendrempel zelfstandigenaftrek")
                Spacer()
                Text("1.225 uur")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Importeer klanten (CSV)") {
                appState.showImportSheet = true
            }
            Button("Importeer urenregistraties (CSV)") {
                appState.showImportSheet = true
            }
        }
    }

    @ViewBuilder
    private var documentopslagSection: some View {
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
    }

    private var overDeAppSection: some View {
        Section("Over de app") {
            Button {
                showingAboutView = true
            } label: {
                HStack {
                    Text("Over deze app")
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Methods

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
        standaardBTWTarief = settings.standaardBTWTarief

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
        settings.standaardBTWTarief = standaardBTWTarief
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

// MARK: - About View

/// About view showing app information - Required for App Store
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    // App version info
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("App icoon")

                VStack(spacing: 4) {
                    Text("RoBerg Boekhouding")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Versie \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Boekhouding voor ZZP'ers")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Functies")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Urenregistratie", systemImage: "clock")
                            Label("Facturatie met BTW", systemImage: "doc.text")
                            Label("Klantenbeheer", systemImage: "person.2")
                            Label("Uitgavenbeheer", systemImage: "creditcard")
                        }
                        .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Privacy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy")
                            .font(.headline)
                        Text("Al je gegevens blijven lokaal op je Mac. Deze app verzamelt geen data en maakt geen verbinding met externe servers.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\u{00A9} 2025 RoBerg. Alle rechten voorbehouden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button("Sluiten") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
