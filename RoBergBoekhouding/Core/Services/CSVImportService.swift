import Foundation
import SwiftData

/// Service for importing CSV data from existing bookkeeping files
actor CSVImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Encoding Detection

    /// Read file content with automatic encoding detection
    /// Tries UTF-8 first, then common Dutch encodings
    private func readFileContent(from url: URL) throws -> String {
        // Try UTF-8 first (most common)
        if let utf8Content = try? String(contentsOf: url, encoding: .utf8) {
            // Remove BOM if present
            var content = utf8Content
            if content.hasPrefix("\u{FEFF}") {
                content = String(content.dropFirst())
            }
            return content
        }

        // Try Windows-1252 (common in Dutch Excel exports)
        if let windowsContent = try? String(contentsOf: url, encoding: .windowsCP1252) {
            return windowsContent
        }

        // Try ISO Latin 1
        if let isoContent = try? String(contentsOf: url, encoding: .isoLatin1) {
            return isoContent
        }

        // Try Mac Roman (legacy Mac files)
        if let macContent = try? String(contentsOf: url, encoding: .macOSRoman) {
            return macContent
        }

        throw ImportError.invalidFormat("Kan bestandscodering niet lezen. Probeer het bestand te openen in Excel en op te slaan als UTF-8 CSV.")
    }

    // MARK: - Import Clients from klanten.csv

    /// Import clients from klanten.csv
    /// Format: ID;Bedrijfsnaam;Naam;Adres;Postcode_Plaats
    func importClients(from url: URL) async throws -> ImportResult {
        let content = try readFileContent(from: url)
        let lines = content.components(separatedBy: .newlines)

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        // Skip header line
        for (index, line) in lines.enumerated() {
            // Skip empty lines and header
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard index > 0, !trimmedLine.isEmpty else { continue }

            do {
                if try await importClientLine(trimmedLine) {
                    imported += 1
                } else {
                    skipped += 1
                }
            } catch {
                errors.append("Regel \(index + 1): \(error.localizedDescription)")
            }
        }

        try modelContext.save()

        return ImportResult(
            imported: imported,
            skipped: skipped,
            errors: errors,
            type: .clients
        )
    }

    private func importClientLine(_ line: String) async throws -> Bool {
        let components = line.components(separatedBy: ";")
        guard components.count >= 5 else {
            throw ImportError.invalidFormat("Verwacht 5 kolommen, gevonden: \(components.count)")
        }

        let bedrijfsnaam = components[1].trimmingCharacters(in: .whitespaces)

        // Skip empty client names
        guard !bedrijfsnaam.isEmpty else {
            return false
        }

        // Check for existing client
        let descriptor = FetchDescriptor<Client>(
            predicate: #Predicate { $0.bedrijfsnaam == bedrijfsnaam }
        )

        let existing = try modelContext.fetch(descriptor)
        if !existing.isEmpty {
            return false // Skip duplicate
        }

        // Parse fields
        let contactpersoon = components[2].trimmingCharacters(in: .whitespaces)
        let adres = components[3].trimmingCharacters(in: .whitespaces)
        let postcodeplaats = components[4].trimmingCharacters(in: .whitespaces)

        // Determine client type based on name
        let clientType: ClientType
        if bedrijfsnaam.lowercased().contains("doktersdienst") ||
           bedrijfsnaam.lowercased().contains("dokter drenthe") {
            clientType = .anwDienst
        } else if bedrijfsnaam.lowercased().contains("roberg") {
            clientType = .administratie
        } else {
            clientType = .dagpraktijk
        }

        // Estimate distance from location (this can be refined later)
        let afstandRetour = estimateDistance(from: postcodeplaats)

        let client = Client(
            bedrijfsnaam: bedrijfsnaam,
            contactpersoon: contactpersoon.isEmpty ? nil : contactpersoon,
            adres: adres,
            postcodeplaats: postcodeplaats,
            standaardUurtarief: clientType.defaultHourlyRate,
            standaardKmTarief: 0.23,
            afstandRetour: afstandRetour,
            clientType: clientType,
            isActive: true
        )

        modelContext.insert(client)
        return true
    }

    // MARK: - Import Time Entries from URENREGISTERexport.csv

    /// Import time entries from URENREGISTERexport.csv
    /// Format: Datum;CODE;Klant;Activiteit;Locatie;Uren;Visite_kilometers;Retourafstand woon/werk km;Uurtarief;Kilometertarief;Totaalbedrag Uren;Totaalbedrag km;Totaalbedrag;Factuurnummer;Opmerkingen
    /// Columns: 0     1     2      3          4       5     6                  7                         8          9               10                 11              12            13              14
    func importTimeEntries(from url: URL, createInvoices: Bool = true) async throws -> ImportResult {
        let content = try readFileContent(from: url)
        let lines = content.components(separatedBy: .newlines)

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        // Track invoice numbers to create Invoice objects later
        var invoiceEntries: [String: [TimeEntry]] = [:]

        // Skip header line
        for (index, line) in lines.enumerated() {
            // Skip empty lines and header
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard index > 0, !trimmedLine.isEmpty else { continue }

            do {
                let result = try await importTimeEntryLine(trimmedLine)
                switch result {
                case .imported(let entry, let invoiceNumber):
                    imported += 1
                    // Track for invoice creation
                    if let invoiceNum = invoiceNumber, !invoiceNum.isEmpty {
                        if invoiceEntries[invoiceNum] == nil {
                            invoiceEntries[invoiceNum] = []
                        }
                        invoiceEntries[invoiceNum]?.append(entry)
                    }
                case .skipped:
                    skipped += 1
                case .error(let message):
                    errors.append("Regel \(index + 1): \(message)")
                }
            } catch {
                errors.append("Regel \(index + 1): \(error.localizedDescription)")
            }
        }

        // Create Invoice objects for entries that have invoice numbers
        if createInvoices {
            let invoicesCreated = try await createInvoicesFromImport(invoiceEntries)
            if invoicesCreated > 0 {
                errors.insert("\(invoicesCreated) facturen aangemaakt", at: 0)
            }
        }

        try modelContext.save()

        return ImportResult(
            imported: imported,
            skipped: skipped,
            errors: errors,
            type: .timeEntries
        )
    }

    private enum ImportEntryResult {
        case imported(TimeEntry, invoiceNumber: String?)
        case skipped
        case error(String)
    }

    private func importTimeEntryLine(_ line: String) async throws -> ImportEntryResult {
        // Split by semicolon
        let components = line.components(separatedBy: ";")

        // Need at least 6 columns for valid entry (date, code, client, activity, location, hours)
        guard components.count >= 6 else {
            return .error("Verwacht minimaal 6 kolommen, gevonden: \(components.count)")
        }

        // Check for Excel #REF! errors in the line
        if line.contains("#REF!") {
            return .error("Excel #REF! fout gevonden - controleer bronbestand")
        }

        // Parse date: DD/MM/YYYY
        let dateStr = components[0].trimmingCharacters(in: .whitespaces)
        guard let datum = DutchDateFormatter.parseCSVDate(dateStr) else {
            return .error("Ongeldige datum: '\(dateStr)'")
        }

        let code = components[1].trimmingCharacters(in: .whitespaces)
        let klantNaam = components[2].trimmingCharacters(in: .whitespaces)
        let activiteit = components[3].trimmingCharacters(in: .whitespaces)
        let locatie = components[4].trimmingCharacters(in: .whitespaces)

        // Parse uren: "9,00" -> 9.0
        let urenStr = components[5].trimmingCharacters(in: .whitespaces)
        guard let uren = urenStr.asDutchDecimal else {
            return .error("Ongeldig getal voor uren: '\(urenStr)'")
        }

        // Parse visitekilometers (optional, column 6)
        let visiteKm: Decimal?
        if components.count > 6 {
            let visiteStr = components[6].trimmingCharacters(in: .whitespaces)
            visiteKm = visiteStr.isEmpty ? nil : visiteStr.asDutchDecimal
        } else {
            visiteKm = nil
        }

        // Parse retourafstand: "108" -> 108 (column 7)
        var retourafstand = 0
        if components.count > 7 {
            let retourStr = components[7].trimmingCharacters(in: .whitespaces)
            retourafstand = retourStr.asDutchInteger ?? 0
        }

        // Parse uurtarief: "€ 70,00" -> 70.0 (column 8)
        var uurtarief: Decimal = 0
        if components.count > 8 {
            let tariefStr = components[8].trimmingCharacters(in: .whitespaces)
            if let tarief = tariefStr.asDutchCurrency {
                uurtarief = tarief
            } else if !tariefStr.isEmpty && !tariefStr.contains("#") {
                return .error("Ongeldig uurtarief: '\(tariefStr)'")
            }
        }

        // Parse kilometertarief: "€ 0,21" -> 0.21 (column 9)
        var kmtarief: Decimal = 0.23 // Default
        if components.count > 9 {
            let kmStr = components[9].trimmingCharacters(in: .whitespaces)
            if let tarief = kmStr.asDutchCurrency {
                kmtarief = tarief
            }
            // Don't fail on invalid km tariff, just use default
        }

        // Parse factuurnummer (column 13)
        var factuurnummer: String? = nil
        if components.count > 13 {
            let invoiceStr = components[13].trimmingCharacters(in: .whitespaces)
            if !invoiceStr.isEmpty {
                factuurnummer = invoiceStr
            }
        }

        // Parse opmerkingen (column 14)
        var opmerkingen: String? = nil
        if components.count > 14 {
            let opmerkingenStr = components[14].trimmingCharacters(in: .whitespaces)
            if !opmerkingenStr.isEmpty {
                opmerkingen = opmerkingenStr
            }
        }

        // Find matching client
        let client = await findClient(named: klantNaam)

        // If no client found and we have a client name, try to create one
        var finalClient = client
        if client == nil && !klantNaam.isEmpty {
            finalClient = createClientFromTimeEntry(name: klantNaam, location: locatie, uurtarief: uurtarief, kmtarief: kmtarief, retourafstand: retourafstand)
        }

        // Determine if billable
        let isBillable = code != "Admin" && code != "NSCHL" && uurtarief > 0

        // Determine if already invoiced
        let isInvoiced = factuurnummer != nil

        // Check for duplicate (same date, code, hours)
        let startOfDay = Calendar.current.startOfDay(for: datum)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.datum >= startOfDay &&
                entry.datum < endOfDay &&
                entry.uren == uren &&
                entry.code == code
            }
        )

        let existing = try modelContext.fetch(descriptor)
        if !existing.isEmpty {
            return .skipped // Skip duplicate
        }

        let entry = TimeEntry(
            datum: datum,
            code: code,
            activiteit: activiteit,
            locatie: locatie,
            uren: uren,
            visiteKilometers: visiteKm,
            retourafstandWoonWerk: retourafstand,
            uurtarief: uurtarief,
            kilometertarief: kmtarief,
            opmerkingen: opmerkingen,
            isBillable: isBillable,
            isInvoiced: isInvoiced,
            factuurnummer: factuurnummer,
            client: finalClient
        )

        modelContext.insert(entry)
        return .imported(entry, invoiceNumber: factuurnummer)
    }

    // MARK: - Create Invoices from Imported Entries

    private func createInvoicesFromImport(_ invoiceEntries: [String: [TimeEntry]]) async throws -> Int {
        var created = 0

        for (invoiceNumber, entries) in invoiceEntries {
            // Check if invoice already exists
            let descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.factuurnummer == invoiceNumber }
            )
            let existing = try modelContext.fetch(descriptor)

            if existing.isEmpty {
                // Get client from first entry
                let client = entries.first?.client

                // Determine invoice date from entries
                let sortedEntries = entries.sorted { $0.datum > $1.datum }
                let invoiceDate = sortedEntries.first?.datum ?? Date()

                // Create invoice
                let invoice = Invoice(
                    factuurnummer: invoiceNumber,
                    factuurdatum: invoiceDate,
                    betalingstermijn: 14,
                    status: .betaald, // Assume imported invoices are paid
                    client: client,
                    notities: "Geïmporteerd uit CSV"
                )

                modelContext.insert(invoice)

                // Link entries to invoice
                for entry in entries {
                    entry.invoice = invoice
                }

                if invoice.timeEntries == nil {
                    invoice.timeEntries = entries
                } else {
                    invoice.timeEntries?.append(contentsOf: entries)
                }

                created += 1
            } else {
                // Invoice exists, link entries to it
                if let existingInvoice = existing.first {
                    for entry in entries {
                        entry.invoice = existingInvoice
                    }
                }
            }
        }

        return created
    }

    // MARK: - Create Client from Time Entry

    private func createClientFromTimeEntry(name: String, location: String, uurtarief: Decimal, kmtarief: Decimal, retourafstand: Int) -> Client {
        // Determine client type based on name or rate
        let clientType: ClientType
        if name.lowercased().contains("doktersdienst") ||
           name.lowercased().contains("dokter drenthe") ||
           uurtarief >= 100 {
            clientType = .anwDienst
        } else if name.lowercased().contains("roberg") ||
                  name.lowercased().contains("admin") {
            clientType = .administratie
        } else {
            clientType = .dagpraktijk
        }

        let client = Client(
            bedrijfsnaam: name,
            contactpersoon: nil,
            adres: "",
            postcodeplaats: location,
            standaardUurtarief: uurtarief > 0 ? uurtarief : clientType.defaultHourlyRate,
            standaardKmTarief: kmtarief > 0 ? kmtarief : 0.23,
            afstandRetour: retourafstand,
            clientType: clientType,
            isActive: true
        )

        modelContext.insert(client)
        return client
    }

    // MARK: - Helper Methods

    private func findClient(named name: String) async -> Client? {
        let searchName = name.trimmingCharacters(in: .whitespaces)

        guard !searchName.isEmpty else { return nil }

        // Try exact match first
        var descriptor = FetchDescriptor<Client>(
            predicate: #Predicate { $0.bedrijfsnaam == searchName }
        )
        descriptor.fetchLimit = 1

        if let client = try? modelContext.fetch(descriptor).first {
            return client
        }

        // Try partial match
        let allClients = try? modelContext.fetch(FetchDescriptor<Client>())
        return allClients?.first { client in
            client.bedrijfsnaam.localizedCaseInsensitiveContains(searchName) ||
            searchName.localizedCaseInsensitiveContains(client.bedrijfsnaam)
        }
    }

    private func estimateDistance(from postcodeplaats: String) -> Int {
        // Known distances based on your data
        let knownDistances: [String: Int] = [
            "Vlagtwedde": 108,
            "Winsum": 44,
            "Marum": 44,
            "Sellingen": 90,
            "Smilde": 60,
            "Zuidbroek": 50,
            "De Wilp": 35,
            "Groningen": 10,
            "Assen": 40,
            "Stadskanaal": 47,
            "Delfzijl": 45,
            "Haren": 15,
            "Beilen": 50
        ]

        for (location, distance) in knownDistances {
            if postcodeplaats.localizedCaseInsensitiveContains(location) {
                return distance
            }
        }

        return 0
    }
}

