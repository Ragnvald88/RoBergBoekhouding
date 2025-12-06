import Foundation
import SwiftData

/// Asset category for depreciable business assets
enum AssetCategory: String, Codable, CaseIterable {
    case computer = "Computer/Laptop"
    case telefoon = "Telefoon/Tablet"
    case kantoorinventaris = "Kantoorinventaris"
    case medischeApparatuur = "Medische apparatuur"
    case vervoermiddel = "Vervoermiddel"
    case software = "Software licenties"
    case gereedschap = "Gereedschap"
    case overig = "Overige bedrijfsmiddelen"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .computer: return "laptopcomputer"
        case .telefoon: return "iphone"
        case .kantoorinventaris: return "chair.lounge"
        case .medischeApparatuur: return "stethoscope"
        case .vervoermiddel: return "car"
        case .software: return "app.badge"
        case .gereedschap: return "wrench.and.screwdriver"
        case .overig: return "shippingbox"
        }
    }

    /// Default depreciation years per category
    var defaultYears: Int {
        switch self {
        case .computer, .telefoon, .software: return 5
        case .kantoorinventaris, .gereedschap: return 7
        case .medischeApparatuur: return 5
        case .vervoermiddel: return 5
        case .overig: return 5
        }
    }
}

@Model
final class Asset {
    // MARK: - Properties
    var id: UUID
    var naam: String                        // "MacBook Pro 16"
    var omschrijving: String?               // Additional details
    var aanschafdatum: Date                 // Purchase date
    var inGebruikDatum: Date                // Date put into use (depreciation starts)
    var aanschafwaarde: Decimal             // Purchase price (excl. BTW)
    var btwBedrag: Decimal                  // BTW amount paid
    var restwaarde: Decimal                 // Residual value
    var afschrijvingsjaren: Int             // Depreciation years
    var categorieRaw: String                // Asset category
    var leverancier: String?                // Supplier
    var factuurNummer: String?              // Supplier invoice number
    var documentPath: String?               // Receipt/invoice path
    var zakelijkPercentage: Decimal         // Business use percentage
    var isActief: Bool                      // Still in use
    var verkoopDatum: Date?                 // Date sold/disposed
    var verkoopWaarde: Decimal?             // Sale value if sold
    var notities: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var expense: Expense?                   // Original expense that created this asset

    // MARK: - Computed Properties

    var categorie: AssetCategory {
        get { AssetCategory(rawValue: categorieRaw) ?? .overig }
        set { categorieRaw = newValue.rawValue }
    }

    /// Depreciable amount (purchase - residual)
    var afschrijfbaarBedrag: Decimal {
        aanschafwaarde - restwaarde
    }

    /// Annual depreciation amount (business portion only)
    var jaarlijkseAfschrijving: Decimal {
        let annual = afschrijfbaarBedrag / Decimal(afschrijvingsjaren)
        return annual * (zakelijkPercentage / 100)
    }

    /// Full years the asset has been in use
    var jarenInGebruik: Int {
        let calendar = Calendar.current
        let endDate = verkoopDatum ?? Date()
        let components = calendar.dateComponents([.year], from: inGebruikDatum, to: endDate)
        return max(0, components.year ?? 0)
    }

