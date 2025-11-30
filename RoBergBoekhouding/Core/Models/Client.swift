import Foundation
import SwiftData

@Model
final class Client {
    // MARK: - Properties
    var id: UUID
    var bedrijfsnaam: String
    var contactpersoon: String?
    var adres: String
    var postcodeplaats: String
    var telefoon: String?
    var email: String?
    var standaardUurtarief: Decimal
    var standaardKmTarief: Decimal
    var afstandRetour: Int  // Total return distance in km (e.g., 108 for Vlagtwedde)
    var clientTypeRaw: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.client)
    var timeEntries: [TimeEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \Invoice.client)
    var invoices: [Invoice]? = []

    // MARK: - Computed Properties
    var clientType: ClientType {
        get { ClientType(rawValue: clientTypeRaw) ?? .dagpraktijk }
        set { clientTypeRaw = newValue.rawValue }
    }

    var displayName: String {
        if let contactpersoon, !contactpersoon.isEmpty {
            return "\(bedrijfsnaam) (\(contactpersoon))"
        }
        return bedrijfsnaam
    }

    var shortAddress: String {
        "\(postcodeplaats)"
    }

    var fullAddress: String {
        "\(adres)\n\(postcodeplaats)"
    }

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        bedrijfsnaam: String,
        contactpersoon: String? = nil,
        adres: String = "",
        postcodeplaats: String = "",
        telefoon: String? = nil,
        email: String? = nil,
        standaardUurtarief: Decimal = 70.00,
        standaardKmTarief: Decimal = 0.23,
        afstandRetour: Int = 0,
        clientType: ClientType = .dagpraktijk,
        isActive: Bool = true
    ) {
        self.id = id
        self.bedrijfsnaam = bedrijfsnaam
        self.contactpersoon = contactpersoon
        self.adres = adres
        self.postcodeplaats = postcodeplaats
        self.telefoon = telefoon
        self.email = email
        self.standaardUurtarief = standaardUurtarief
        self.standaardKmTarief = standaardKmTarief
        self.afstandRetour = afstandRetour
        self.clientTypeRaw = clientType.rawValue
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }

    /// Calculate total revenue from this client
    var totalRevenue: Decimal {
        guard let entries = timeEntries else { return 0 }
        return entries.filter { $0.isBillable }.reduce(0) { $0 + $1.totaalbedrag }
    }

    /// Calculate total hours worked for this client
    var totalHours: Decimal {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.uren }
    }

    /// Calculate total kilometers driven for this client
    var totalKilometers: Int {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { $0 + $1.retourafstandWoonWerk }
    }

    /// Get unbilled time entries
    var unbilledEntries: [TimeEntry] {
        guard let entries = timeEntries else { return [] }
        return entries.filter { $0.isBillable && !$0.isInvoiced }
    }

    /// Get total unbilled amount
    var unbilledAmount: Decimal {
        unbilledEntries.reduce(0) { $0 + $1.totaalbedrag }
    }
}

// MARK: - Sample Data
extension Client {
    static var sampleClients: [Client] {
        [
            Client(
                bedrijfsnaam: "Huisartspraktijk Raupp",
                contactpersoon: "G.E.M. Raupp",
                adres: "Oostersingel 28",
                postcodeplaats: "9541 BK Vlagtwedde",
                standaardUurtarief: 70.00,
                standaardKmTarief: 0.23,
                afstandRetour: 108,
                clientType: .dagpraktijk
            ),
            Client(
                bedrijfsnaam: "Huisartsenpraktijk 't Ouddiep",
                contactpersoon: "M. Janssens",
                adres: "Kamperfoelielaan 5",
                postcodeplaats: "9363 EV Marum",
                standaardUurtarief: 70.00,
                standaardKmTarief: 0.23,
                afstandRetour: 44,
                clientType: .dagpraktijk
            ),
            Client(
                bedrijfsnaam: "Doktersdienst Groningen",
                adres: "van Swietenlaan 2b",
                postcodeplaats: "9728 NZ Groningen",
                standaardUurtarief: 124.00,
                standaardKmTarief: 0.23,
                afstandRetour: 10,
                clientType: .anwDienst
            ),
            Client(
                bedrijfsnaam: "Dokter Drenthe",
                adres: "Stationsstraat 44",
                postcodeplaats: "9401 KX Assen",
                standaardUurtarief: 124.00,
                standaardKmTarief: 0.23,
                afstandRetour: 40,
                clientType: .anwDienst
            ),
            Client(
                bedrijfsnaam: "Huisartsenpraktijk Winsum",
                contactpersoon: "S. Dijkema",
                adres: "Meeden 3D",
                postcodeplaats: "9951 HZ Winsum",
                standaardUurtarief: 70.00,
                standaardKmTarief: 0.21,
                afstandRetour: 44,
                clientType: .dagpraktijk
            )
        ]
    }
}
