import Foundation
import SwiftData
import AppKit

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

    // MARK: - Export Backup to User Location
    /// Exports backup to a user-selected location
    func exportBackup(modelContext: ModelContext, to destinationURL: URL) async throws {
        let exportData = try await exportAllData(modelContext: modelContext)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: destinationURL)
    }

    // MARK: - Restore Backup
    /// Restores data from a backup file
    /// - Parameters:
    ///   - url: URL of the backup JSON file
    ///   - modelContext: The SwiftData model context
    ///   - clearExisting: If true, deletes all existing data before restore
    /// - Returns: RestoreResult with counts of restored items
    func restoreBackup(from url: URL, modelContext: ModelContext, clearExisting: Bool) async throws -> RestoreResult {
        // Read and decode backup file
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        // Clear existing data if requested
        if clearExisting {
            try await clearAllData(modelContext: modelContext)
        }

        var result = RestoreResult()

        // 1. Restore Settings first
        if let settingsExport = backupData.settings {
            let settings = BusinessSettings(
                bedrijfsnaam: settingsExport.bedrijfsnaam,
                eigenaar: settingsExport.eigenaar,
                adres: settingsExport.adres,
                postcodeplaats: settingsExport.postcodeplaats,
                telefoon: settingsExport.telefoon,
                email: settingsExport.email,
                kvkNummer: settingsExport.kvkNummer,
                iban: settingsExport.iban,
                bank: settingsExport.bank,
                standaardUurtariefDag: settingsExport.standaardUurtariefDag,
                standaardKilometertarief: settingsExport.standaardKilometertarief,
                standaardBetalingstermijn: settingsExport.standaardBetalingstermijn
            )
            modelContext.insert(settings)
            result.settingsRestored = true
        }

        // 2. Restore Clients - build ID mapping for relationships
        var clientMap: [UUID: Client] = [:]
        for clientExport in backupData.clients {
            // Check for duplicate by name if not clearing
            if !clearExisting {
                let descriptor = FetchDescriptor<Client>(
                    predicate: #Predicate { $0.bedrijfsnaam == clientExport.bedrijfsnaam }
                )
                if let existing = try? modelContext.fetch(descriptor).first {
                    clientMap[clientExport.id] = existing
                    result.clientsSkipped += 1
                    continue
                }
            }

            let client = Client(
                bedrijfsnaam: clientExport.bedrijfsnaam,
                contactpersoon: clientExport.contactpersoon,
                adres: clientExport.adres,
                postcodeplaats: clientExport.postcodeplaats,
                telefoon: clientExport.telefoon,
                email: clientExport.email,
                standaardUurtarief: clientExport.standaardUurtarief,
                standaardKmTarief: clientExport.standaardKmTarief,
                afstandRetour: clientExport.afstandRetour,
                clientType: ClientType(rawValue: clientExport.clientType) ?? .zakelijk,
                isActive: clientExport.isActive
            )
            modelContext.insert(client)
            clientMap[clientExport.id] = client
            result.clientsRestored += 1
        }

        // 3. Restore Expenses
        for expenseExport in backupData.expenses {
            // Check for duplicate by date + amount + description
            if !clearExisting {
                let datum = expenseExport.datum
                let bedrag = expenseExport.bedrag
                let omschrijving = expenseExport.omschrijving
                let descriptor = FetchDescriptor<Expense>(
                    predicate: #Predicate { $0.datum == datum && $0.bedrag == bedrag && $0.omschrijving == omschrijving }
                )
                if (try? modelContext.fetch(descriptor).first) != nil {
                    result.expensesSkipped += 1
                    continue
                }
            }

            let expense = Expense(
                datum: expenseExport.datum,
                omschrijving: expenseExport.omschrijving,
                bedrag: expenseExport.bedrag,
                categorie: ExpenseCategory(rawValue: expenseExport.categorie) ?? .overig,
                leverancier: expenseExport.leverancier,
                zakelijkPercentage: expenseExport.zakelijkPercentage,
                isRecurring: expenseExport.isRecurring
            )
            expense.documentPath = expenseExport.documentPath
            modelContext.insert(expense)
            result.expensesRestored += 1
        }

        // 4. Restore Time Entries
        var entryMap: [UUID: TimeEntry] = [:]
        for entryExport in backupData.timeEntries {
            // Check for duplicate by date + client + hours
            if !clearExisting {
                let datum = entryExport.datum
                let uren = entryExport.uren
                let descriptor = FetchDescriptor<TimeEntry>(
                    predicate: #Predicate { $0.datum == datum && $0.uren == uren }
                )
                if let existing = try? modelContext.fetch(descriptor).first,
                   existing.client?.id == entryExport.clientId {
                    entryMap[entryExport.id] = existing
                    result.timeEntriesSkipped += 1
                    continue
                }
            }

            let entry = TimeEntry(
                datum: entryExport.datum,
                activiteit: entryExport.activiteit,
                locatie: entryExport.locatie,
                uren: entryExport.uren,
                visiteKilometers: entryExport.visiteKilometers,
                retourafstandWoonWerk: entryExport.retourafstandWoonWerk,
                uurtarief: entryExport.uurtarief,
                kilometertarief: entryExport.kilometertarief,
                isBillable: entryExport.isBillable,
                isInvoiced: entryExport.isInvoiced,
                factuurnummer: entryExport.factuurnummer
            )

            // Link to client
            if let clientId = entryExport.clientId, let client = clientMap[clientId] {
                entry.client = client
            }

            modelContext.insert(entry)
            entryMap[entryExport.id] = entry
            result.timeEntriesRestored += 1
        }

        // 5. Restore Invoices and link time entries
        for invoiceExport in backupData.invoices {
            // Check for duplicate by invoice number
            if !clearExisting {
                let nummer = invoiceExport.factuurnummer
                let descriptor = FetchDescriptor<Invoice>(
                    predicate: #Predicate { $0.factuurnummer == nummer }
                )
                if (try? modelContext.fetch(descriptor).first) != nil {
                    result.invoicesSkipped += 1
                    continue
                }
            }

            let invoice = Invoice(
                factuurnummer: invoiceExport.factuurnummer,
                factuurdatum: invoiceExport.factuurdatum,
                betalingstermijn: 14,
                status: InvoiceStatus(rawValue: invoiceExport.status) ?? .concept
            )
            invoice.notities = invoiceExport.notities
            invoice.pdfPath = invoiceExport.pdfPath

            // Link to client
            if let clientId = invoiceExport.clientId, let client = clientMap[clientId] {
                invoice.client = client
            }

            // Link time entries by matching factuurnummer
            let matchingEntries = backupData.timeEntries.filter { $0.factuurnummer == invoiceExport.factuurnummer }
            for entryExport in matchingEntries {
                if let entry = entryMap[entryExport.id] {
                    entry.invoice = invoice
                    entry.isInvoiced = true
                }
            }

            modelContext.insert(invoice)
            result.invoicesRestored += 1
        }

        try modelContext.save()
        return result
    }

    // MARK: - Clear All Data
    private func clearAllData(modelContext: ModelContext) async throws {
        // Delete in order to respect relationships
        let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
        for invoice in invoices { modelContext.delete(invoice) }

        let entries = try modelContext.fetch(FetchDescriptor<TimeEntry>())
        for entry in entries { modelContext.delete(entry) }

        let expenses = try modelContext.fetch(FetchDescriptor<Expense>())
        for expense in expenses { modelContext.delete(expense) }

        let clients = try modelContext.fetch(FetchDescriptor<Client>())
        for client in clients { modelContext.delete(client) }

        let settings = try modelContext.fetch(FetchDescriptor<BusinessSettings>())
        for setting in settings { modelContext.delete(setting) }

        try modelContext.save()
    }

    // MARK: - Validate Backup File
    /// Validates a backup file without importing
    func validateBackup(at url: URL) throws -> BackupValidation {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        return BackupValidation(
            isValid: true,
            version: backupData.version,
            appVersion: backupData.appVersion,
            createdAt: backupData.createdAt,
            clientCount: backupData.clients.count,
            timeEntryCount: backupData.timeEntries.count,
            invoiceCount: backupData.invoices.count,
            expenseCount: backupData.expenses.count,
            hasSettings: backupData.settings != nil
        )
    }
}