    /// Months in use for current year (for partial year calculation)
    var maandenInGebruikHuidigJaar: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: inGebruikDatum)

        if startYear == currentYear {
            // Asset purchased this year
            let startMonth = calendar.component(.month, from: inGebruikDatum)
            let currentMonth = calendar.component(.month, from: Date())
            return currentMonth - startMonth + 1
        } else if startYear < currentYear {
            // Asset purchased in previous year
            return 12
        }
        return 0
    }

    /// Total depreciation to date
    var afschrijvingTotDatum: Decimal {
        let fullYears = min(jarenInGebruik, afschrijvingsjaren)
        var total = jaarlijkseAfschrijving * Decimal(fullYears)

        // Add partial year if still depreciating
        if jarenInGebruik < afschrijvingsjaren {
            let partialYear = jaarlijkseAfschrijving * Decimal(maandenInGebruikHuidigJaar) / 12
            total += partialYear
        }

        // Cannot exceed depreciable amount
        return min(total, afschrijfbaarBedrag * (zakelijkPercentage / 100))
    }

    /// Current book value
    var boekwaarde: Decimal {
        let businessPortion = aanschafwaarde * (zakelijkPercentage / 100)
        return max(restwaarde * (zakelijkPercentage / 100), businessPortion - afschrijvingTotDatum)
    }

    /// Remaining years of depreciation
    var resterendeJaren: Int {
        max(0, afschrijvingsjaren - jarenInGebruik)
    }

    /// Whether asset is fully depreciated
    var isVolledigAfgeschreven: Bool {
        jarenInGebruik >= afschrijvingsjaren
    }

    /// Depreciation for a specific year
    /// Uses pro-rata calculation for first and last years based on months in use.
    func afschrijvingVoorJaar(_ year: Int) -> Decimal {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: inGebruikDatum)
        let startMonth = calendar.component(.month, from: inGebruikDatum)

        // Calculate the actual end year, accounting for partial first year
        // If start is not January, depreciation extends into an extra year
        let monthsInFirstYear = 13 - startMonth
        let remainingMonths = (afschrijvingsjaren * 12) - monthsInFirstYear
        let additionalFullYears = remainingMonths / 12
        let monthsInLastYear = remainingMonths % 12
        let endYear = startYear + 1 + additionalFullYears + (monthsInLastYear > 0 ? 1 : 0) - 1

        guard year >= startYear && year <= endYear else { return 0 }

        // Handle sale - no depreciation after sale year
        if let verkoopDatum = verkoopDatum {
            let saleYear = calendar.component(.year, from: verkoopDatum)
            if year > saleYear { return 0 }

            // Partial year if sold during the year
            if year == saleYear {
                let saleMonth = calendar.component(.month, from: verkoopDatum)
                if year == startYear {
                    // Sold in same year as purchase
                    let months = saleMonth - startMonth + 1
                    return jaarlijkseAfschrijving * Decimal(max(0, months)) / 12
                } else {
                    // Sold in a later year
                    return jaarlijkseAfschrijving * Decimal(saleMonth) / 12
                }
            }
        }

        // First year: partial (from start month to December)
        if year == startYear {
            let months = 13 - startMonth // Months remaining in first year
            return jaarlijkseAfschrijving * Decimal(months) / 12
        }

        // Last year: partial (January to anniversary month - 1)
        // This is the remaining portion that completes the full depreciation period
        if year == endYear && monthsInLastYear > 0 {
            return jaarlijkseAfschrijving * Decimal(monthsInLastYear) / 12
        }

        // Full year (applies to all years between first and last)
        return jaarlijkseAfschrijving
    }

    /// Formatted date
    var aanschafdatumFormatted: String {
        DutchDateFormatter.formatStandard(aanschafdatum)
    }

    /// Display name with category
    var displayName: String {
        "\(naam) (\(categorie.displayName))"
    }

    // MARK: - Receipt/Document Properties

    var hasDocument: Bool {
        guard let path = documentPath, !path.isEmpty else { return false }
        return DocumentStorageService.shared.documentExists(at: path)
    }

    func documentURL(customBasePath: String? = nil) -> URL? {
        guard let path = documentPath else { return nil }
        return DocumentStorageService.shared.url(for: path, customBasePath: customBasePath)
    }

    @discardableResult
    func openDocument(customBasePath: String? = nil) -> Bool {
        guard let path = documentPath else { return false }
        return DocumentStorageService.shared.openPDF(at: path, customBasePath: customBasePath)
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        naam: String,
        omschrijving: String? = nil,
        aanschafdatum: Date = Date(),
        inGebruikDatum: Date? = nil,
        aanschafwaarde: Decimal,
        btwBedrag: Decimal = 0,
        restwaarde: Decimal? = nil,
        afschrijvingsjaren: Int = 5,
        categorie: AssetCategory = .overig,
        leverancier: String? = nil,
        factuurNummer: String? = nil,
        documentPath: String? = nil,
        zakelijkPercentage: Decimal = 100,
        notities: String? = nil
    ) {
        self.id = id
        self.naam = naam
        self.omschrijving = omschrijving
        self.aanschafdatum = aanschafdatum
        self.inGebruikDatum = inGebruikDatum ?? aanschafdatum
        self.aanschafwaarde = max(0, aanschafwaarde)
        self.btwBedrag = max(0, btwBedrag)
        // Default residual value is 10% if not specified
        self.restwaarde = restwaarde ?? (aanschafwaarde * Decimal(string: "0.10")!)
        self.afschrijvingsjaren = max(1, afschrijvingsjaren)
        self.categorieRaw = categorie.rawValue
        self.leverancier = leverancier
        self.factuurNummer = factuurNummer
        self.documentPath = documentPath
        self.zakelijkPercentage = min(100, max(0, zakelijkPercentage))
        self.isActief = true
        self.notities = notities
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods

    func updateTimestamp() {
        updatedAt = Date()
    }

    /// Mark asset as sold/disposed
    func dispose(date: Date = Date(), saleValue: Decimal? = nil) {
        verkoopDatum = date
        verkoopWaarde = saleValue
        isActief = false
        updateTimestamp()
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let assetCreated = NSNotification.Name("assetCreated")
}

// MARK: - Array Extensions
extension [Asset] {
    /// All active assets
    var active: [Asset] {
        filter { $0.isActief }
    }

    /// Total book value of all assets
    var totalBoekwaarde: Decimal {
        reduce(0) { $0 + $1.boekwaarde }
    }

    /// Total annual depreciation for all assets
    var totalJaarlijkseAfschrijving: Decimal {
        reduce(0) { $0 + $1.jaarlijkseAfschrijving }
    }

    /// Total depreciation for a specific year
    func totalAfschrijvingVoorJaar(_ year: Int) -> Decimal {
        reduce(0) { $0 + $1.afschrijvingVoorJaar(year) }
    }

    /// Assets by category
    var groupedByCategory: [AssetCategory: [Asset]] {
        Dictionary(grouping: self) { $0.categorie }
    }

    /// Fully depreciated assets
    var volledigAfgeschreven: [Asset] {
        filter { $0.isVolledigAfgeschreven }
    }

    /// Sort by purchase date (newest first)
    var sortedByDate: [Asset] {
        sorted { $0.aanschafdatum > $1.aanschafdatum }
    }

    /// Filter by year of purchase
    func filterByYear(_ year: Int) -> [Asset] {
        let calendar = Calendar.current
        return filter { calendar.component(.year, from: $0.aanschafdatum) == year }
    }
}
