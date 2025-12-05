import Foundation
import SwiftData

@Model
final class Invoice {
    // MARK: - Properties
    var id: UUID
    var factuurnummer: String           // "2025-042"
    var factuurdatum: Date
    var vervaldatum: Date               // +14 days
    var statusRaw: String
    var pdfPath: String?                // Relative path to generated PDF
    var importedPdfPath: String?        // Relative path to original imported PDF
    var notities: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - BTW Properties
    var btwTariefRaw: String            // BTW tarief for this invoice
    var btwBedragOverride: Decimal?     // Manual BTW amount (for imported invoices)

    // MARK: - Manual Line Items (JSON encoded for flexibility)
    var manualLineItemsData: Data?      // Encoded ManualInvoiceLineItem array

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var client: Client?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.invoice)
    var timeEntries: [TimeEntry]? = []

    // MARK: - Computed Properties
    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .concept }
        set { statusRaw = newValue.rawValue }
    }

    var btwTarief: BTWTarief {
        get { BTWTarief(rawValue: btwTariefRaw) ?? .vrijgesteld }
        set { btwTariefRaw = newValue.rawValue }
    }

    /// Manual line items decoded from JSON
    var manualLineItems: [ManualInvoiceLineItem] {
        get {
            guard let data = manualLineItemsData else { return [] }
            return (try? JSONDecoder().decode([ManualInvoiceLineItem].self, from: data)) ?? []
        }
        set {
            manualLineItemsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Total hours on this invoice
    var totaalUren: Decimal {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.uren }
    }

    /// Total amount for hours
    var totaalUrenBedrag: Decimal {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.totaalbedragUren }
    }

    /// Total kilometers on this invoice
    var totaalKilometers: Int {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.totaalKilometers }
    }

    /// Total amount for kilometers
    var totaalKmBedrag: Decimal {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.totaalbedragKm }
    }

    /// Subtotal from time entries (hours + km)
    var subtotaalTimeEntries: Decimal {
        totaalUrenBedrag + totaalKmBedrag
    }

    /// Subtotal from manual line items
    var subtotaalManualItems: Decimal {
        manualLineItems.reduce(0) { $0 + $1.bedrag }
    }

    /// Grand total excl. BTW (hours + km + manual items)
    var totaalbedragExclBTW: Decimal {
        subtotaalTimeEntries + subtotaalManualItems
    }

    /// BTW amount
    var btwBedrag: Decimal {
        if let override = btwBedragOverride {
            return override
        }
        return totaalbedragExclBTW * btwTarief.percentage
    }

    /// Grand total incl. BTW
    var totaalbedrag: Decimal {
        totaalbedragExclBTW + btwBedrag
    }

    /// Formatted BTW amount
    var btwBedragFormatted: String {
        btwBedrag.asCurrency
    }

    /// Whether this invoice has BTW
    var hasBTW: Bool {
        btwTarief != .vrijgesteld && btwBedrag > 0
    }

    /// Number of line items
    var aantalRegels: Int {
        timeEntries?.count ?? 0
    }

    /// Formatted invoice date
    var factuurdatumFormatted: String {
        DutchDateFormatter.formatStandard(factuurdatum)
    }

    /// Formatted due date
    var vervaldatumFormatted: String {
        DutchDateFormatter.formatStandard(vervaldatum)
    }

    /// Days until due (or past due if negative)
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: vervaldatum)
        return calendar.dateComponents([.day], from: now, to: due).day ?? 0
    }

    /// Is this invoice overdue?
    var isOverdue: Bool {
        status == .verzonden && daysUntilDue < 0
    }

    /// Date range of entries on this invoice
    var dateRange: String {
        guard let entries = timeEntries, !entries.isEmpty else { return "" }
        let sorted = entries.sorted { $0.datum < $1.datum }

        if let first = sorted.first, let last = sorted.last {
            if Calendar.current.isDate(first.datum, inSameDayAs: last.datum) {
                return DutchDateFormatter.formatShort(first.datum)
            }
            return "\(DutchDateFormatter.formatShort(first.datum)) - \(DutchDateFormatter.formatShort(last.datum))"
        }
        return ""
    }

    // MARK: - PDF Properties

    /// Whether any PDF is available (generated or imported)
    var hasPdf: Bool {
        hasGeneratedPdf || hasImportedPdf
    }

    /// Whether a generated PDF exists
    var hasGeneratedPdf: Bool {
        guard let path = pdfPath, !path.isEmpty else { return false }
        return DocumentStorageService.shared.documentExists(at: path)
    }

    /// Whether an imported PDF exists
    var hasImportedPdf: Bool {
        guard let path = importedPdfPath, !path.isEmpty else { return false }
        return DocumentStorageService.shared.documentExists(at: path)
    }

    /// Get the full URL to the generated PDF
    func generatedPdfURL(customBasePath: String? = nil) -> URL? {
        guard let path = pdfPath else { return nil }
        return DocumentStorageService.shared.url(for: path, customBasePath: customBasePath)
    }

    /// Get the full URL to the imported PDF
    func importedPdfURL(customBasePath: String? = nil) -> URL? {
        guard let path = importedPdfPath else { return nil }
        return DocumentStorageService.shared.url(for: path, customBasePath: customBasePath)
    }

    /// Open the generated PDF in the default viewer
    @discardableResult
    func openGeneratedPdf(customBasePath: String? = nil) -> Bool {
        guard let path = pdfPath else { return false }
        return DocumentStorageService.shared.openPDF(at: path, customBasePath: customBasePath)
    }

    /// Open the imported PDF in the default viewer
    @discardableResult
    func openImportedPdf(customBasePath: String? = nil) -> Bool {
        guard let path = importedPdfPath else { return false }
        return DocumentStorageService.shared.openPDF(at: path, customBasePath: customBasePath)
    }

    // MARK: - PDF Deletion

    /// Delete the generated PDF file and clear the path
    func deleteGeneratedPdf(customBasePath: String? = nil) throws {
        guard let path = pdfPath else { return }
        try DocumentStorageService.shared.deletePDF(at: path, customBasePath: customBasePath)
        pdfPath = nil
        updateTimestamp()
    }

    /// Delete the imported PDF file and clear the path
    func deleteImportedPdf(customBasePath: String? = nil) throws {
        guard let path = importedPdfPath else { return }
        try DocumentStorageService.shared.deletePDF(at: path, customBasePath: customBasePath)
        importedPdfPath = nil
        updateTimestamp()
    }

    /// Delete all associated PDF files
    func deleteAllPdfs(customBasePath: String? = nil) {
        try? deleteGeneratedPdf(customBasePath: customBasePath)
        try? deleteImportedPdf(customBasePath: customBasePath)
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        factuurnummer: String,
        factuurdatum: Date = Date(),
        betalingstermijn: Int = 14,
        status: InvoiceStatus = .concept,
        client: Client? = nil,
        notities: String? = nil,
        btwTarief: BTWTarief = .vrijgesteld
    ) {
        self.id = id
        self.factuurnummer = factuurnummer
        self.factuurdatum = factuurdatum
        self.vervaldatum = Calendar.current.date(byAdding: .day, value: betalingstermijn, to: factuurdatum) ?? factuurdatum
        self.statusRaw = status.rawValue
        self.btwTariefRaw = btwTarief.rawValue
        self.client = client
        self.notities = notities
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }

    /// Add time entries to this invoice
    func addTimeEntries(_ entries: [TimeEntry]) {
        for entry in entries {
            entry.markAsInvoiced(withNumber: factuurnummer, invoice: self)
        }
        if timeEntries == nil {
            timeEntries = entries
        } else {
            timeEntries?.append(contentsOf: entries)
        }
        updateTimestamp()
    }

    /// Update invoice status
    func updateStatus(_ newStatus: InvoiceStatus) {
        status = newStatus
        updateTimestamp()
    }

    /// Mark invoice as paid
    func markAsPaid() {
        updateStatus(.betaald)
    }

    /// Mark invoice as sent
    func markAsSent() {
        updateStatus(.verzonden)
    }

    /// Generate invoice line items for display
    var lineItems: [InvoiceLineItem] {
        var items: [InvoiceLineItem] = []

        // Add time entry based items
        if let entries = timeEntries {
            for entry in entries.sorted(by: { $0.datum < $1.datum }) {
                // Hours line
                items.append(InvoiceLineItem(
                    datum: entry.datumShort,
                    omschrijving: entry.activiteit,
                    eenheid: "uur",
                    aantal: entry.uren,
                    tarief: entry.uurtarief,
                    bedrag: entry.totaalbedragUren,
                    btwTarief: btwTarief
                ))

                // Kilometers line (if any)
                if entry.totaalKilometers > 0 {
                    items.append(InvoiceLineItem(
                        datum: entry.datumShort,
                        omschrijving: "Reiskosten \(entry.locatie)",
                        eenheid: "km",
                        aantal: Decimal(entry.totaalKilometers),
                        tarief: entry.kilometertarief,
                        bedrag: entry.totaalbedragKm,
                        btwTarief: btwTarief
                    ))
                }
            }
        }

        // Add manual line items
        for manualItem in manualLineItems {
            items.append(manualItem.toInvoiceLineItem())
        }

        return items
    }

    /// Add a manual line item
    func addManualLineItem(_ item: ManualInvoiceLineItem) {
        var items = manualLineItems
        items.append(item)
        manualLineItems = items
        updateTimestamp()
    }

    /// Remove a manual line item
    func removeManualLineItem(id: UUID) {
        var items = manualLineItems
        items.removeAll { $0.id == id }
        manualLineItems = items
        updateTimestamp()
    }
}