// MARK: - Import Result
struct ImportResult {
    let imported: Int
    let skipped: Int
    let errors: [String]
    let type: ImportType

    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { errors.contains { $0.contains("facturen aangemaakt") } }

    var summary: String {
        var parts: [String] = []
        parts.append("\(imported) \(type.itemName) geïmporteerd")
        if skipped > 0 {
            parts.append("\(skipped) overgeslagen (duplicaten)")
        }
        let realErrors = errors.filter { !$0.contains("facturen aangemaakt") }
        if !realErrors.isEmpty {
            parts.append("\(realErrors.count) fouten")
        }
        return parts.joined(separator: ", ")
    }

    var infoMessages: [String] {
        errors.filter { $0.contains("facturen aangemaakt") }
    }

    var errorMessages: [String] {
        errors.filter { !$0.contains("facturen aangemaakt") }
    }
}

enum ImportType {
    case clients
    case timeEntries
    case bankTransactions

    var itemName: String {
        switch self {
        case .clients: return "klanten"
        case .timeEntries: return "urenregistraties"
        case .bankTransactions: return "transacties"
        }
    }
}

// MARK: - Import Errors
enum ImportError: LocalizedError {
    case invalidFormat(String)
    case invalidDate(String)
    case invalidNumber(String, String)
    case clientNotFound(String)
    case excelError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let details):
            return "Ongeldig formaat: \(details)"
        case .invalidDate(let value):
            return "Ongeldige datum: '\(value)'"
        case .invalidNumber(let field, let value):
            return "Ongeldig getal voor \(field): '\(value)'"
        case .clientNotFound(let name):
            return "Klant niet gevonden: '\(name)'"
        case .excelError(let details):
            return "Excel fout: \(details)"
        }
    }
}
