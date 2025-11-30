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
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: datum)
    }

    /// Short date for invoice line items
    var datumShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: datum)
    }

    /// Display name for the entry
    var displayName: String {
        if let clientName = client?.bedrijfsnaam {
            return "\(clientName) - \(locatie)"
        }
        return "\(activiteit) - \(locatie)"
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
        client: Client? = nil
    ) {
        self.id = id
        self.datum = datum
        self.code = code
        self.activiteit = activiteit
        self.locatie = locatie
        self.uren = uren
        self.visiteKilometers = visiteKilometers
        self.retourafstandWoonWerk = retourafstandWoonWerk
        self.uurtarief = uurtarief
        self.kilometertarief = kilometertarief
        self.opmerkingen = opmerkingen
        self.isBillable = isBillable
        self.isInvoiced = isInvoiced
        self.factuurnummer = factuurnummer
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

    /// Mark this entry as invoiced
    func markAsInvoiced(withNumber number: String, invoice: Invoice) {
        isInvoiced = true
        factuurnummer = number
        self.invoice = invoice
        updateTimestamp()
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

    /// Total hours
    var totalHours: Decimal {
        reduce(0) { $0 + $1.uren }
    }

    /// Total billable hours
    var totalBillableHours: Decimal {
        billableOnly.reduce(0) { $0 + $1.uren }
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