// MARK: - Invoice Line Item (for display in PDF/views)
struct InvoiceLineItem: Identifiable {
    let id = UUID()
    let datum: String
    let omschrijving: String
    let eenheid: String
    let aantal: Decimal
    let tarief: Decimal
    let bedrag: Decimal
    let btwTarief: BTWTarief

    init(datum: String, omschrijving: String, eenheid: String, aantal: Decimal, tarief: Decimal, bedrag: Decimal, btwTarief: BTWTarief = .vrijgesteld) {
        self.datum = datum
        self.omschrijving = omschrijving
        self.eenheid = eenheid
        self.aantal = aantal
        self.tarief = tarief
        self.bedrag = bedrag
        self.btwTarief = btwTarief
    }

    /// BTW amount for this line item
    var btwBedrag: Decimal {
        bedrag * btwTarief.percentage
    }

    /// Total including BTW
    var bedragInclBTW: Decimal {
        bedrag + btwBedrag
    }
}

// MARK: - Manual Invoice Line Item (stored as JSON)
/// For adding custom line items not linked to TimeEntry
struct ManualInvoiceLineItem: Identifiable, Codable {
    var id: UUID
    var datum: Date
    var omschrijving: String
    var eenheid: String              // "uur", "stuk", "km", etc.
    var aantal: Decimal
    var tarief: Decimal
    var btwTariefRaw: String

