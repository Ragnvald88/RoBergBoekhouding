import Foundation
import SwiftData

@Model
final class TimeEntry {
    // MARK: - Properties
    var id: UUID
    var datum: Date
    var code: String                    // Activity code: "WDAGPRAKTIJK_70", "Admin", etc.
    var activiteit: String              // "Waarneming Dagpraktijk", "Administratie"
    var locatie: String                 // "Vlagtwedde", "Winsum", "Thuis"
    var uren: Decimal                   // Hours worked: 9.00
    var visiteKilometers: Decimal?      // Optional extra visit km
    var retourafstandWoonWerk: Int      // Return distance: 108, 44, etc.
    var uurtarief: Decimal              // Hourly rate: 70.00, 124.00
    var kilometertarief: Decimal        // km rate: 0.21, 0.23
    var opmerkingen: String?            // Notes
    var isBillable: Bool                // False for Admin/NSCHL
    var isInvoiced: Bool                // True if included in an invoice
    var factuurnummer: String?          // Invoice number if invoiced
    var isStandby: Bool                 // True for achterwacht/standby hours (don't count for zelfstandigenaftrek)
    var dienstCode: String?             // ANW dienst code: "AW-WK-H", "SAV*", etc.
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var client: Client?

    @Relationship(deleteRule: .nullify)
    var invoice: Invoice?

    // MARK: - Computed Properties

    /// Total amount for hours: uren * uurtarief
    var totaalbedragUren: Decimal {
        uren * uurtarief
    }

    /// Total amount for kilometers: retourafstand * kilometertarief
    var totaalbedragKm: Decimal {
        Decimal(retourafstandWoonWerk) * kilometertarief + (visiteKilometers ?? 0) * kilometertarief
    }

    /// Total amount (hours + km), zero if not billable
    var totaalbedrag: Decimal {
        isBillable ? (totaalbedragUren + totaalbedragKm) : 0
    }

    /// Total kilometers including visit km
    var totaalKilometers: Int {
        retourafstandWoonWerk + Int(truncating: (visiteKilometers ?? 0) as NSDecimalNumber)
    }

    /// Formatted date string
    var datumFormatted: String {
        DutchDateFormatter.formatStandard(datum)
    }

    /// Short date for invoice line items
    var datumShort: String {
        DutchDateFormatter.formatShort(datum)
    }

    /// Display name for the entry
    var displayName: String {
        if let clientName = client?.bedrijfsnaam {
            return "\(clientName) - \(locatie)"
        }
        return "\(activiteit) - \(locatie)"
    }

    /// Hours that count for zelfstandigenaftrek (excludes standby hours)
    /// Note: ALL hours count (billable + non-billable like admin), except standby
    var workingHours: Decimal {
        isStandby ? 0 : uren
    }

    /// Whether this is an ANW dienst entry
    var isANWDienst: Bool {
        dienstCode != nil
    }

    /// Formatted dienst info for display
    var dienstInfo: String? {
        guard let code = dienstCode else { return nil }
        if isStandby {
            return "\(code) (achterwacht)"
        }
        return code
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        datum: Date = Date(),
        code: String = "WDAGPRAKTIJK_70",
        activiteit: String = "Waarneming Dagpraktijk",
        locatie: String = "",
        uren: Decimal = 9.00,
        visiteKilometers: Decimal? = nil,
        retourafstandWoonWerk: Int = 0,
        uurtarief: Decimal = 70.00,
        kilometertarief: Decimal = 0.23,
        opmerkingen: String? = nil,
        isBillable: Bool = true,
        isInvoiced: Bool = false,
        factuurnummer: String? = nil,
        isStandby: Bool = false,
        dienstCode: String? = nil,
        client: Client? = nil
    ) {
        self.id = id
        self.datum = datum
        self.code = code
        self.activiteit = activiteit
        self.locatie = locatie
        // Validate: hours cannot be negative
        self.uren = max(0, uren)
        // Validate: kilometers cannot be negative
        self.visiteKilometers = visiteKilometers.map { max(0, $0) }
        self.retourafstandWoonWerk = max(0, retourafstandWoonWerk)
        // Validate: rates cannot be negative
        self.uurtarief = max(0, uurtarief)
        self.kilometertarief = max(0, kilometertarief)
        self.opmerkingen = opmerkingen
        self.isBillable = isBillable
        self.isInvoiced = isInvoiced
        self.factuurnummer = factuurnummer
        self.isStandby = isStandby
        self.dienstCode = dienstCode
        self.client = client
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }

    /// Apply client defaults to this entry
    func applyClientDefaults() {
        guard let client = client else { return }
        uurtarief = client.standaardUurtarief
        kilometertarief = client.standaardKmTarief
        retourafstandWoonWerk = client.afstandRetour
        locatie = extractCity(from: client.postcodeplaats)
    }

    /// Extract city from postcodeplaats (e.g., "9541 BK Vlagtwedde" -> "Vlagtwedde")
    private func extractCity(from postcodeplaats: String) -> String {
        let components = postcodeplaats.components(separatedBy: " ")
        // Format is typically "9541 BK Vlagtwedde" - city is last component(s)
        if components.count >= 3 {
            return components.dropFirst(2).joined(separator: " ")
        }
        return postcodeplaats
    }

