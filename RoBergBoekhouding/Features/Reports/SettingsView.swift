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
    @State private var isCreatingBackup = false
    @State private var lastBackupDate: Date? = nil
    @State private var showingExportPanel = false
    @State private var showingRestorePanel = false
    @State private var backupValidation: BackupValidation? = nil
    @State private var isRestoring = false
    @State private var restoreResult: RestoreResult? = nil
    @State private var showRestoreConfirmation = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var clearExistingOnRestore = false

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
            backupSection
            overDeAppSection
        }
        .formStyle(.grouped)
        .navigationTitle("Instellingen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    saveSettings()
                } label: {
                    Label("Opslaan", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
                .help("Sla wijzigingen op (⌘S)")
                .keyboardShortcut("s", modifiers: .command)
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

    // MARK: - Backup Section
    private var backupSection: some View {
        Section("Backup & Herstel") {
            // Create backup
            HStack {
                VStack(alignment: .leading) {
                    Text("Backup maken")
                        .font(.subheadline.weight(.medium))
                    Text("Automatische backup in app-map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Maak backup") {
                    Task { await createBackup() }
                }
                .buttonStyle(.bordered)
                .disabled(isCreatingBackup)
            }

            // Export to location
            HStack {
                VStack(alignment: .leading) {
                    Text("Exporteer backup")
                        .font(.subheadline.weight(.medium))
                    Text("Sla op naar iCloud, USB of andere locatie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Exporteer...") {
                    showingExportPanel = true
                }
                .buttonStyle(.bordered)
                .disabled(isCreatingBackup)
            }

            Divider()

            // Restore backup
            HStack {
                VStack(alignment: .leading) {
                    Text("Backup herstellen")
                        .font(.subheadline.weight(.medium))
                    Text("Herstel gegevens uit een backup bestand")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Herstel...") {
                    showingRestorePanel = true
                }
                .buttonStyle(.bordered)
                .disabled(isRestoring)
            }

            // Show restore result
            if let result = restoreResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(result.summary)
                            .font(.caption)
                    }
                    if let skipped = result.skippedSummary {
                        Text(skipped)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Show validation preview
            if let validation = backupValidation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backup bevat:")
                        .font(.caption.weight(.medium))
                    Text("\(validation.clientCount) klanten, \(validation.timeEntryCount) uren, \(validation.invoiceCount) facturen, \(validation.expenseCount) uitgaven")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Gemaakt: \(validation.formattedDate)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            Divider()

            if let lastBackupDate = lastBackupDate {
                HStack {
                    Text("Laatste backup:")
                    Spacer()
                    Text(lastBackupDate, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Open backup map") {
                Task { await BackupService.shared.openBackupFolder() }
            }
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: BackupDocument(modelContext: modelContext),
            contentType: .json,
            defaultFilename: "uurwerker_backup_\(Date().standardDutch).json"
        ) { result in
            switch result {
            case .success(let url):
                appState.showAlert(title: "Backup geëxporteerd", message: "Opgeslagen naar: \(url.lastPathComponent)")
            case .failure(let error):
                appState.showAlert(title: "Export mislukt", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showingRestorePanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreFileSelection(result)
        }
        .alert("Backup herstellen", isPresented: $showRestoreConfirmation) {
            Button("Annuleren", role: .cancel) {
                pendingRestoreURL = nil
                backupValidation = nil
            }
            Button("Samenvoegen") {
                clearExistingOnRestore = false
                performRestore()
            }
            Button("Vervangen", role: .destructive) {
                clearExistingOnRestore = true
                performRestore()
            }
        } message: {
            if let validation = backupValidation {
                Text("Backup van \(validation.formattedDate) met \(validation.totalRecords) records.\n\nSamenvoegen: voeg toe aan bestaande data\nVervangen: wis alles en herstel")
            } else {
                Text("Wil je de backup herstellen?")
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

    private func createBackup() async {
        isCreatingBackup = true
        defer { isCreatingBackup = false }

        do {
            let url = try await BackupService.shared.createBackup(modelContext: modelContext)
            lastBackupDate = Date()
            appState.showAlert(title: "Backup gemaakt", message: "Backup opgeslagen in: \(url.lastPathComponent)")
        } catch {
            appState.showAlert(title: "Backup mislukt", message: error.localizedDescription)
        }
    }

    private func handleRestoreFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                // Copy file to temp location for later access
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try FileManager.default.copyItem(at: url, to: tempURL)

                // Validate backup
                let validation = try BackupService.shared.validateBackup(at: tempURL)
                backupValidation = validation
                pendingRestoreURL = tempURL
                showRestoreConfirmation = true
            } catch {
                appState.showAlert(title: "Ongeldig backup bestand", message: error.localizedDescription)
            }

        case .failure(let error):
            appState.showAlert(title: "Fout bij selecteren", message: error.localizedDescription)
        }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }

        isRestoring = true
        restoreResult = nil

        Task {
            do {
                let result = try await BackupService.shared.restoreBackup(
                    from: url,
                    modelContext: modelContext,
                    clearExisting: clearExistingOnRestore
                )

                await MainActor.run {
                    restoreResult = result
                    isRestoring = false
                    pendingRestoreURL = nil
                    backupValidation = nil

                    // Reload settings if restored
                    if result.settingsRestored {
                        loadSettings()
                    }

                    NotificationCenter.default.post(name: .dataImported, object: result)
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    appState.showAlert(title: "Herstel mislukt", message: error.localizedDescription)
                }
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Backup Document for File Exporter
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not supported - use file importer instead")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create backup data synchronously for file exporter
        let clientDescriptor = FetchDescriptor<Client>()
        let clients = try modelContext.fetch(clientDescriptor)

        let timeEntryDescriptor = FetchDescriptor<TimeEntry>()
        let timeEntries = try modelContext.fetch(timeEntryDescriptor)

        let invoiceDescriptor = FetchDescriptor<Invoice>()
        let invoices = try modelContext.fetch(invoiceDescriptor)

        let expenseDescriptor = FetchDescriptor<Expense>()
        let expenses = try modelContext.fetch(expenseDescriptor)

        let settingsDescriptor = FetchDescriptor<BusinessSettings>()
        let settings = try modelContext.fetch(settingsDescriptor)

        let backupData = BackupData(
            version: "1.0",
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            clients: clients.map { ClientExport(from: $0) },
            timeEntries: timeEntries.map { TimeEntryExport(from: $0) },
            invoices: invoices.map { InvoiceExport(from: $0) },
            expenses: expenses.map { ExpenseExport(from: $0) },
            settings: settings.first.map { SettingsExport(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(backupData)
        return FileWrapper(regularFileWithContents: jsonData)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
