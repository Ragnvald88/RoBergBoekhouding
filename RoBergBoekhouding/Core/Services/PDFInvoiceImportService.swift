import Foundation
import SwiftData
import PDFKit

/// Service for importing invoices from PDF files
@MainActor
class PDFInvoiceImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Import Single PDF Invoice

    func importInvoice(from url: URL) throws -> PDFImportResult {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFImportError.cannotReadPDF
        }

        // Extract text from all pages
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        guard !fullText.isEmpty else {
            throw PDFImportError.noTextContent
        }

        // Parse the invoice
        let parsedInvoice = try parseInvoiceText(fullText, fileName: url.lastPathComponent)

        // Check for duplicate
        let invoiceNum = parsedInvoice.invoiceNumber
        let existingDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.factuurnummer == invoiceNum }
        )
        let existing = try modelContext.fetch(existingDescriptor)
        if !existing.isEmpty {
            return PDFImportResult(
                success: false,
                invoiceNumber: parsedInvoice.invoiceNumber,
                message: "Factuur \(parsedInvoice.invoiceNumber) bestaat al",
                timeEntriesCreated: 0,
                totalAmount: 0
            )
        }

        // Find or create client
        let client = findOrCreateClient(
            name: parsedInvoice.clientName,
            contactPerson: parsedInvoice.clientContact,
            address: parsedInvoice.clientAddress,
            postcodeplaats: parsedInvoice.clientPostcode
        )

        // Create invoice
        let invoice = Invoice(
            factuurnummer: parsedInvoice.invoiceNumber,
            factuurdatum: parsedInvoice.invoiceDate,
            betalingstermijn: 14,
            status: .betaald, // Assume imported invoices are paid
            client: client,
            notities: "Geïmporteerd uit PDF: \(url.lastPathComponent)"
        )

        modelContext.insert(invoice)

        // Store the imported PDF in the documents directory
        let year = Calendar.current.component(.year, from: parsedInvoice.invoiceDate)
        if let pdfData = try? Data(contentsOf: url) {
            do {
                let storedPath = try DocumentStorageService.shared.storePDF(
                    pdfData,
                    type: .importedPDF,
                    identifier: parsedInvoice.invoiceNumber,
                    year: year
                )
                invoice.importedPdfPath = storedPath
            } catch {
                // Continue even if storage fails - the import itself succeeded
                print("Warning: Could not store imported PDF: \(error.localizedDescription)")
            }
        }

        // Create time entries from line items
        var entriesCreated = 0
        for item in parsedInvoice.lineItems {
            // Check if this is an hours entry (not km)
            if item.isHoursEntry {
                let entry = TimeEntry(
                    datum: item.date,
                    code: "WDAGPRAKTIJK_\(Int(truncating: item.rate as NSDecimalNumber))",
                    activiteit: item.description,
                    locatie: parsedInvoice.clientLocation,
                    uren: item.quantity,
                    visiteKilometers: nil,
                    retourafstandWoonWerk: 0, // Will be set from km entry
                    uurtarief: item.rate,
                    kilometertarief: 0.23,
                    opmerkingen: nil,
                    isBillable: true,
                    isInvoiced: true,
                    factuurnummer: parsedInvoice.invoiceNumber,
                    client: client
                )
                entry.invoice = invoice
                modelContext.insert(entry)
                entriesCreated += 1
            }
        }

        // Update time entries with km data
        for item in parsedInvoice.lineItems where !item.isHoursEntry {
            // Find the matching hours entry for this date
            let itemDate = item.date
            let startOfDay = Calendar.current.startOfDay(for: itemDate)
            guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
                continue // Skip this item if date calculation fails
            }
            let searchInvoiceNum: String? = invoiceNum

            let descriptor = FetchDescriptor<TimeEntry>(
                predicate: #Predicate { entry in
                    entry.datum >= startOfDay &&
                    entry.datum < endOfDay &&
                    entry.factuurnummer == searchInvoiceNum
                }
            )

            if let matchingEntry = try? modelContext.fetch(descriptor).first {
                matchingEntry.retourafstandWoonWerk = Int(truncating: item.quantity as NSDecimalNumber)
                matchingEntry.kilometertarief = item.rate
            }
        }

        // Link entries to invoice
        let allEntriesDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.factuurnummer == invoiceNum }
        )
        let allEntries = try modelContext.fetch(allEntriesDescriptor)
        invoice.timeEntries = allEntries

        try modelContext.save()

        return PDFImportResult(
            success: true,
            invoiceNumber: parsedInvoice.invoiceNumber,
            message: "Factuur \(parsedInvoice.invoiceNumber) geïmporteerd",
            timeEntriesCreated: entriesCreated,
            totalAmount: parsedInvoice.totalAmount
        )
    }

    // MARK: - Import Multiple PDFs from Folder

    func importInvoicesFromFolder(at url: URL) throws -> [PDFImportResult] {
        let fileManager = FileManager.default
        var results: [PDFImportResult] = []

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let pdfFiles = contents.filter { $0.pathExtension.lowercased() == "pdf" }

        for pdfURL in pdfFiles {
            do {
                let result = try importInvoice(from: pdfURL)
                results.append(result)
            } catch {
                results.append(PDFImportResult(
                    success: false,
                    invoiceNumber: pdfURL.lastPathComponent,
                    message: error.localizedDescription,
                    timeEntriesCreated: 0,
                    totalAmount: 0
                ))
            }
        }

        return results
    }

    // MARK: - Parse Invoice Text

    private func parseInvoiceText(_ text: String, fileName: String) throws -> ParsedInvoice {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        // Extract invoice number
        var invoiceNumber: String?
        for line in lines {
            // Try different patterns
            if let match = extractPattern(from: line, pattern: "Nummer:\\s*([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
                break
            }
            if let match = extractPattern(from: line, pattern: "Factuurnummer:\\s*([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
                break
            }
            if let match = extractPattern(from: line, pattern: "^([0-9]{4}-[0-9]{3})$") {
                invoiceNumber = match
                break
            }
        }

        // Try to get from filename if not found
        if invoiceNumber == nil {
            if let match = extractPattern(from: fileName, pattern: "([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
            }
        }

        guard let finalInvoiceNumber = invoiceNumber else {
            throw PDFImportError.cannotParseInvoiceNumber
        }

        // Extract invoice date - PDF text extraction may split label and date
        var invoiceDate = Date()
        var foundDate = false

        for (index, line) in lines.enumerated() {
            // Pattern 1: Date on same line as label
            if line.lowercased().contains("factuurdatum") {
                // Try to extract date from same line
                if let match = extractPattern(from: line, pattern: "([0-9]{1,2}-[0-9]{1,2}-[0-9]{4})") {
                    if let date = parseDate(match) {
                        invoiceDate = date
                        foundDate = true
                        break
                    }
                }
                // If not on same line, check next few lines for a date
                for nextIndex in (index + 1)..<min(index + 3, lines.count) {
                    let nextLine = lines[nextIndex]
                    if let match = extractPattern(from: nextLine, pattern: "([0-9]{1,2}-[0-9]{1,2}-[0-9]{4})") {
                        if let date = parseDate(match) {
                            invoiceDate = date
                            foundDate = true
                            break
                        }
                    }
                }
                if foundDate { break }
            }
        }

        // Fallback: look for any date pattern near the top of the document
        if !foundDate {
            for line in lines.prefix(30) {
                if let match = extractPattern(from: line, pattern: "([0-9]{2}-[0-9]{2}-[0-9]{4})") {
                    if let date = parseDate(match) {
                        // Sanity check: date should be in reasonable range (not future, not too old)
                        let calendar = Calendar.current
                        let yearOfDate = calendar.component(.year, from: date)
                        if yearOfDate >= 2020 && yearOfDate <= calendar.component(.year, from: Date()) + 1 {
                            invoiceDate = date
                            break
                        }
                    }
                }
            }
        }

        // Extract client info
        var clientName = ""
        var clientContact = ""
        var clientAddress = ""
        var clientPostcode = ""
        var clientLocation = ""

        // Look for "Factuur aan:" section or client address block
        var inClientSection = false
        var clientLines: [String] = []

        for line in lines {
            if line.contains("Factuur aan:") || line.contains("Factuur aan") {
                inClientSection = true
                continue
            }
            if inClientSection {
                if line.isEmpty || line.contains("Datum") || line.contains("Omschrijving") {
                    break
                }
                clientLines.append(line)
            }
        }

        // If no "Factuur aan:" found, try to find client from known patterns
        if clientLines.isEmpty {
            for line in lines {
                if line.contains("Huisartspraktijk") || line.contains("Huisartsenpraktijk") ||
                   line.contains("Doktersdienst") || line.contains("Dokter Drenthe") {
                    clientLines.append(line)
                    // Get next few lines for address
                    if let idx = lines.firstIndex(of: line) {
                        for i in 1...3 {
                            if idx + i < lines.count {
                                let nextLine = lines[idx + i]
                                if !nextLine.isEmpty && !nextLine.contains("Bastion") && !nextLine.contains("RoBerg") {
                                    clientLines.append(nextLine)
                                }
                            }
                        }
                    }
                    break
                }
            }
        }

        // Parse client lines
        if clientLines.count > 0 {
            clientName = clientLines[0]
        }
        if clientLines.count > 1 {
            // Check if second line is contact person or address
            if clientLines[1].contains("G.E.M.") || clientLines[1].contains("M.") ||
               clientLines[1].split(separator: " ").count <= 3 && !clientLines[1].contains(where: { $0.isNumber }) {
                clientContact = clientLines[1]
                if clientLines.count > 2 { clientAddress = clientLines[2] }
                if clientLines.count > 3 { clientPostcode = clientLines[3] }
            } else {
                clientAddress = clientLines[1]
                if clientLines.count > 2 { clientPostcode = clientLines[2] }
            }
        }

        // Extract location from postcode
        if let location = extractLocation(from: clientPostcode) {
            clientLocation = location
        }

        // Parse line items
        var lineItems: [ParsedLineItem] = []

        // Find table section
        var inTable = false
        var currentDate: Date?

        for line in lines {
            // Detect table start
            if line.contains("Datum") && (line.contains("Omschrijving") || line.contains("Tarief")) {
                inTable = true
                continue
            }

            // Detect table end
            if inTable && (line.contains("TOTAAL") || line.contains("Totaal uren") || line.contains("Betaalinformatie")) {
                break
            }

            if inTable && !line.isEmpty {
                // Try to parse as line item
                if let item = parseLineItem(line, currentDate: currentDate) {
                    if item.date != currentDate {
                        currentDate = item.date
                    }
                    lineItems.append(item)
                }
            }
        }

        // Extract total - PRIORITY: "Te betalen bedrag" over "TOTAAL"
        // For split invoices (deelbetaling), "Te betalen bedrag" is the actual amount
        var totalAmount: Decimal = 0
        var foundTeBetalen = false

        // First pass: look for "Te betalen bedrag" (highest priority)
        // PDF text extraction may put label and value on same or different lines
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("te betalen bedrag") {
                // Try to extract amount from same line
                if let amount = extractCurrency(from: line) {
                    totalAmount = amount
                    foundTeBetalen = true
                    break
                }
                // If not on same line, check next few lines for euro amount
                for nextIndex in (index + 1)..<min(index + 4, lines.count) {
                    let nextLine = lines[nextIndex]
                    if let amount = extractCurrency(from: nextLine) {
                        totalAmount = amount
                        foundTeBetalen = true
                        break
                    }
                    // Stop if we hit another label
                    if nextLine.contains(":") && !nextLine.contains("€") {
                        break
                    }
                }
                if foundTeBetalen { break }
            }
        }

        // Second pass: only if "Te betalen bedrag" not found, look for TOTAAL
        if !foundTeBetalen {
            for line in lines {
                if (line.contains("TOTAAL") || line.contains("Totaal")) && line.contains("€") {
                    // Skip lines that are subtotals (like "Totaal uren")
                    if line.contains("uren") || line.contains("km") || line.contains("kilometer") {
                        continue
                    }
                    if let amount = extractCurrency(from: line) {
                        totalAmount = amount
                        break
                    }
                }
            }
        }

        // Calculate total from line items if still not found
        if totalAmount == 0 {
            totalAmount = lineItems.reduce(0) { $0 + $1.total }
        }

        return ParsedInvoice(
            invoiceNumber: finalInvoiceNumber,
            invoiceDate: invoiceDate,
            clientName: clientName,
            clientContact: clientContact,
            clientAddress: clientAddress,
            clientPostcode: clientPostcode,
            clientLocation: clientLocation,
            lineItems: lineItems,
            totalAmount: totalAmount
        )
    }

    private func parseLineItem(_ line: String, currentDate: Date?) -> ParsedLineItem? {
        // Try to extract date from line
        var itemDate = currentDate ?? Date()

        // Pattern for date at start: "04-11-2025" or "15-12-23"
        if let dateMatch = extractPattern(from: line, pattern: "^([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})") {
            if let date = parseDate(dateMatch) {
                itemDate = date
            }
        }

        // Determine if this is hours or km
        let isHours = line.contains("Waarneming") || line.contains("Uren") || line.contains("dagpraktijk")
        let isKm = line.contains("Reiskosten") || line.contains("Kilometer") || line.contains("km") || line.contains("Afstand")

        guard isHours || isKm else { return nil }

        // Extract numbers from the line
        let numbers = extractAllNumbers(from: line)

        // We need at least quantity, rate, total
        guard numbers.count >= 2 else { return nil }

        // Parse based on type
        var quantity: Decimal = 0
        var rate: Decimal = 0
        var total: Decimal = 0

        // For hours: typically 9, 70.00, 630.00 or similar
        // For km: typically 108, 0.23, 24.84 or similar

        if isHours {
            // Hours quantity is usually single/double digit
            for num in numbers {
                if num <= 24 && num > 0 && quantity == 0 {
                    quantity = num
                } else if num >= 50 && num <= 200 && rate == 0 {
                    // Hourly rate range
                    rate = num
                } else if num > 200 && total == 0 {
                    total = num
                }
            }
        } else {
            // Kilometers
            for num in numbers {
                if num >= 10 && num <= 500 && quantity == 0 {
                    // km range
                    quantity = num
                } else if num < 1 && rate == 0 {
                    // km rate (0.21, 0.23)
                    rate = num
                } else if num > 1 && num < 100 && total == 0 {
                    total = num
                }
            }
        }

        // Validate we have meaningful data
        guard quantity > 0 else { return nil }

        // Calculate total if not found
        if total == 0 && rate > 0 {
            total = quantity * rate
        }

        // Estimate rate if not found (guard against division by zero)
        if rate == 0 && total > 0 && quantity > 0 {
            rate = total / quantity
        }

        let description = isHours ? "Waarneming dagpraktijk" : "Reiskosten"

        return ParsedLineItem(
            date: itemDate,
            description: description,
            quantity: quantity,
            rate: rate,
            total: total,
            isHoursEntry: isHours
        )
    }

    // MARK: - Helper Methods

    private func findOrCreateClient(name: String, contactPerson: String, address: String, postcodeplaats: String) -> Client? {
        guard !name.isEmpty else { return nil }

        // Try to find existing client
        let searchName = name
        let descriptor = FetchDescriptor<Client>(
            predicate: #Predicate { $0.bedrijfsnaam == searchName }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // Try partial match
        let allClients = try? modelContext.fetch(FetchDescriptor<Client>())
        if let match = allClients?.first(where: {
            $0.bedrijfsnaam.localizedCaseInsensitiveContains(name) ||
            name.localizedCaseInsensitiveContains($0.bedrijfsnaam)
        }) {
            return match
        }

        // Create new client
        let clientType: ClientType = name.lowercased().contains("dokter") ? .anwDienst : .dagpraktijk
        let distance = estimateDistance(from: postcodeplaats)

        let client = Client(
            bedrijfsnaam: name,
            contactpersoon: contactPerson.isEmpty ? nil : contactPerson,
            adres: address,
            postcodeplaats: postcodeplaats,
            standaardUurtarief: clientType.defaultHourlyRate,
            standaardKmTarief: 0.23,
            afstandRetour: distance,
            clientType: clientType,
            isActive: true
        )

        modelContext.insert(client)
        return client
    }

    private func extractPattern(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            if match.numberOfRanges > 1 {
                if let matchRange = Range(match.range(at: 1), in: text) {
                    return String(text[matchRange])
                }
            }
        }
        return nil
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters = [
            "dd-MM-yyyy",
            "d-M-yyyy",
            "dd-MM-yy",
            "d-M-yy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "nl_NL")
            if let date = formatter.date(from: string) {
                // Handle 2-digit years
                if format.contains("yy") && !format.contains("yyyy") {
                    let year = Calendar.current.component(.year, from: date)
                    if year < 100 {
                        // Assume 2000s
                        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                        components.year = 2000 + year
                        return Calendar.current.date(from: components)
                    }
                }
                return date
            }
        }
        return nil
    }

    private func parseDecimal(_ string: String) -> Decimal? {
        var cleaned = string
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Dutch format: 1.234,56 (period = thousands, comma = decimal)
        // Check if there's both a period AND a comma
        let hasPeriod = cleaned.contains(".")
        let hasComma = cleaned.contains(",")

        if hasPeriod && hasComma {
            // Both present: period is thousands separator, comma is decimal
            // e.g., "2.195,67" -> "2195.67"
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else if hasComma && !hasPeriod {
            // Only comma: it's the decimal separator
            // e.g., "505,00" -> "505.00"
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        // If only period or neither, the string is already in a parseable format

        return Decimal(string: cleaned)
    }

    private func extractCurrency(from text: String) -> Decimal? {
        // Find euro amount pattern - try multiple patterns
        // Pattern 1: € followed by number (with optional spaces)
        if let match = extractPattern(from: text, pattern: "€\\s*([0-9][0-9.,]*)") {
            return parseDecimal(match)
        }

        // Pattern 2: Just a number that looks like currency (3+ digits with comma)
        // This catches standalone amounts like "658,70" on a line by itself
        if text.trimmingCharacters(in: .whitespaces).contains(",") {
            let cleaned = text.trimmingCharacters(in: .whitespaces)
            if let match = extractPattern(from: cleaned, pattern: "^([0-9][0-9.,]*)$") {
                return parseDecimal(match)
            }
        }

        return nil
    }

    private func extractAllNumbers(from text: String) -> [Decimal] {
        var numbers: [Decimal] = []

        // Pattern for numbers with optional decimal (Dutch format: 70,00 or 0,23)
        let pattern = "([0-9]+[,.]?[0-9]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return numbers
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            if let matchRange = Range(match.range(at: 1), in: text) {
                let numStr = String(text[matchRange])
                if let decimal = parseDecimal(numStr) {
                    numbers.append(decimal)
                }
            }
        }

        return numbers
    }

    private func extractLocation(from postcodeplaats: String) -> String? {
        // Extract city name from "9541 BK Vlagtwedde"
        let parts = postcodeplaats.split(separator: " ")
        if parts.count >= 3 {
            return parts.dropFirst(2).joined(separator: " ")
        }
        return nil
    }

    private func estimateDistance(from postcodeplaats: String) -> Int {
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
            "Delfzijl": 45
        ]

        for (location, distance) in knownDistances {
            if postcodeplaats.localizedCaseInsensitiveContains(location) {
                return distance
            }
        }

        return 0
    }
}

