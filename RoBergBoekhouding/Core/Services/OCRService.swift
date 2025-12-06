//
//  OCRService.swift
//  RoBergBoekhouding
//
//  Copyright 2024-2025 RoBerg. All rights reserved.
//

import Foundation
import Vision
import AppKit
import PDFKit

/// Extracted data from a receipt or invoice
struct OCRExtractedData {
    var bedrag: Decimal?
    var datum: Date?
    var leverancier: String?
    var factuurNummer: String?
    var btwBedrag: Decimal?
    var omschrijving: String?

    /// Raw extracted text (for debugging)
    var rawText: String

    /// Confidence score (0.0 - 1.0) for the overall extraction
    var confidence: Double

    /// Whether any useful data was extracted
    var hasData: Bool {
        bedrag != nil || datum != nil || leverancier != nil || factuurNummer != nil
    }
}

/// Service for OCR text recognition on receipts and invoices
final class OCRService {
    static let shared = OCRService()

    private init() {}

    // MARK: - Public Methods

    /// Extract data from any supported file type (PDF, PNG, JPEG, etc.)
    func extractData(from fileURL: URL) async throws -> OCRExtractedData {
        let ext = fileURL.pathExtension.lowercased()

        switch ext {
        case "pdf":
            return try await extractFromPDF(at: fileURL)
        case "png", "jpg", "jpeg", "tiff", "heic":
            return try await extractFromImage(at: fileURL)
        default:
            throw OCRError.unsupportedFormat
        }
    }

    // MARK: - Private Extraction Methods

    /// Extract data from an image file (PNG, JPEG, etc.)
    private func extractFromImage(at imageURL: URL) async throws -> OCRExtractedData {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }

