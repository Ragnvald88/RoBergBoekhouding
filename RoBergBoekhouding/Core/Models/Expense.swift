import Foundation
import SwiftData

@Model
final class Expense {
    // MARK: - Properties
    var id: UUID
    var datum: Date
    var omschrijving: String
    var bedrag: Decimal
    var categorieRaw: String
    var leverancier: String?
    var documentPath: String?           // Path to receipt PDF
    var zakelijkPercentage: Decimal     // 100% or partial (e.g., 50% for mixed use)
    var isRecurring: Bool               // Monthly recurring expense
    var notities: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties
    var categorie: ExpenseCategory {
        get { ExpenseCategory(rawValue: categorieRaw) ?? .overig }
        set { categorieRaw = newValue.rawValue }
    }

    /// Business portion of the expense
    var zakelijkBedrag: Decimal {
        bedrag * (zakelijkPercentage / 100)
    }

    /// Private portion of the expense
    var priveBedrag: Decimal {
        bedrag - zakelijkBedrag
    }

    /// Formatted date
    var datumFormatted: String {
        DutchDateFormatter.formatStandard(datum)
    }

    /// Short date for lists
    var datumShort: String {
        DutchDateFormatter.formatShort(datum)
    }

    /// Month-year string for grouping
    var maandJaar: String {
        DutchDateFormatter.formatMonthYear(datum)
    }

    /// Display name for the expense
    var displayName: String {
        if let leverancier, !leverancier.isEmpty {
            return "\(leverancier): \(omschrijving)"
        }
        return omschrijving
    }

    // MARK: - Receipt Properties

    /// Whether a receipt document is attached
    var hasReceipt: Bool {
        guard let path = documentPath, !path.isEmpty else { return false }
        return DocumentStorageService.shared.documentExists(at: path)
    }

    /// Get the full URL to the receipt document
    func receiptURL(customBasePath: String? = nil) -> URL? {
        guard let path = documentPath else { return nil }
        return DocumentStorageService.shared.url(for: path, customBasePath: customBasePath)
    }

    /// Open the receipt in the default viewer
    @discardableResult
    func openReceipt(customBasePath: String? = nil) -> Bool {
        guard let path = documentPath else { return false }
        return DocumentStorageService.shared.openPDF(at: path, customBasePath: customBasePath)
    }

    /// Attach a receipt document from a file URL
    func attachReceipt(from url: URL, customBasePath: String? = nil) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw DocumentStorageService.StorageError.cannotWriteFile
        }

        let year = Calendar.current.component(.year, from: datum)
        let path = try DocumentStorageService.shared.storePDF(
            data,
            type: .expense,
            identifier: id.uuidString,
            year: year,
            customBasePath: customBasePath
        )

        documentPath = path
        updateTimestamp()
    }

    /// Remove the attached receipt
    func removeReceipt(customBasePath: String? = nil) throws {
        guard let path = documentPath else { return }
        try DocumentStorageService.shared.deletePDF(at: path, customBasePath: customBasePath)
        documentPath = nil
        updateTimestamp()
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        datum: Date = Date(),
        omschrijving: String,
        bedrag: Decimal,
        categorie: ExpenseCategory = .overig,
        leverancier: String? = nil,
        documentPath: String? = nil,
        zakelijkPercentage: Decimal = 100,
        isRecurring: Bool = false,
        notities: String? = nil
    ) {
        self.id = id
        self.datum = datum
        self.omschrijving = omschrijving
        // Validate: bedrag cannot be negative
        self.bedrag = max(0, bedrag)
        self.categorieRaw = categorie.rawValue
        self.leverancier = leverancier
        self.documentPath = documentPath
        // Validate: percentage must be between 0 and 100
        self.zakelijkPercentage = min(100, max(0, zakelijkPercentage))
        self.isRecurring = isRecurring
        self.notities = notities
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }
}

// MARK: - Sample Data
extension Expense {
    static var sampleExpenses: [Expense] {
        [
            Expense(
                datum: Date(),
                omschrijving: "Administratie en jaarstukken",
                bedrag: 89.00,
                categorie: .accountancy,
                leverancier: "VvAA",
                isRecurring: true
            ),
            Expense(
                datum: Date(),
                omschrijving: "KPN Mobiel",
                bedrag: 72.50,
                categorie: .telefoonInternet,
                leverancier: "KPN",
                zakelijkPercentage: 80,
                isRecurring: true
            ),
            Expense(
                datum: Date(),
                omschrijving: "AOV Zorgservice",
                bedrag: 250.00,
                categorie: .verzekeringen,
                leverancier: "Allianz",
                isRecurring: true
            ),
            Expense(
                datum: Date(),
                omschrijving: "NHG Contributie",
                bedrag: 393.00,
                categorie: .lidmaatschappen,
                leverancier: "NHG"
            ),
            Expense(
                datum: Date(),
                omschrijving: "Pensioenpremie Q1",
                bedrag: 220.00,
                categorie: .pensioenpremie,
                leverancier: "SPH"
            ),
            Expense(
                datum: Date(),
                omschrijving: "Glucosemeter",
                bedrag: 150.00,
                categorie: .kleineAankopen,
                leverancier: "Praxisdienst"
            )
        ]
    }
}

// MARK: - Filtering and Grouping
extension [Expense] {
    /// Sort by date descending
    var sortedByDate: [Expense] {
        sorted { $0.datum > $1.datum }
    }

    /// Total amount
    var totalAmount: Decimal {
        reduce(0) { $0 + $1.bedrag }
    }

    /// Total business amount
    var totalBusinessAmount: Decimal {
        reduce(0) { $0 + $1.zakelijkBedrag }
    }

    /// Filter by category
    func filterByCategory(_ category: ExpenseCategory) -> [Expense] {
        filter { $0.categorie == category }
    }

    /// Filter by year
    func filterByYear(_ year: Int) -> [Expense] {
        let calendar = Calendar.current
        return filter { calendar.component(.year, from: $0.datum) == year }
    }

    /// Filter by month
    func filterByMonth(_ month: Int, year: Int) -> [Expense] {
        let calendar = Calendar.current
        return filter {
            calendar.component(.year, from: $0.datum) == year &&
            calendar.component(.month, from: $0.datum) == month
        }
    }

    /// Group by category
    var groupedByCategory: [ExpenseCategory: [Expense]] {
        Dictionary(grouping: self) { $0.categorie }
    }

    /// Group by month
    var groupedByMonth: [String: [Expense]] {
        Dictionary(grouping: self) { $0.maandJaar }
    }

    /// Summary by category
    var summaryByCategory: [(category: ExpenseCategory, total: Decimal)] {
        ExpenseCategory.allCases.compactMap { category in
            let total = filterByCategory(category).totalBusinessAmount
            guard total > 0 else { return nil }
            return (category, total)
        }.sorted { $0.total > $1.total }
    }

    /// Recurring expenses only
    var recurring: [Expense] {
        filter { $0.isRecurring }
    }

    /// Monthly recurring total
    var monthlyRecurringTotal: Decimal {
        recurring.totalBusinessAmount
    }
}
