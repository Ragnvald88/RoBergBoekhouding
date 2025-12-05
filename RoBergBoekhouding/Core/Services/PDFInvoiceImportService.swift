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
        var entriesSkipped = 0

        // For split payment invoices, apply verdeelfactor to hours
        let factor = parsedInvoice.verdeelfactor ?? 1

        for item in parsedInvoice.lineItems {
            // Check if this is an hours entry (not km)
            if item.isHoursEntry {
                // Calculate proportional hours for split payments
                let proportionalHours = item.quantity * factor

                // Check for duplicate time entry (same date, same client, similar hours)
                let itemDate = item.date
                let startOfDay = Calendar.current.startOfDay(for: itemDate)
                guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
                    continue
                }

                // Check if entry already exists for this date/client combination
                let clientId = client?.id
                let duplicateDescriptor = FetchDescriptor<TimeEntry>(
                    predicate: #Predicate<TimeEntry> { entry in
                        entry.datum >= startOfDay &&
                        entry.datum < endOfDay &&
                        entry.client?.id == clientId
                    }
                )

                if let existingEntries = try? modelContext.fetch(duplicateDescriptor), !existingEntries.isEmpty {
                    // Skip duplicate entry
                    entriesSkipped += 1
                    continue
                }

                // Determine activity code based on type
                let activityCode: String
                if let dienstCode = item.dienstCode {
                    activityCode = "ANW_\(dienstCode)"
                } else {
                    activityCode = "WDAGPRAKTIJK_\(Int(truncating: item.rate as NSDecimalNumber))"
                }

                // Build description - note if split payment
                var description = item.description
                if parsedInvoice.isSplitPayment, let vf = parsedInvoice.verdeelfactor {
                    let percentage = Int(truncating: (vf * 100) as NSDecimalNumber)
                    description = "\(item.description) (\(percentage)% aandeel)"
                }

                let entry = TimeEntry(
                    datum: item.date,
                    code: activityCode,
                    activiteit: description,
                    locatie: parsedInvoice.clientLocation,
                    uren: proportionalHours,  // Use proportional hours
                    visiteKilometers: nil,
                    retourafstandWoonWerk: 0, // Will be set from km entry
                    uurtarief: item.rate,
                    kilometertarief: 0.23,
                    opmerkingen: parsedInvoice.isSplitPayment ? "Gedeelde dienst - verdeelfactor \(factor)" : nil,
                    isBillable: true,
                    isInvoiced: true,
                    factuurnummer: parsedInvoice.invoiceNumber,
                    isStandby: item.isStandby,
                    dienstCode: item.dienstCode,
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

        // Build result message
        var message = "Factuur \(parsedInvoice.invoiceNumber) geïmporteerd"
        if parsedInvoice.isSplitPayment, let vf = parsedInvoice.verdeelfactor {
            let percentage = Int(truncating: (vf * 100) as NSDecimalNumber)
            message += " (gedeeld: \(percentage)%)"
        }
        if entriesSkipped > 0 {
            message += " (\(entriesSkipped) dubbele entries overgeslagen)"
        }

        return PDFImportResult(
            success: true,
            invoiceNumber: parsedInvoice.invoiceNumber,
            message: message,
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

    // MARK: - Invoice Format Detection

    private enum InvoiceFormat {
        case formatA_vertical       // 2025-002: "9x" quantity, "Datum: 9 januari 2025" on separate line
        case formatB_slashDates     // 2025-001, 2025-003, 2025-005: "13/01/2025", hours+km same row
        case formatC_kmColumn       // 2025-008: km as separate column "Afstand woon-werk"
        case formatD_dashDates      // 2025-009, 2025-016: dashes, hours+km same row with Reiskosten
        case formatE_separateLines  // 2025-019, 2025-020: hours and km on separate rows
        case formatANW_dienst       // ANW dienst invoices from Dokter Drenthe, Doktersdienst Groningen
    }

    private func detectFormat(from lines: [String]) -> InvoiceFormat {
        let joinedText = lines.prefix(50).joined(separator: " ")

        // ANW Format: Dokter Drenthe or Doktersdienst Groningen with "UREN SPECIFICATIE" table
        if (joinedText.contains("Dokter Drenthe") || joinedText.contains("Doktersdienst Groningen") ||
            joinedText.contains("Doktersdienst Noord")) &&
           (joinedText.contains("UREN SPECIFICATIE") || joinedText.contains("Dienst ID")) {
            return .formatANW_dienst
        }

        // Format A: has "Datum:" followed by Dutch month name
        if joinedText.contains("Datum:") && (joinedText.contains("januari") || joinedText.contains("februari") ||
            joinedText.contains("maart") || joinedText.contains("april") || joinedText.contains("mei")) {
            return .formatA_vertical
        }

        // Format C: has "Afstand woon-werk" column
        if joinedText.contains("Afstand") && joinedText.contains("woon-werk") {
            return .formatC_kmColumn
        }

        // Format E: look for "Kilometers woon-werk" or "uren" in description (separate lines pattern)
        if joinedText.contains("Kilometers woon-werk") || joinedText.contains("dagpraktijk uren") {
            return .formatE_separateLines
        }

        // Check date format in table rows
        for line in lines {
            // Slash date format
            if let _ = extractPattern(from: line, pattern: "^\\s*[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}") {
                return .formatB_slashDates
            }
            // Dash date format at start of line
            if let _ = extractPattern(from: line, pattern: "^\\s*[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\\s+Waarneming") {
                return .formatD_dashDates
            }
        }

        // Default to format D (most common recent format)
        return .formatD_dashDates
    }

    // MARK: - Parse Invoice Text

    private func parseInvoiceText(_ text: String, fileName: String) throws -> ParsedInvoice {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let format = detectFormat(from: lines)

        // Extract invoice number
        var invoiceNumber: String?
        for line in lines {
            // Try different patterns - order matters!

            // ANW format: "FACTUURNUMMER : 22470-25-16" (note space before colon)
            if let match = extractPattern(from: line, pattern: "FACTUURNUMMER\\s*:\\s*([0-9]+-[0-9]+-[0-9]+)") {
                invoiceNumber = match
                break
            }

            // Standard formats: "Nummer: 2025-001" or "Factuurnummer: 2025-001"
            if let match = extractPattern(from: line, pattern: "Nummer:\\s*([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
                break
            }
            if let match = extractPattern(from: line, pattern: "Factuurnummer:\\s*([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
                break
            }
            if let match = extractPattern(from: line, pattern: "Factuur\\s+([0-9]{4}-[0-9]{3})") {
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
            // Try ANW format in filename (e.g., "0125_Dokter Drenthe.pdf" -> extract from content)
            // Or standard format "2025-001_Raupp.pdf"
            if let match = extractPattern(from: fileName, pattern: "([0-9]{4}-[0-9]{3})") {
                invoiceNumber = match
            }
        }

        guard let finalInvoiceNumber = invoiceNumber else {
            throw PDFImportError.cannotParseInvoiceNumber
        }

        // Extract invoice date - supports both / and - separators
        var invoiceDate = Date()
        var foundDate = false

        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("factuurdatum") {
                // Try both date formats
                if let match = extractPattern(from: line, pattern: "([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})") {
                    if let date = parseDate(match) {
                        invoiceDate = date
                        foundDate = true
                        break
                    }
                }
                // If not on same line, check next few lines
                for nextIndex in (index + 1)..<min(index + 3, lines.count) {
                    let nextLine = lines[nextIndex]
                    if let match = extractPattern(from: nextLine, pattern: "([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})") {
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

        // Fallback: look for any date pattern near the top
        if !foundDate {
            for line in lines.prefix(30) {
                if let match = extractPattern(from: line, pattern: "([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})") {
                    if let date = parseDate(match) {
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
            for (idx, line) in lines.enumerated() {
                if line.contains("Huisartspraktijk") || line.contains("Huisartsenpraktijk") ||
                   line.contains("Doktersdienst") || line.contains("Dokter Drenthe") ||
                   line.contains("S. Borgemeester") {
                    clientLines.append(line)
                    // Get next few lines for address
                    for i in 1...3 {
                        if idx + i < lines.count {
                            let nextLine = lines[idx + i]
                            if !nextLine.isEmpty && !nextLine.contains("Bastion") && !nextLine.contains("RoBerg") &&
                               !nextLine.contains("FACTUUR") && !nextLine.contains("Ronald") {
                                clientLines.append(nextLine)
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
            let secondLine = clientLines[1]
            let isContactPerson = secondLine.contains("G.E.M.") || secondLine.contains("M.") ||
                secondLine.contains("T.a.v.") || secondLine.contains("F.G.") ||
                (secondLine.split(separator: " ").count <= 3 && !secondLine.contains(where: { $0.isNumber }))

            if isContactPerson {
                clientContact = secondLine.replacingOccurrences(of: "T.a.v. ", with: "")
                if clientLines.count > 2 { clientAddress = clientLines[2] }
                if clientLines.count > 3 { clientPostcode = clientLines[3] }
            } else {
                clientAddress = secondLine
                if clientLines.count > 2 { clientPostcode = clientLines[2] }
            }
        }

        // Extract location from postcode
        if let location = extractLocation(from: clientPostcode) {
            clientLocation = location
        }

        // Parse line items based on detected format
        let lineItems = parseLineItems(from: lines, format: format)

        // Extract total - PRIORITY: "Te betalen bedrag" over "TOTAAL"
        var totalAmount: Decimal = 0
        var foundTeBetalen = false

        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("te betalen bedrag") {
                if let amount = extractCurrency(from: line) {
                    totalAmount = amount
                    foundTeBetalen = true
                    break
                }
                for nextIndex in (index + 1)..<min(index + 4, lines.count) {
                    let nextLine = lines[nextIndex]
                    if let amount = extractCurrency(from: nextLine) {
                        totalAmount = amount
                        foundTeBetalen = true
                        break
                    }
                    if nextLine.contains(":") && !nextLine.contains("€") {
                        break
                    }
                }
                if foundTeBetalen { break }
            }
        }

        if !foundTeBetalen {
            for line in lines {
                if (line.contains("TOTAAL") || line.contains("Totaal")) && line.contains("€") {
                    if line.lowercased().contains("uren") || line.lowercased().contains("km") ||
                       line.lowercased().contains("kilometer") {
                        continue
                    }
                    if let amount = extractCurrency(from: line) {
                        totalAmount = amount
                        break
                    }
                }
            }
        }

        if totalAmount == 0 {
            totalAmount = lineItems.filter { $0.isHoursEntry }.reduce(0) { $0 + $1.total }
        }

        // Detect split payment (Deelbetaling) and extract verdeelfactor
        var isSplitPayment = false
        var verdeelfactor: Decimal?

        let joinedText = lines.joined(separator: " ").lowercased()
        if joinedText.contains("deelbetaling") || joinedText.contains("verdeelfactor") ||
           joinedText.contains("naar rato") {
            isSplitPayment = true

            // Find the verdeelfactor for the invoice recipient
            // Look for pattern: "ClientName ... 0,23 ... €Amount" in the split table
            let cleanClientName = clientName.lowercased()
                .replacingOccurrences(of: "huisartsenpraktijk", with: "")
                .replacingOccurrences(of: "huisartspraktijk", with: "")
                .trimmingCharacters(in: .whitespaces)

            for line in lines {
                let lowered = line.lowercased()
                // Check if this line contains the client name (partial match)
                if lowered.contains(cleanClientName) || cleanClientName.split(separator: " ").first.map({ lowered.contains(String($0)) }) == true {
                    // Extract the verdeelfactor (decimal between 0 and 1)
                    // Pattern: look for "0,XX" format
                    if let match = extractPattern(from: line, pattern: "\\b0[,.]([0-9]{1,2})\\b") {
                        let factorStr = "0.\(match)"
                        verdeelfactor = Decimal(string: factorStr)
                        break
                    }
                }
            }
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
            totalAmount: totalAmount,
            verdeelfactor: verdeelfactor,
            isSplitPayment: isSplitPayment
        )
    }

    // MARK: - Parse Line Items (Format-aware)

    private func parseLineItems(from lines: [String], format: InvoiceFormat) -> [ParsedLineItem] {
        var items: [ParsedLineItem] = []
        var inTable = false
        var currentDate: Date?
        var lastHoursItem: ParsedLineItem?

        for (index, line) in lines.enumerated() {
            // Detect table start - different patterns for different formats
            if format == .formatANW_dienst {
                // ANW format: table starts with "UREN SPECIFICATIE" or "Dienst ID"
                if line.contains("UREN SPECIFICATIE") || line.contains("Dienst ID") {
                    inTable = true
                    continue
                }
            } else {
                // Standard formats: "Datum" + "Omschrijving/Tarief/Bedrag"
                if line.contains("Datum") && (line.contains("Omschrijving") || line.contains("Tarief") || line.contains("Bedrag")) {
                    inTable = true
                    continue
                }
            }

            // Detect table end
            if inTable {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Totaal") || line.contains("TOTAAL UREN") ||
                   line.contains("Totaalbedrag") || line.contains("Betaalinformatie") ||
                   line.contains("Gelieve deze factuur") {
                    break
                }
            }

            guard inTable && !line.isEmpty else { continue }

            switch format {
            case .formatA_vertical:
                // Format A: "9x  Waarneming Dagpraktijk  € 77,50  € 697,50" followed by "Datum: 9 januari 2025"
                if let item = parseFormatA(line: line, nextLines: Array(lines.suffix(from: min(index + 1, lines.count)))) {
                    items.append(item)
                }

            case .formatB_slashDates:
                // Format B: "13/01/2025  Waarneming dagpraktijk  8,5  € 77,50  € 12,42  € 658,75"
                if let item = parseFormatB(line: line, currentDate: currentDate) {
                    currentDate = item.date
                    items.append(item)
                }

            case .formatC_kmColumn:
                // Format C: "27-02-2025  Waarneming dagpraktijk  9  € 77,50  54  € 12,42  € 709,92"
                if let item = parseFormatC(line: line, currentDate: currentDate) {
                    currentDate = item.date
                    items.append(item)
                }

            case .formatD_dashDates:
                // Format D: "07/01/2025  Waarneming dagpraktijk  9,00  € 77,50  € 24,84  € 722,34"
                // Also handle km lines on separate rows
                let result = parseFormatD_withKm(line: line, currentDate: currentDate, lastHoursItem: lastHoursItem)
                if let item = result.item {
                    if item.isHoursEntry {
                        currentDate = item.date
                        lastHoursItem = item
                    }
                    items.append(item)
                }

            case .formatE_separateLines:
                // Format E: Hours and km on separate lines
                let result = parseFormatE(line: line, currentDate: currentDate, lastHoursItem: lastHoursItem)
                if let item = result.item {
                    if item.isHoursEntry {
                        currentDate = item.date
                        lastHoursItem = item
                    }
                    items.append(item)
                }

            case .formatANW_dienst:
                // Format ANW: Dokter Drenthe / Doktersdienst Groningen dienst table
                if let parsedItems = parseFormatANW(line: line, currentDate: currentDate) {
                    for item in parsedItems {
                        currentDate = item.date
                        items.append(item)
                    }
                }
            }
        }

        return items
    }

    // MARK: - Format-specific Parsers

    /// Format A: Vertical layout with "9x" quantity and "Datum: 9 januari 2025" on next line
    private func parseFormatA(line: String, nextLines: [String]) -> ParsedLineItem? {
        // Look for "9x" pattern at start
        guard let quantityMatch = extractPattern(from: line, pattern: "^([0-9]+)x?\\s") else { return nil }
        guard let quantity = Decimal(string: quantityMatch) else { return nil }

        let isHours = line.contains("Waarneming") || line.contains("Dagpraktijk") || line.contains("dagpraktijk")
        let isKm = line.contains("Reiskosten") || line.contains("Kilometer")

        guard isHours || isKm else { return nil }

        // Find date from "Datum: X januari 2025" in next lines
        var itemDate = Date()
        for nextLine in nextLines.prefix(2) {
            if nextLine.contains("Datum:") {
                if let date = parseDutchTextDate(nextLine) {
                    itemDate = date
                }
                break
            }
        }

        // Extract rate and total
        let numbers = extractCurrencyValues(from: line)

        var rate: Decimal = 0
        var total: Decimal = 0

        if isHours {
            rate = numbers.first { $0 >= 50 && $0 <= 150 } ?? 77.50
            total = numbers.first { $0 > 150 } ?? (quantity * rate)
        } else {
            rate = numbers.first { $0 < 1 } ?? 0.23
            total = numbers.first { $0 > 1 && $0 < 100 } ?? (quantity * rate)
        }

        return ParsedLineItem(
            date: itemDate,
            description: isHours ? "Waarneming dagpraktijk" : "Reiskosten",
            quantity: quantity,
            rate: rate,
            total: total,
            isHoursEntry: isHours
        )
    }

    /// Format B: Slash dates with hours+km combined - "13/01/2025  Waarneming  8,5  € 77,50  € 12,42  € 658,75"
    private func parseFormatB(line: String, currentDate: Date?) -> ParsedLineItem? {
        var itemDate = currentDate ?? Date()

        // Extract date with slashes at the START of line only
        if let dateMatch = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})") {
            if let date = parseDate(dateMatch) {
                itemDate = date
            }
        }

        // Must contain Waarneming for hours line
        guard line.contains("Waarneming") || line.contains("dagpraktijk") else { return nil }

        // Extract all currency values (€ prefixed numbers)
        let currencyValues = extractCurrencyValues(from: line)

        // Remove the date from line before extracting quantity
        var lineWithoutDate = line
        if let range = line.range(of: "^\\s*[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\\s*", options: .regularExpression) {
            lineWithoutDate = String(line[range.upperBound...])
        }

        // Extract quantity - look for number NOT preceded by € and before first €
        var quantity: Decimal = 0
        if let euroIndex = lineWithoutDate.firstIndex(of: "€") {
            let beforeEuro = String(lineWithoutDate[..<euroIndex])
            // Find decimal numbers like "8,5" or "9,00" or just "9"
            if let qtyMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+[,.]?[0-9]*)\\s*$") {
                quantity = parseDecimal(qtyMatch) ?? 0
            }
        }

        guard quantity > 0 && quantity <= 24 else { return nil }

        // Rate is typically first currency value (77.50)
        // Reiskosten is second currency value (12.42)
        // Total is last currency value
        let rate = currencyValues.first { $0 >= 50 && $0 <= 150 } ?? 77.50
        let reiskosten = currencyValues.first { $0 > 5 && $0 < 50 } ?? 0
        let total = currencyValues.last ?? (quantity * rate + reiskosten)

        return ParsedLineItem(
            date: itemDate,
            description: "Waarneming dagpraktijk",
            quantity: quantity,
            rate: rate,
            total: total,
            isHoursEntry: true
        )
    }

    /// Format C: km as separate column - "27-02-2025  Waarneming  9  € 77,50  54  € 12,42  € 709,92"
    private func parseFormatC(line: String, currentDate: Date?) -> ParsedLineItem? {
        var itemDate = currentDate ?? Date()

        // Extract date with dashes at the START of line
        if let dateMatch = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})") {
            if let date = parseDate(dateMatch) {
                itemDate = date
            }
        }

        guard line.contains("Waarneming") || line.contains("dagpraktijk") else { return nil }

        let currencyValues = extractCurrencyValues(from: line)

        // Remove date from line
        var lineWithoutDate = line
        if let range = line.range(of: "^\\s*[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\\s*", options: .regularExpression) {
            lineWithoutDate = String(line[range.upperBound...])
        }

        // Extract hours quantity (before first €)
        var hours: Decimal = 0
        if let euroIndex = lineWithoutDate.firstIndex(of: "€") {
            let beforeEuro = String(lineWithoutDate[..<euroIndex])
            let numbers = extractAllNumbers(from: beforeEuro)
            hours = numbers.first { $0 > 0 && $0 <= 24 } ?? 0
        }

        guard hours > 0 else { return nil }

        let rate = currencyValues.first { $0 >= 50 && $0 <= 150 } ?? 77.50
        let total = currencyValues.last ?? (hours * rate)

        return ParsedLineItem(
            date: itemDate,
            description: "Waarneming dagpraktijk",
            quantity: hours,
            rate: rate,
            total: total,
            isHoursEntry: true
        )
    }

    /// Format D: Dash dates with hours+reiskosten same row - "07/01/2025  Waarneming  9,00  € 77,50  € 24,84  € 722,34"
    private func parseFormatD(line: String, currentDate: Date?) -> ParsedLineItem? {
        var itemDate = currentDate ?? Date()

        // Extract date (both / and - formats) at START of line only
        if let dateMatch = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})") {
            if let date = parseDate(dateMatch) {
                itemDate = date
            }
        } else {
            // No date at start - might be a continuation line, skip it
            if !line.hasPrefix(" ") && currentDate == nil {
                return nil
            }
        }

        guard line.contains("Waarneming") || line.contains("dagpraktijk") else { return nil }

        let currencyValues = extractCurrencyValues(from: line)

        // Remove date from line before extracting quantity
        var lineWithoutDate = line
        if let range = line.range(of: "^\\s*[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4}\\s*", options: .regularExpression) {
            lineWithoutDate = String(line[range.upperBound...])
        }

        // Find quantity between description and first €
        var hours: Decimal = 0
        if let euroIndex = lineWithoutDate.firstIndex(of: "€") {
            let beforeEuro = String(lineWithoutDate[..<euroIndex])
            // Look for the LAST number before € (that's the quantity)
            if let qtyMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+[,.]?[0-9]*)\\s*$") {
                hours = parseDecimal(qtyMatch) ?? 0
            }
        }

        guard hours > 0 && hours <= 24 else { return nil }

        let rate = currencyValues.first { $0 >= 50 && $0 <= 150 } ?? 77.50
        let total = currencyValues.last ?? (hours * rate)

        return ParsedLineItem(
            date: itemDate,
            description: "Waarneming dagpraktijk",
            quantity: hours,
            rate: rate,
            total: total,
            isHoursEntry: true
        )
    }

    /// Format D with km support: Handles both hours lines and separate km lines
    private func parseFormatD_withKm(line: String, currentDate: Date?, lastHoursItem: ParsedLineItem?) -> (item: ParsedLineItem?, updatedDate: Date?) {
        var itemDate = currentDate ?? Date()

        // Check if line starts with a date
        let hasDate = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})") != nil

        if hasDate {
            if let dateMatch = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})") {
                if let date = parseDate(dateMatch) {
                    itemDate = date
                }
            }
        }

        // Determine line type
        let isHoursLine = line.contains("Waarneming") || line.contains("dagpraktijk")
        let isKmLine = line.contains("Reiskosten") || line.contains("Kilometer") || line.contains("km retour")

        if isHoursLine {
            // Parse hours line
            let currencyValues = extractCurrencyValues(from: line)

            // Remove date from line before extracting quantity
            var lineWithoutDate = line
            if let range = line.range(of: "^\\s*[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4}\\s*", options: .regularExpression) {
                lineWithoutDate = String(line[range.upperBound...])
            }

            // Find quantity between description and first €
            var hours: Decimal = 0
            if let euroIndex = lineWithoutDate.firstIndex(of: "€") {
                let beforeEuro = String(lineWithoutDate[..<euroIndex])
                // Look for the LAST number before € (that's the quantity)
                if let qtyMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+[,.]?[0-9]*)\\s*$") {
                    hours = parseDecimal(qtyMatch) ?? 0
                }
            }

            guard hours > 0 && hours <= 24 else { return (nil, itemDate) }

            let rate = currencyValues.first { $0 >= 50 && $0 <= 150 } ?? 77.50
            let total = currencyValues.last ?? (hours * rate)

            let item = ParsedLineItem(
                date: itemDate,
                description: "Waarneming dagpraktijk",
                quantity: hours,
                rate: rate,
                total: total,
                isHoursEntry: true
            )
            return (item, itemDate)

        } else if isKmLine {
            // Parse km line - uses date from previous hours entry if not present
            let kmDate = hasDate ? itemDate : (lastHoursItem?.date ?? currentDate ?? Date())
            let currencyValues = extractCurrencyValues(from: line)

            // Extract km quantity - look for number NOT in currency
            var kmDistance: Decimal = 0
            var lineForNumbers = line

            // Remove date if present
            if let range = line.range(of: "^\\s*[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4}\\s*", options: .regularExpression) {
                lineForNumbers = String(line[range.upperBound...])
            }

            // Find number between description and € (the km distance)
            if let euroIndex = lineForNumbers.firstIndex(of: "€") {
                let beforeEuro = String(lineForNumbers[..<euroIndex])
                if let kmMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+)\\s*$") {
                    kmDistance = Decimal(string: kmMatch) ?? 0
                }
            }

            guard kmDistance >= 10 && kmDistance <= 500 else { return (nil, currentDate) }

            let rate = currencyValues.first { $0 < 1 } ?? 0.23
            let total = currencyValues.first { $0 > 1 && $0 < 100 } ?? (kmDistance * rate)

            let item = ParsedLineItem(
                date: kmDate,
                description: "Reiskosten",
                quantity: kmDistance,
                rate: rate,
                total: total,
                isHoursEntry: false
            )
            return (item, currentDate)
        }

        return (nil, currentDate)
    }

    /// Format E: Separate lines for hours and km
    private func parseFormatE(line: String, currentDate: Date?, lastHoursItem: ParsedLineItem?) -> (item: ParsedLineItem?, updatedDate: Date?) {
        var itemDate = currentDate ?? Date()

        // Check if line starts with a date
        let hasDate = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})") != nil

        if hasDate {
            if let dateMatch = extractPattern(from: line, pattern: "^\\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})") {
                if let date = parseDate(dateMatch) {
                    itemDate = date
                }
            }
        }

        // Determine line type
        let isHoursLine = line.contains("Waarneming") || line.contains("dagpraktijk uren") ||
                          (line.contains("HOED") && !line.contains("Reiskosten"))
        let isKmLine = line.contains("Kilometer") || line.contains("Reiskosten") || line.contains("km")

        if isHoursLine {
            let currencyValues = extractCurrencyValues(from: line)

            // Remove date from line
            var lineWithoutDate = line
            if let range = line.range(of: "^\\s*[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\\s*", options: .regularExpression) {
                lineWithoutDate = String(line[range.upperBound...])
            }

            // Extract hours - number before first € but after description
            var hours: Decimal = 0
            if let euroIndex = lineWithoutDate.firstIndex(of: "€") {
                let beforeEuro = String(lineWithoutDate[..<euroIndex])
                // Get the last number before €
                if let qtyMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+[,.]?[0-9]*)\\s*$") {
                    hours = parseDecimal(qtyMatch) ?? 0
                }
            }

            guard hours > 0 && hours <= 24 else { return (nil, itemDate) }

            let rate = currencyValues.first { $0 >= 50 && $0 <= 150 } ?? 77.50
            let total = currencyValues.last ?? (hours * rate)

            let item = ParsedLineItem(
                date: itemDate,
                description: "Waarneming dagpraktijk",
                quantity: hours,
                rate: rate,
                total: total,
                isHoursEntry: true
            )
            return (item, itemDate)

        } else if isKmLine {
            // Km line - uses date from previous hours entry
            let kmDate = hasDate ? itemDate : (lastHoursItem?.date ?? currentDate ?? Date())
            let currencyValues = extractCurrencyValues(from: line)

            // Extract km quantity - look for number NOT in currency
            var kmDistance: Decimal = 0
            var lineForNumbers = line

            // Remove date if present
            if let range = line.range(of: "^\\s*[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\\s*", options: .regularExpression) {
                lineForNumbers = String(line[range.upperBound...])
            }

            // Find number between description and € (the km distance)
            if let euroIndex = lineForNumbers.firstIndex(of: "€") {
                let beforeEuro = String(lineForNumbers[..<euroIndex])
                if let kmMatch = extractPattern(from: beforeEuro, pattern: "([0-9]+)\\s*$") {
                    kmDistance = Decimal(string: kmMatch) ?? 0
                }
            }

            guard kmDistance >= 10 && kmDistance <= 500 else { return (nil, currentDate) }

            let rate = currencyValues.first { $0 < 1 } ?? 0.23
            let total = currencyValues.first { $0 > 1 && $0 < 100 } ?? (kmDistance * rate)

            let item = ParsedLineItem(
                date: kmDate,
                description: "Reiskosten",
                quantity: kmDistance,
                rate: rate,
                total: total,
                isHoursEntry: false
            )
            return (item, currentDate)
        }

        return (nil, currentDate)
    }

    /// Format ANW: Dokter Drenthe / Doktersdienst Groningen dienst invoices
    /// Line format: "506042  AW-WK-H  13-12-2024  17:00  00:00  7.00  Avond  € 6,72  Vrijgesteld  € 47,04"
    /// May have continuation lines without dienst ID for multi-part shifts (Nacht portion)
    private func parseFormatANW(line: String, currentDate: Date?) -> [ParsedLineItem]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Skip header lines and totals
        if trimmed.contains("Dienst ID") || trimmed.contains("Tarief Naam") ||
           trimmed.starts(with: "Totaal") || trimmed.contains("TOTAAL") ||
           trimmed.contains("SPECIFICATIE") || trimmed.contains("Vrijgesteld van") {
            return nil
        }

        // Check if this line has currency values (indicates actual data row)
        let currencyValues = extractCurrencyValues(from: line)
        guard !currencyValues.isEmpty else { return nil }

        var items: [ParsedLineItem] = []
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 4 else { return nil }

        var dienstCode: String?
        var dateStr: String?
        var hours: Decimal = 0
        var rate: Decimal = 0
        var total: Decimal = 0
        var tariefNaam: String = ""
        var isContinuationLine = false

        // First part should be dienst ID (6 digits) or it's a continuation line
        let firstPart = parts[0]

        if firstPart.count == 6 && Int(firstPart) != nil {
            // This is a new dienst entry
            dienstCode = parts.count > 1 ? parts[1] : nil
        } else if firstPart.contains(":") || firstPart == "00" {
            // Continuation line - starts with time like "00:00"
            isContinuationLine = true
        }

        // Find date (dd-mm-yyyy format) - only in main lines, not continuation
        if !isContinuationLine {
            for part in parts {
                if let _ = extractPattern(from: part, pattern: "^([0-9]{2}-[0-9]{2}-[0-9]{4})$") {
                    dateStr = part
                    break
                }
            }
        }

        // Find hours value - look for decimal number that's not part of time (no colon context)
        // Hours are typically after the times: "17:00  00:00  7.00"
        var foundTime = false
        for part in parts {
            if part.contains(":") {
                foundTime = true
                continue
            }
            if part.contains("€") || part.contains("-") {
                continue
            }
            // After finding time patterns, look for hours
            if foundTime || isContinuationLine {
                if let match = extractPattern(from: part, pattern: "^([0-9]+[,.]?[0-9]*)$") {
                    if let decimal = parseDecimal(match) {
                        if decimal > 0 && decimal <= 24 && hours == 0 {
                            hours = decimal
                            break
                        }
                    }
                }
            }
        }

        // Find tarief naam (Avond, Nacht, Weekend, Feestdag)
        let tariefNames = ["Avond", "Nacht", "Weekend", "Feestdag"]
        for name in tariefNames {
            if line.contains(name) {
                tariefNaam = name
                break
            }
        }

        // Rate is typically the first currency value, total is the last
        if currencyValues.count >= 2 {
            rate = currencyValues[0]
            total = currencyValues.last ?? 0
        } else if currencyValues.count == 1 {
            total = currencyValues[0]
            if hours > 0 {
                rate = total / hours
            }
        }

        guard hours > 0 else { return nil }

        // Parse the date - use currentDate for continuation lines
        var itemDate = currentDate ?? Date()
        if let dateString = dateStr, let date = parseDate(dateString) {
            itemDate = date
        }

        // Determine if this is achterwacht (standby) based on dienst code or rate
        // AW-* codes are achterwacht, rates < €50/hour indicate standby
        // For continuation lines, use rate to determine (as they don't have dienst code)
        let isStandby = (dienstCode?.hasPrefix("AW") == true) || (rate < 50)

        // Build description
        var description: String
        if isStandby {
            description = "Achterwacht \(tariefNaam)".trimmingCharacters(in: .whitespaces)
        } else {
            description = "ANW dienst \(tariefNaam)".trimmingCharacters(in: .whitespaces)
        }
        if description == "Achterwacht" || description == "ANW dienst" {
            description = dienstCode ?? (isStandby ? "Achterwacht" : "ANW dienst")
        }

        let item = ParsedLineItem(
            date: itemDate,
            description: description,
            quantity: hours,
            rate: rate,
            total: total,
            isHoursEntry: true,
            isStandby: isStandby,
            dienstCode: dienstCode
        )

        items.append(item)

        return items.isEmpty ? nil : items
    }

    // MARK: - Additional Helper Methods

    /// Parse Dutch text date like "Datum: 9 januari 2025"
    private func parseDutchTextDate(_ text: String) -> Date? {
        let dutchMonths = [
            "januari": 1, "februari": 2, "maart": 3, "april": 4,
            "mei": 5, "juni": 6, "juli": 7, "augustus": 8,
            "september": 9, "oktober": 10, "november": 11, "december": 12
        ]

        // Extract day number
        guard let dayMatch = extractPattern(from: text, pattern: "([0-9]{1,2})\\s+[a-z]") else { return nil }
        guard let day = Int(dayMatch) else { return nil }

        // Find month
        var month = 0
        for (monthName, monthNum) in dutchMonths {
            if text.lowercased().contains(monthName) {
                month = monthNum
                break
            }
        }
        guard month > 0 else { return nil }

        // Extract year
        guard let yearMatch = extractPattern(from: text, pattern: "([0-9]{4})") else { return nil }
        guard let year = Int(yearMatch) else { return nil }

        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year

        return Calendar.current.date(from: components)
    }

    /// Extract all € currency values from a line
    private func extractCurrencyValues(from text: String) -> [Decimal] {
        var values: [Decimal] = []

        // Pattern for € followed by number (handles Dutch format with comma as decimal)
        let pattern = "€\\s*([0-9]+[.,]?[0-9]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return values }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            if let matchRange = Range(match.range(at: 1), in: text) {
                let numStr = String(text[matchRange])
                if let decimal = parseDecimal(numStr) {
                    values.append(decimal)
                }
            }
        }

        return values
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
        // Normalize separator: replace / with -
        let normalized = string.replacingOccurrences(of: "/", with: "-")

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
            if let date = formatter.date(from: normalized) {
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
    let verdeelfactor: Decimal?  // For split payment invoices (0.0-1.0)
    let isSplitPayment: Bool     // True if "Deelbetaling" detected
}

struct ParsedLineItem {
    let date: Date
    let description: String
    let quantity: Decimal
    let rate: Decimal
    let total: Decimal
    let isHoursEntry: Bool
    let isStandby: Bool         // True for achterwacht (AW-*) diensten
    let dienstCode: String?     // ANW dienst code like "AW-WK-H", "SAV*", etc.

    init(date: Date, description: String, quantity: Decimal, rate: Decimal, total: Decimal,
         isHoursEntry: Bool, isStandby: Bool = false, dienstCode: String? = nil) {
        self.date = date
        self.description = description
        self.quantity = quantity
        self.rate = rate
        self.total = total
        self.isHoursEntry = isHoursEntry
        self.isStandby = isStandby
        self.dienstCode = dienstCode
    }
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