        let text = try await recognizeText(in: cgImage)
        return parseExtractedText(text)
    }

    /// Extract data from a PDF file
    private func extractFromPDF(at pdfURL: URL) async throws -> OCRExtractedData {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw OCRError.invalidPDF
        }

        var allText = ""

        // Try to get embedded text first (faster and more accurate)
        for pageIndex in 0..<min(pdfDocument.pageCount, 3) { // Limit to first 3 pages
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                allText += pageText + "\n"
            }
        }

        // If no embedded text, use OCR on page images
        if allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            for pageIndex in 0..<min(pdfDocument.pageCount, 3) {
                if let page = pdfDocument.page(at: pageIndex) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0 // Higher resolution for OCR
                    let scaledRect = CGRect(x: 0, y: 0,
                                           width: pageRect.width * scale,
                                           height: pageRect.height * scale)

                    let image = page.thumbnail(of: scaledRect.size, for: .mediaBox)
                    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        if let pageText = try? await recognizeText(in: cgImage) {
                            allText += pageText + "\n"
                        }
                    }
                }
            }
        }

        guard !allText.isEmpty else {
            throw OCRError.noTextFound
        }

        return parseExtractedText(allText)
    }

    // MARK: - Private Methods

    /// Perform OCR on a CGImage
    private func recognizeText(in image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["nl-NL", "en-US"] // Dutch first, then English

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionError(error))
            }
        }
    }

    /// Parse extracted text to find relevant invoice/receipt data
    private func parseExtractedText(_ text: String) -> OCRExtractedData {
        let lines = text.components(separatedBy: .newlines)
        var confidence: Double = 0.0
        var fieldsFound = 0

        // Extract amount (look for currency patterns)
        let bedrag = extractAmount(from: text)
        if bedrag != nil { fieldsFound += 1 }

        // Extract date
        let datum = extractDate(from: text)
        if datum != nil { fieldsFound += 1 }

        // Extract supplier (usually first line or after common keywords)
        let leverancier = extractSupplier(from: lines)
        if leverancier != nil { fieldsFound += 1 }

        // Extract invoice number
        let factuurNummer = extractInvoiceNumber(from: text)
        if factuurNummer != nil { fieldsFound += 1 }

        // Extract BTW amount
        let btwBedrag = extractBTW(from: text)

        // Calculate confidence based on fields found
        confidence = Double(fieldsFound) / 4.0

        return OCRExtractedData(
            bedrag: bedrag,
            datum: datum,
            leverancier: leverancier,
            factuurNummer: factuurNummer,
            btwBedrag: btwBedrag,
            omschrijving: nil,
            rawText: text,
            confidence: confidence
        )
    }

    /// Extract monetary amount from text
    private func extractAmount(from text: String) -> Decimal? {
        // Common patterns for amounts in Dutch receipts
        let patterns = [
            // "Totaal: € 123,45" or "Totaal € 123.45"
            #"(?:totaal|total|te betalen|bedrag|amount)[:\s]*(?:€|EUR)?\s*(\d+[.,]\d{2})"#,
            // "€ 123,45" at end of line (likely total)
            #"€\s*(\d+[.,]\d{2})\s*$"#,
            // "123,45 EUR"
            #"(\d+[.,]\d{2})\s*(?:€|EUR)"#,
            // Large standalone amount (> 10)
            #"(?:€|EUR)\s*(\d{2,}[.,]\d{2})"#
        ]

        let lowercaseText = text.lowercased()

        for pattern in patterns {
            if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                .firstMatch(in: lowercaseText, range: NSRange(lowercaseText.startIndex..., in: lowercaseText)) {
                if let range = Range(match.range(at: 1), in: lowercaseText) {
                    let amountStr = String(lowercaseText[range])
                        .replacingOccurrences(of: ",", with: ".")
                    if let amount = Decimal(string: amountStr), amount > 0 {
                        return amount
                    }
                }
            }
        }

        return nil
    }

    /// Extract date from text
    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            // DD-MM-YYYY or DD/MM/YYYY
            (#"(\d{1,2})[/-](\d{1,2})[/-](\d{4})"#, "dd-MM-yyyy"),
            // DD-MM-YY
            (#"(\d{1,2})[/-](\d{1,2})[/-](\d{2})\b"#, "dd-MM-yy"),
            // YYYY-MM-DD
            (#"(\d{4})[/-](\d{1,2})[/-](\d{1,2})"#, "yyyy-MM-dd"),
            // "12 januari 2025" (Dutch month names)
            (#"(\d{1,2})\s+(januari|februari|maart|april|mei|juni|juli|augustus|september|oktober|november|december)\s+(\d{4})"#, "d MMMM yyyy")
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "nl_NL")

        for (pattern, format) in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let dateStr = String(text[range])
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateStr) {
                    // Sanity check: date should be reasonable (within last 2 years to next year)
                    let now = Date()
                    let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now)!
                    let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now)!
                    if date >= twoYearsAgo && date <= oneYearFromNow {
                        return date
                    }
                }
            }
        }

        return nil
    }

    /// Extract supplier name from lines
    private func extractSupplier(from lines: [String]) -> String? {
        // Skip empty lines and get first meaningful line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip if it looks like a date, amount, or invoice number
            if trimmed.isEmpty { continue }
            if trimmed.contains("€") || trimmed.contains("EUR") { continue }
            if trimmed.lowercased().contains("factuur") { continue }
            if trimmed.lowercased().contains("datum") { continue }
            if trimmed.range(of: #"^\d+[/-]\d+[/-]\d+"#, options: .regularExpression) != nil { continue }

            // Likely a company name if it's reasonably short and doesn't look like an address
            if trimmed.count >= 3 && trimmed.count <= 100 {
                // Clean up common suffixes
                return trimmed
            }
        }

        return nil
    }

    /// Extract invoice number from text
    private func extractInvoiceNumber(from text: String) -> String? {
        let patterns = [
            // "Factuurnummer: ABC-123" or "Factuur: ABC-123"
            #"(?:factuur(?:nummer)?|invoice(?:\s*(?:no|nr|number))?)[:\s]+([A-Z0-9][\w\-\/]+)"#,
            // "Bonnummer: 12345"
            #"(?:bon(?:nummer)?|receipt)[:\s]+(\d+)"#,
            // "Ref: ABC-123"
            #"(?:ref(?:erentie)?|reference)[:\s]+([A-Z0-9][\w\-\/]+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    /// Extract BTW (VAT) amount from text
    private func extractBTW(from text: String) -> Decimal? {
        let patterns = [
            #"(?:btw|vat|omzetbelasting)[:\s]*(?:€|EUR)?\s*(\d+[.,]\d{2})"#,
            #"(?:21%|9%)\s*(?:€|EUR)?\s*(\d+[.,]\d{2})"#
        ]

        let lowercaseText = text.lowercased()

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercaseText, range: NSRange(lowercaseText.startIndex..., in: lowercaseText)),
               let range = Range(match.range(at: 1), in: lowercaseText) {
                let amountStr = String(lowercaseText[range])
                    .replacingOccurrences(of: ",", with: ".")
                if let amount = Decimal(string: amountStr), amount > 0 {
                    return amount
                }
            }
        }

        return nil
    }
}

// MARK: - Errors
enum OCRError: LocalizedError {
    case invalidImage
    case invalidPDF
    case noTextFound
    case unsupportedFormat
    case visionError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Kon afbeelding niet laden"
        case .invalidPDF:
            return "Kon PDF niet laden"
        case .noTextFound:
            return "Geen tekst gevonden in document"
        case .unsupportedFormat:
            return "Bestandsformaat niet ondersteund"
        case .visionError(let error):
            return "OCR fout: \(error.localizedDescription)"
        }
    }
}
