import Foundation
import SwiftData

@Model
final class BusinessSettings {
    // MARK: - Business Information
    var id: UUID
    var bedrijfsnaam: String
    var eigenaar: String
    var adres: String
    var postcodeplaats: String
    var telefoon: String
    var email: String
    var kvkNummer: String
    var iban: String
    var bank: String

    // MARK: - Default Rates
    var standaardUurtariefDag: Decimal      // €70.00
    var standaardUurtariefANW: Decimal      // €124.00
    var standaardKilometertarief: Decimal   // €0.23
    var standaardBetalingstermijn: Int      // 14 days

    // MARK: - Invoice Settings
    var factuurnummerPrefix: String         // "2025-"
    var laatsteFactuurnummer: Int           // Last used number

    // MARK: - Tax Settings
    var urendrempelZelfstandigenaftrek: Int // 1225 hours minimum
    var btwVrijgesteld: Bool                // Legacy: Healthcare is BTW exempt
    var standaardBTWTariefRaw: String       // Default BTW tarief for new invoices

    // MARK: - Branding
    var logoPath: String?                   // Path to company logo
    var primaryColorHex: String?            // Brand color for invoices
    var invoiceFooterText: String?          // Custom invoice footer text

    // MARK: - File Paths
    var dataDirectory: String?              // Path to bookkeeping files
    var exportDirectory: String?            // Path for exports

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Current year prefix for invoice numbers
    var currentYearPrefix: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(year)-"
    }

    /// Full business address block for invoices
    var addressBlock: String {
        """
        \(bedrijfsnaam)
        \(eigenaar)
        \(adres)
        \(postcodeplaats)
        """
    }

    /// Contact info block for invoices
    var contactBlock: String {
        """
        Tel. \(telefoon)
        Mail: \(email)
        KvK: \(kvkNummer)
        Bank: \(bank)
        IBAN: \(iban)
        """
    }

    /// Payment instruction text for invoices
    var paymentInstruction: String {
        """
        Gelieve het bovenstaand bedrag binnen \(standaardBetalingstermijn) dagen na dagtekening over te maken op bankrekening
        \(iban) ten name van \(bedrijfsnaam) onder vermelding van het factuurnummer.
        """
    }

    /// Resolved documents directory URL (custom or default)
    var resolvedDataDirectory: URL {
        DocumentStorageService.shared.documentsDirectory(customPath: dataDirectory)
    }

    /// Resolved export directory URL (custom or default to documents)
    var resolvedExportDirectory: URL {
        if let path = exportDirectory, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return resolvedDataDirectory
    }

    /// Default BTW tarief for new invoices
    var standaardBTWTarief: BTWTarief {
        get { BTWTarief(rawValue: standaardBTWTariefRaw) ?? .vrijgesteld }
        set { standaardBTWTariefRaw = newValue.rawValue }
    }

    /// Get full URL to logo if exists
    var logoURL: URL? {
        guard let path = logoPath, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Brand color for invoices (defaults to blue)
    var primaryColor: String {
        primaryColorHex ?? "#2563eb"
    }

    /// Formatted storage size used by documents
    var formattedStorageUsed: String {
        DocumentStorageService.shared.formattedStorageUsed(customBasePath: dataDirectory)
    }

    /// Open the documents folder in Finder
    func openDocumentsFolder() {
        DocumentStorageService.shared.openDocumentsFolder(customBasePath: dataDirectory)
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        bedrijfsnaam: String = "RoBerg huisartswaarnemer",
        eigenaar: String = "R. Hoogenberg",
        adres: String = "Bastion 3",
        postcodeplaats: String = "9723 ZH Groningen",
        telefoon: String = "06 432 67 791",
        email: String = "ronaldhoogenberg@hotmail.com",
        kvkNummer: String = "90103777",
        iban: String = "NL74 RABO 0344 1916 80",
        bank: String = "Rabobank",
        standaardUurtariefDag: Decimal = 70.00,
        standaardUurtariefANW: Decimal = 124.00,
        standaardKilometertarief: Decimal = 0.23,
        standaardBetalingstermijn: Int = 14,
        laatsteFactuurnummer: Int = 0,
        urendrempelZelfstandigenaftrek: Int = 1225,
        btwVrijgesteld: Bool = true,
        standaardBTWTarief: BTWTarief = .vrijgesteld,
        logoPath: String? = nil,
        primaryColorHex: String? = nil,
        invoiceFooterText: String? = nil
    ) {
        self.id = id
        self.bedrijfsnaam = bedrijfsnaam
        self.eigenaar = eigenaar
        self.adres = adres
        self.postcodeplaats = postcodeplaats
        self.telefoon = telefoon
        self.email = email
        self.kvkNummer = kvkNummer
        self.iban = iban
        self.bank = bank
        self.standaardUurtariefDag = standaardUurtariefDag
        self.standaardUurtariefANW = standaardUurtariefANW
        self.standaardKilometertarief = standaardKilometertarief
        self.standaardBetalingstermijn = standaardBetalingstermijn
        self.factuurnummerPrefix = "\(Calendar.current.component(.year, from: Date()))-"
        self.laatsteFactuurnummer = laatsteFactuurnummer
        self.urendrempelZelfstandigenaftrek = urendrempelZelfstandigenaftrek
        self.btwVrijgesteld = btwVrijgesteld
        self.standaardBTWTariefRaw = standaardBTWTarief.rawValue
        self.logoPath = logoPath
        self.primaryColorHex = primaryColorHex
        self.invoiceFooterText = invoiceFooterText
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods

    func updateTimestamp() {
        updatedAt = Date()
    }

    /// Generate next invoice number and increment counter
    func generateNextInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())

        // Reset counter if year changed
        if !factuurnummerPrefix.hasPrefix("\(year)") {
            factuurnummerPrefix = "\(year)-"
            laatsteFactuurnummer = 0
        }

        laatsteFactuurnummer += 1
        updateTimestamp()

        return String(format: "%d-%03d", year, laatsteFactuurnummer)
    }

    /// Update prefix for new year
    func updateYearPrefix() {
        let year = Calendar.current.component(.year, from: Date())
        let currentPrefix = "\(year)-"

        if factuurnummerPrefix != currentPrefix {
            factuurnummerPrefix = currentPrefix
            laatsteFactuurnummer = 0
            updateTimestamp()
        }
    }
}

// MARK: - Default Settings
extension BusinessSettings {
    /// Default settings for RoBerg huisartswaarnemer
    static var defaultSettings: BusinessSettings {
        BusinessSettings()
    }

    /// Check if settings exist, otherwise create defaults
    /// Also ensures only one settings record exists (deletes duplicates)
    static func ensureSettingsExist(in context: ModelContext) -> BusinessSettings {
        let descriptor = FetchDescriptor<BusinessSettings>()

        do {
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty {
                // Keep the first (oldest) settings record, delete any duplicates
                let settingsToKeep = existing[0]
                if existing.count > 1 {
                    for duplicateSettings in existing.dropFirst() {
                        context.delete(duplicateSettings)
                    }
                    try? context.save()
                }
                settingsToKeep.updateYearPrefix()
                return settingsToKeep
            }
        } catch {
            print("Error fetching settings: \(error)")
        }

        // Create default settings
        let newSettings = BusinessSettings.defaultSettings
        context.insert(newSettings)
        return newSettings
    }
}