    /// Mark this entry as invoiced (internal - sets flags only)
    /// Note: Use Invoice.addTimeEntries() to link entries to invoices.
    /// This method is called internally by addTimeEntries() and should not
    /// be called directly to avoid relationship management issues.
    internal func markAsInvoiced(withNumber number: String) {
        isInvoiced = true
        factuurnummer = number
        updateTimestamp()
    }

    /// Unmark this entry as invoiced (for when invoice is deleted)
    func unmarkAsInvoiced() {
        isInvoiced = false
        factuurnummer = nil
        invoice = nil
        updateTimestamp()
    }

    /// Check if this entry's invoiced state is consistent
    /// Returns true if all invoice-related fields are in a valid state
    var hasConsistentInvoiceState: Bool {
        if isInvoiced {
            // If marked as invoiced, should have both factuurnummer and invoice reference
            return factuurnummer != nil && invoice != nil
        } else {
            // If not invoiced, should have neither
            return factuurnummer == nil && invoice == nil
        }
    }
}

// MARK: - Sample Data
extension TimeEntry {
    static func sampleEntry(for client: Client) -> TimeEntry {
        TimeEntry(
            datum: Date(),
            code: "WDAGPRAKTIJK_70",
            activiteit: "Waarneming Dagpraktijk",
            locatie: "Vlagtwedde",
            uren: 9.00,
            retourafstandWoonWerk: client.afstandRetour,
            uurtarief: client.standaardUurtarief,
            kilometertarief: client.standaardKmTarief,
            client: client
        )
    }

    static var sampleEntries: [TimeEntry] {
        let calendar = Calendar.current
        return (0..<10).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let isAdmin = dayOffset % 7 == 6 // Every Sunday is admin

            return TimeEntry(
                datum: date,
                code: isAdmin ? "Admin" : "WDAGPRAKTIJK_70",
                activiteit: isAdmin ? "Administratie" : "Waarneming Dagpraktijk",
                locatie: isAdmin ? "Thuis" : (dayOffset % 2 == 0 ? "Vlagtwedde" : "Winsum"),
                uren: isAdmin ? 3.00 : 9.00,
                retourafstandWoonWerk: isAdmin ? 0 : (dayOffset % 2 == 0 ? 108 : 44),
                uurtarief: isAdmin ? 0.00 : 70.00,
                kilometertarief: isAdmin ? 0.00 : 0.23,
                isBillable: !isAdmin
            )
        }
    }
}

// MARK: - Sorting and Filtering
extension [TimeEntry] {
    /// Sort by date descending (newest first)
    var sortedByDate: [TimeEntry] {
        sorted { $0.datum > $1.datum }
    }

    /// Filter to billable entries only
    var billableOnly: [TimeEntry] {
        filter { $0.isBillable }
    }

    /// Filter to uninvoiced entries only
    var uninvoiced: [TimeEntry] {
        filter { !$0.isInvoiced }
    }

    /// Total hours (all hours including standby)
    var totalHours: Decimal {
        reduce(0) { $0 + $1.uren }
    }

    /// Total billable hours
    var totalBillableHours: Decimal {
        billableOnly.reduce(0) { $0 + $1.uren }
    }

    /// Total working hours (for zelfstandigenaftrek - excludes standby)
    var totalWorkingHours: Decimal {
        reduce(0) { $0 + $1.workingHours }
    }

    /// Total standby hours (achterwacht)
    var totalStandbyHours: Decimal {
        filter { $0.isStandby }.reduce(0) { $0 + $1.uren }
    }

    /// Filter to standby entries only
    var standbyOnly: [TimeEntry] {
        filter { $0.isStandby }
    }

    /// Filter to non-standby entries only
    var excludingStandby: [TimeEntry] {
        filter { !$0.isStandby }
    }

    /// Total kilometers
    var totalKilometers: Int {
        reduce(0) { $0 + $1.totaalKilometers }
    }

    /// Total revenue
    var totalRevenue: Decimal {
        billableOnly.reduce(0) { $0 + $1.totaalbedrag }
    }

    /// Filter by year
    func filterByYear(_ year: Int) -> [TimeEntry] {
        let calendar = Calendar.current
        return filter { calendar.component(.year, from: $0.datum) == year }
    }

    /// Filter by month
    func filterByMonth(_ month: Int, year: Int) -> [TimeEntry] {
        let calendar = Calendar.current
        return filter {
            calendar.component(.year, from: $0.datum) == year &&
            calendar.component(.month, from: $0.datum) == month
        }
    }

    /// Group by client ID
    var groupedByClientID: [UUID?: [TimeEntry]] {
        Dictionary(grouping: self) { $0.client?.id }
    }

    /// Group by client - returns array of tuples for proper iteration
    var groupedByClient: [(client: Client?, entries: [TimeEntry])] {
        let byID = groupedByClientID
        var result: [(client: Client?, entries: [TimeEntry])] = []

        // Get unique clients
        var seenClients: Set<UUID> = []
        for entry in self {
            if let client = entry.client {
                if !seenClients.contains(client.id) {
                    seenClients.insert(client.id)
                    if let entries = byID[client.id] {
                        result.append((client: client, entries: entries))
                    }
                }
            }
        }

        // Add entries without client
        if let nilEntries = byID[nil], !nilEntries.isEmpty {
            result.append((client: nil, entries: nilEntries))
        }

        return result
    }
}