    var bedrag: Decimal {
        aantal * tarief
    }

    var btwTarief: BTWTarief {
        get { BTWTarief(rawValue: btwTariefRaw) ?? .vrijgesteld }
        set { btwTariefRaw = newValue.rawValue }
    }

    var btwBedrag: Decimal {
        bedrag * btwTarief.percentage
    }

    var datumFormatted: String {
        DutchDateFormatter.formatShort(datum)
    }

    init(
        id: UUID = UUID(),
        datum: Date = Date(),
        omschrijving: String,
        eenheid: String = "stuk",
        aantal: Decimal = 1,
        tarief: Decimal,
        btwTarief: BTWTarief = .standaard
    ) {
        self.id = id
        self.datum = datum
        self.omschrijving = omschrijving
        self.eenheid = eenheid
        self.aantal = aantal
        self.tarief = tarief
        self.btwTariefRaw = btwTarief.rawValue
    }

    /// Convert to display line item
    func toInvoiceLineItem() -> InvoiceLineItem {
        InvoiceLineItem(
            datum: datumFormatted,
            omschrijving: omschrijving,
            eenheid: eenheid,
            aantal: aantal,
            tarief: tarief,
            bedrag: bedrag,
            btwTarief: btwTarief
        )
    }
}

// MARK: - Invoice Number Generator
extension Invoice {
    /// Generate next invoice number for a year
    static func nextInvoiceNumber(year: Int, lastNumber: Int) -> String {
        let nextNum = lastNumber + 1
        return String(format: "%d-%03d", year, nextNum)
    }

    /// Extract year and number from invoice number
    static func parseInvoiceNumber(_ number: String) -> (year: Int, number: Int)? {
        let parts = number.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let num = Int(parts[1]) else {
            return nil
        }
        return (year, num)
    }
}

// MARK: - Sample Data
extension Invoice {
    static func sampleInvoice(for client: Client, entries: [TimeEntry]) -> Invoice {
        let invoice = Invoice(
            factuurnummer: "2025-001",
            status: .concept,
            client: client
        )
        invoice.addTimeEntries(entries)
        return invoice
    }
}

// MARK: - Filtering
extension [Invoice] {
    /// Sort by date descending
    var sortedByDate: [Invoice] {
        sorted { $0.factuurdatum > $1.factuurdatum }
    }

    /// Filter by status
    func filterByStatus(_ status: InvoiceStatus) -> [Invoice] {
        filter { $0.status == status }
    }

    /// Filter by year
    func filterByYear(_ year: Int) -> [Invoice] {
        let calendar = Calendar.current
        return filter { calendar.component(.year, from: $0.factuurdatum) == year }
    }

    /// Total amount
    var totalAmount: Decimal {
        reduce(0) { $0 + $1.totaalbedrag }
    }

    /// Total paid amount
    var totalPaid: Decimal {
        filterByStatus(.betaald).reduce(0) { $0 + $1.totaalbedrag }
    }

    /// Total outstanding amount
    var totalOutstanding: Decimal {
        filter { $0.status == .verzonden || $0.status == .herinnering }
            .reduce(0) { $0 + $1.totaalbedrag }
    }

    /// Count by status
    func countByStatus(_ status: InvoiceStatus) -> Int {
        filterByStatus(status).count
    }
}