// MARK: - Restore Result
struct RestoreResult {
    var settingsRestored: Bool = false
    var clientsRestored: Int = 0
    var clientsSkipped: Int = 0
    var timeEntriesRestored: Int = 0
    var timeEntriesSkipped: Int = 0
    var invoicesRestored: Int = 0
    var invoicesSkipped: Int = 0
    var expensesRestored: Int = 0
    var expensesSkipped: Int = 0

    var summary: String {
        var parts: [String] = []
        if clientsRestored > 0 { parts.append("\(clientsRestored) klanten") }
        if timeEntriesRestored > 0 { parts.append("\(timeEntriesRestored) uren") }
        if invoicesRestored > 0 { parts.append("\(invoicesRestored) facturen") }
        if expensesRestored > 0 { parts.append("\(expensesRestored) uitgaven") }
        if settingsRestored { parts.append("instellingen") }

        if parts.isEmpty { return "Geen nieuwe gegevens hersteld" }
        return "Hersteld: " + parts.joined(separator: ", ")
    }

    var skippedSummary: String? {
        var parts: [String] = []
        if clientsSkipped > 0 { parts.append("\(clientsSkipped) klanten") }
        if timeEntriesSkipped > 0 { parts.append("\(timeEntriesSkipped) uren") }
        if invoicesSkipped > 0 { parts.append("\(invoicesSkipped) facturen") }
        if expensesSkipped > 0 { parts.append("\(expensesSkipped) uitgaven") }

        if parts.isEmpty { return nil }
        return "Overgeslagen (duplicaten): " + parts.joined(separator: ", ")
    }
}

