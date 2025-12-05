import Foundation
import SwiftData

// MARK: - Backup Service
/// Service for creating and managing database backups
actor BackupService {

    // MARK: - Singleton
    static let shared = BackupService()

    private init() {}

    // MARK: - Backup Directory
    private var backupDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Uurwerker", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: - Create Backup
    /// Creates a backup of the current database
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: URL of the created backup file
    func createBackup(modelContext: ModelContext) async throws -> URL {
        // Ensure backup directory exists
        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )

        // Create timestamp for filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let backupURL = backupDirectory
            .appendingPathComponent("backup_\(timestamp).json")

        // Export all data to JSON
        let exportData = try await exportAllData(modelContext: modelContext)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: backupURL)

        // Clean up old backups (keep last 10)
        try cleanupOldBackups()

        return backupURL
    }

    // MARK: - Export All Data
    private func exportAllData(modelContext: ModelContext) async throws -> BackupData {
        // Fetch all entities
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

        return BackupData(
            version: "1.0",
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            clients: clients.map { ClientExport(from: $0) },
            timeEntries: timeEntries.map { TimeEntryExport(from: $0) },
            invoices: invoices.map { InvoiceExport(from: $0) },
            expenses: expenses.map { ExpenseExport(from: $0) },
            settings: settings.first.map { SettingsExport(from: $0) }
        )
    }

    // MARK: - List Backups
    /// Lists all available backups
    func listBackups() throws -> [BackupInfo] {
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupInfo? in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let createdAt = attributes[.creationDate] as? Date,
                      let size = attributes[.size] as? Int else {
                    return nil
                }

                return BackupInfo(
                    url: url,
                    filename: url.lastPathComponent,
                    createdAt: createdAt,
                    sizeBytes: size
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete Backup
    func deleteBackup(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Cleanup Old Backups
    private func cleanupOldBackups(keepCount: Int = 10) throws {
        let backups = try listBackups()

        guard backups.count > keepCount else { return }

        let toDelete = backups.dropFirst(keepCount)
        for backup in toDelete {
            try? FileManager.default.removeItem(at: backup.url)
        }
    }

    // MARK: - Open Backup Folder
    func openBackupFolder() {
        NSWorkspace.shared.open(backupDirectory)
    }

    // MARK: - Backup Size
    func totalBackupSize() throws -> Int {
        let backups = try listBackups()
        return backups.reduce(0) { $0 + $1.sizeBytes }
    }
}

// MARK: - Backup Data Model
struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let appVersion: String
    let clients: [ClientExport]
    let timeEntries: [TimeEntryExport]
    let invoices: [InvoiceExport]
    let expenses: [ExpenseExport]
    let settings: SettingsExport?
}

// MARK: - Export Models
struct ClientExport: Codable {
    let id: UUID
    let bedrijfsnaam: String
    let naam: String?
    let email: String?
    let telefoon: String?
    let adres: String?
    let postcode: String?
    let plaats: String?
    let clientType: String
    let isActive: Bool
    let standaardUurtarief: Decimal?
    let standaardKmTarief: Decimal?
    let afstandRetour: Int?

    init(from client: Client) {
        self.id = client.id
        self.bedrijfsnaam = client.bedrijfsnaam
        self.naam = client.naam
        self.email = client.email
        self.telefoon = client.telefoon
        self.adres = client.adres
        self.postcode = client.postcode
        self.plaats = client.plaats
        self.clientType = client.clientTypeRaw
        self.isActive = client.isActive
        self.standaardUurtarief = client.standaardUurtarief
        self.standaardKmTarief = client.standaardKmTarief
        self.afstandRetour = client.afstandRetour
    }
}

struct TimeEntryExport: Codable {
    let id: UUID
    let datum: Date
    let uren: Decimal
    let uurtarief: Decimal
    let retourafstandWoonWerk: Decimal
    let visiteKilometers: Decimal
    let kmtarief: Decimal
    let activiteit: String
    let locatie: String
    let isBillable: Bool
    let isInvoiced: Bool
    let clientId: UUID?
    let factuurnummer: String?

    init(from entry: TimeEntry) {
        self.id = entry.id
        self.datum = entry.datum
        self.uren = entry.uren
        self.uurtarief = entry.uurtarief
        self.retourafstandWoonWerk = entry.retourafstandWoonWerk
        self.visiteKilometers = entry.visiteKilometers
        self.kmtarief = entry.kmtarief
        self.activiteit = entry.activiteit
        self.locatie = entry.locatie
        self.isBillable = entry.isBillable
        self.isInvoiced = entry.isInvoiced
        self.clientId = entry.client?.id
        self.factuurnummer = entry.factuurnummer
    }
}

struct InvoiceExport: Codable {
    let id: UUID
    let factuurnummer: String
    let factuurdatum: Date
    let vervaldatum: Date
    let status: String
    let notities: String?
    let clientId: UUID?
    let pdfPath: String?
    let btwTarief: String?
    let totaalbedrag: Decimal

    init(from invoice: Invoice) {
        self.id = invoice.id
        self.factuurnummer = invoice.factuurnummer
        self.factuurdatum = invoice.factuurdatum
        self.vervaldatum = invoice.vervaldatum
        self.status = invoice.statusRaw
        self.notities = invoice.notities
        self.clientId = invoice.client?.id
        self.pdfPath = invoice.pdfPath
        self.btwTarief = invoice.btwTariefRaw
        self.totaalbedrag = invoice.totaalbedrag
    }
}

struct ExpenseExport: Codable {
    let id: UUID
    let datum: Date
    let omschrijving: String
    let bedrag: Decimal
    let categorie: String
    let leverancier: String?
    let zakelijkPercentage: Int
    let isRecurring: Bool
    let documentPath: String?

    init(from expense: Expense) {
        self.id = expense.id
        self.datum = expense.datum
        self.omschrijving = expense.omschrijving
        self.bedrag = expense.bedrag
        self.categorie = expense.categorieRaw
        self.leverancier = expense.leverancier
        self.zakelijkPercentage = expense.zakelijkPercentage
        self.isRecurring = expense.isRecurring
        self.documentPath = expense.documentPath
    }
}

struct SettingsExport: Codable {
    let bedrijfsnaam: String
    let eigenaar: String
    let adres: String
    let email: String
    let telefoon: String
    let kvkNummer: String
    let btwNummer: String
    let standaardUurtariefDag: Decimal
    let standaardKilometertarief: Decimal
    let betalingstermijn: Int

    init(from settings: BusinessSettings) {
        self.bedrijfsnaam = settings.bedrijfsnaam
        self.eigenaar = settings.eigenaar
        self.adres = settings.adres
        self.email = settings.email
        self.telefoon = settings.telefoon
        self.kvkNummer = settings.kvkNummer
        self.btwNummer = settings.btwNummer
        self.standaardUurtariefDag = settings.standaardUurtariefDag
        self.standaardKilometertarief = settings.standaardKilometertarief
        self.betalingstermijn = settings.betalingstermijn
    }
}

// MARK: - Backup Info
struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let createdAt: Date
    let sizeBytes: Int

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeBytes))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: createdAt)
    }
}