// MARK: - Data Structures

struct ParsedInvoice {
    let invoiceNumber: String
    let invoiceDate: Date
    let clientName: String
    let clientContact: String
    let clientAddress: String
    let clientPostcode: String
    let clientLocation: String
    let lineItems: [ParsedLineItem]
    let totalAmount: Decimal
}

struct ParsedLineItem {
    let date: Date
    let description: String
    let quantity: Decimal
    let rate: Decimal
    let total: Decimal
    let isHoursEntry: Bool
}

struct PDFImportResult {
    let success: Bool
    let invoiceNumber: String
    let message: String
    let timeEntriesCreated: Int
    let totalAmount: Decimal
}

// MARK: - Errors

enum PDFImportError: LocalizedError {
    case cannotReadPDF
    case noTextContent
    case cannotParseInvoiceNumber
    case cannotParseDate
    case cannotParseLineItems

    var errorDescription: String? {
        switch self {
        case .cannotReadPDF:
            return "Kan PDF bestand niet lezen"
        case .noTextContent:
            return "Geen tekst gevonden in PDF"
        case .cannotParseInvoiceNumber:
            return "Kan factuurnummer niet vinden"
        case .cannotParseDate:
            return "Kan datum niet lezen"
        case .cannotParseLineItems:
            return "Kan factuurregels niet lezen"
        }
    }
}