// MARK: - Backup Validation
struct BackupValidation {
    let isValid: Bool
    let version: String
    let appVersion: String
    let createdAt: Date
    let clientCount: Int
    let timeEntryCount: Int
    let invoiceCount: Int
    let expenseCount: Int
    let hasSettings: Bool

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: createdAt)
    }

    var totalRecords: Int {
        clientCount + timeEntryCount + invoiceCount + expenseCount + (hasSettings ? 1 : 0)
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
    let contactpersoon: String?
    let email: String?
    let telefoon: String?
    let adres: String
    let postcodeplaats: String
    let clientType: String
    let isActive: Bool
    let standaardUurtarief: Decimal
    let standaardKmTarief: Decimal
    let afstandRetour: Int

    init(from client: Client) {
        self.id = client.id
        self.bedrijfsnaam = client.bedrijfsnaam
        self.contactpersoon = client.contactpersoon
        self.email = client.email
        self.telefoon = client.telefoon
        self.adres = client.adres
        self.postcodeplaats = client.postcodeplaats
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
    let retourafstandWoonWerk: Int
    let visiteKilometers: Decimal?
    let kilometertarief: Decimal
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
        self.kilometertarief = entry.kilometertarief
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
    let zakelijkPercentage: Decimal
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
    let postcodeplaats: String
    let email: String
    let telefoon: String
    let kvkNummer: String
    let iban: String
    let bank: String
    let standaardUurtariefDag: Decimal
    let standaardKilometertarief: Decimal
    let standaardBetalingstermijn: Int

    init(from settings: BusinessSettings) {
        self.bedrijfsnaam = settings.bedrijfsnaam
        self.eigenaar = settings.eigenaar
        self.adres = settings.adres
        self.postcodeplaats = settings.postcodeplaats
        self.email = settings.email
        self.telefoon = settings.telefoon
        self.kvkNummer = settings.kvkNummer
        self.iban = settings.iban
        self.bank = settings.bank
        self.standaardUurtariefDag = settings.standaardUurtariefDag
        self.standaardKilometertarief = settings.standaardKilometertarief
        self.standaardBetalingstermijn = settings.standaardBetalingstermijn
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
