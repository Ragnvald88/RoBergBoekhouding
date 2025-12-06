import Foundation
import AppKit
import PDFKit
import SwiftData
import WebKit
import os.log

/// Logger for PDF generation
private let pdfLogger = Logger(subsystem: "nl.uurwerker", category: "PDFGeneration")

/// Default timeout for PDF generation in seconds
private let pdfGenerationTimeout: TimeInterval = 30.0

// MARK: - PDF Generation Service

/// Service for generating PDF invoices
class PDFGenerationService {
    private let settings: BusinessSettings

    /// Container to hold WebView and delegate during async PDF generation
    /// This prevents premature deallocation
    private class PDFRenderContext {
        let webView: WKWebView
        let delegate: PDFWebViewDelegate
        var timeoutWorkItem: DispatchWorkItem?

        init(webView: WKWebView, delegate: PDFWebViewDelegate) {
            self.webView = webView
            self.delegate = delegate
        }

        func cancelTimeout() {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }
    }

    /// Active render contexts - keeps references alive during rendering
    private static var activeContexts: [UUID: PDFRenderContext] = [:]
    private static let contextLock = NSLock()

    init(settings: BusinessSettings) {
        self.settings = settings
    }

    // MARK: - Generate Invoice PDF (Async)

    /// Generate PDF data for an invoice asynchronously
    func generateInvoicePDF(for invoice: Invoice) async -> Data? {
        let html = generateInvoiceHTML(for: invoice)
        return await renderHTMLToPDFAsync(html)
    }

    /// Render HTML to PDF asynchronously using WKWebView
    /// Includes proper memory management and timeout handling
    private func renderHTMLToPDFAsync(_ html: String) async -> Data? {
        let contextId = UUID()
        pdfLogger.debug("Starting PDF render with context: \(contextId.uuidString)")

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var hasResumed = false
                let resumeLock = NSLock()

                // Thread-safe resume helper
                func safeResume(with data: Data?) {
                    resumeLock.lock()
                    defer { resumeLock.unlock() }

                    guard !hasResumed else {
                        pdfLogger.warning("Attempted to resume continuation twice for context: \(contextId.uuidString)")
                        return
                    }
                    hasResumed = true

                    // Clean up context
                    Self.contextLock.lock()
                    if let context = Self.activeContexts.removeValue(forKey: contextId) {
                        context.cancelTimeout()
                    }
                    Self.contextLock.unlock()

                    continuation.resume(returning: data)
                }

                let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842)) // A4 at 72 DPI

                // Use navigation delegate to wait for content to fully load
                let delegate = PDFWebViewDelegate { [weak webView] in
                    guard let webView = webView else {
                        pdfLogger.error("WebView was deallocated during PDF generation")
                        safeResume(with: nil)
                        return
                    }

                    let config = WKPDFConfiguration()
                    config.rect = NSRect(x: 0, y: 0, width: 595, height: 842)

                    webView.createPDF(configuration: config) { result in
                        switch result {
                        case .success(let data):
                            pdfLogger.debug("PDF generated successfully: \(data.count) bytes")
                            safeResume(with: data)
                        case .failure(let error):
                            pdfLogger.error("PDF generation error: \(error.localizedDescription)")
                            safeResume(with: nil)
                        }
                    }
                }

                webView.navigationDelegate = delegate

                // Store context to keep webView and delegate alive
                let context = PDFRenderContext(webView: webView, delegate: delegate)

                // Set up timeout
                let timeoutWorkItem = DispatchWorkItem {
                    pdfLogger.warning("PDF generation timed out after \(pdfGenerationTimeout) seconds")
                    safeResume(with: nil)
                }
                context.timeoutWorkItem = timeoutWorkItem
                DispatchQueue.main.asyncAfter(deadline: .now() + pdfGenerationTimeout, execute: timeoutWorkItem)

                // Store context
                Self.contextLock.lock()
                Self.activeContexts[contextId] = context
                Self.contextLock.unlock()

                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    /// Generate HTML for an invoice
    func generateInvoiceHTML(for invoice: Invoice) -> String {
        let brandColor = settings.primaryColor
        let hasBTW = invoice.hasBTW

        return """
        <!DOCTYPE html>
        <html lang="nl">
        <head>
            <meta charset="UTF-8">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 11pt;
                    line-height: 1.4;
                    color: #333;
                    padding: 40px;
                }
                .header {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 40px;
                }
                .logo {
                    font-size: 28pt;
                    font-weight: bold;
                    color: \(brandColor);
                }
                .subtitle {
                    font-size: 14pt;
                    color: #666;
                    margin-top: 4px;
                }
                .contact-info {
                    font-size: 10pt;
                    color: #666;
                    margin-top: 16px;
                    line-height: 1.6;
                }
                .invoice-meta {
                    text-align: right;
                }
                .invoice-title {
                    font-size: 24pt;
                    font-weight: bold;
                    color: #333;
                    margin-bottom: 16px;
                }
                .meta-table {
                    font-size: 10pt;
                }
                .meta-table td {
                    padding: 2px 0;
                }
                .meta-table td:first-child {
                    color: #666;
                    padding-right: 16px;
                }
                .address-block {
                    margin: 40px 0;
                    padding: 20px;
                    background: #f8f9fa;
                    border-radius: 8px;
                }
                .address-label {
                    font-size: 10pt;
                    color: #666;
                    margin-bottom: 8px;
                }
                .address-content {
                    font-size: 11pt;
                }
                .items-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 24px 0;
                }
                .items-table th {
                    background: #f1f5f9;
                    padding: 12px 8px;
                    text-align: left;
                    font-size: 10pt;
                    font-weight: 600;
                    color: #64748b;
                    border-bottom: 2px solid #e2e8f0;
                }
                .items-table th:last-child,
                .items-table td:last-child {
                    text-align: right;
                }
                .items-table th:nth-child(4),
                .items-table th:nth-child(5),
                .items-table td:nth-child(4),
                .items-table td:nth-child(5) {
                    text-align: right;
                }
                .items-table td {
                    padding: 10px 8px;
                    border-bottom: 1px solid #e2e8f0;
                    font-size: 10pt;
                }
                .items-table tr:last-child td {
                    border-bottom: none;
                }
                .totals {
                    margin-top: 24px;
                    margin-left: auto;
                    width: 300px;
                }
                .totals-row {
                    display: flex;
                    justify-content: space-between;
                    padding: 8px 0;
                    font-size: 11pt;
                }
                .totals-row.subtotal {
                    border-top: 1px solid #e2e8f0;
                    padding-top: 12px;
                }
                .totals-row.btw {
                    color: #666;
                }
                .totals-row.grand-total {
                    border-top: 2px solid #333;
                    padding-top: 12px;
                    font-size: 14pt;
                    font-weight: bold;
                }
                .footer {
                    margin-top: 60px;
                    padding-top: 20px;
                    border-top: 1px solid #e2e8f0;
                    font-size: 10pt;
                    color: #666;
                    line-height: 1.6;
                }
                .btw-note {
                    margin-top: 16px;
                    font-size: 9pt;
                    color: #94a3b8;
                    font-style: italic;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <div>
                    <div class="logo">\(settings.bedrijfsnaam.components(separatedBy: " ").first ?? settings.bedrijfsnaam)</div>
                    <div class="subtitle">\(settings.eigenaar)</div>
                    <div class="contact-info">
                        \(settings.adres)<br>
                        \(settings.postcodeplaats)<br><br>
                        Tel. \(settings.telefoon)<br>
                        Mail: \(settings.email)<br>
                        KvK: \(settings.kvkNummer)<br>
                        Bank: \(settings.bank)<br>
                        IBAN: \(settings.iban)
                    </div>
                </div>
                <div class="invoice-meta">
                    <div class="invoice-title">FACTUUR</div>
                    <table class="meta-table">
                        <tr><td>Factuurnummer:</td><td><strong>\(invoice.factuurnummer)</strong></td></tr>
                        <tr><td>Factuurdatum:</td><td>\(invoice.factuurdatumFormatted)</td></tr>
                        <tr><td>Vervaldatum:</td><td>\(invoice.vervaldatumFormatted)</td></tr>
                    </table>
                </div>
            </div>

            <div class="address-block">
                <div class="address-label">Factuuradres:</div>
                <div class="address-content">
                    \(generateClientAddress(invoice.client))
                </div>
            </div>

            <table class="items-table">
                <thead>
                    <tr>
                        <th>Datum</th>
                        <th>Omschrijving</th>
                        <th>Eenheid</th>
                        <th>Aantal</th>
                        <th>Tarief</th>
                        <th>Bedrag</th>
                    </tr>
                </thead>
                <tbody>
                    \(generateLineItemsHTML(invoice.lineItems))
                </tbody>
            </table>

            <div class="totals">
                \(generateTotalsHTML(for: invoice, hasBTW: hasBTW))
            </div>

            <div class="footer">
                \(settings.invoiceFooterText ?? settings.paymentInstruction)
                \(generateBTWNote(for: invoice))
            </div>
        </body>
        </html>
        """
    }

    /// Generate totals section HTML
    private func generateTotalsHTML(for invoice: Invoice, hasBTW: Bool) -> String {
        var html = ""

        // Subtotals
        if invoice.totaalUrenBedrag > 0 {
            html += """
            <div class="totals-row">
                <span>Totaal uren</span>
                <span>\(invoice.totaalUrenBedrag.asCurrency)</span>
            </div>
            """
        }

        if invoice.totaalKmBedrag > 0 {
            html += """
            <div class="totals-row">
                <span>Totaal kilometerkosten</span>
                <span>\(invoice.totaalKmBedrag.asCurrency)</span>
            </div>
            """
        }

        if invoice.subtotaalManualItems > 0 {
            html += """
            <div class="totals-row">
                <span>Overige posten</span>
                <span>\(invoice.subtotaalManualItems.asCurrency)</span>
            </div>
            """
        }

        // Subtotal excl BTW (only show if there's BTW)
        if hasBTW {
            html += """
            <div class="totals-row subtotal">
                <span>Subtotaal excl. BTW</span>
                <span>\(invoice.totaalbedragExclBTW.asCurrency)</span>
            </div>
            <div class="totals-row btw">
                <span>BTW \(invoice.btwTarief.percentageFormatted)</span>
                <span>\(invoice.btwBedragFormatted)</span>
            </div>
            """
        }

        // Grand total
        html += """
        <div class="totals-row grand-total">
            <span>TOTAAL\(hasBTW ? " incl. BTW" : "")</span>
            <span>\(invoice.totaalbedrag.asCurrency)</span>
        </div>
        """

        return html
    }

    /// Generate BTW note for footer
    private func generateBTWNote(for invoice: Invoice) -> String {
        if let legalText = invoice.btwTarief.legalText {
            return """
            <div class="btw-note">
                \(legalText)
            </div>
            """
        }
        return ""
    }

    private func generateClientAddress(_ client: Client?) -> String {
        guard let client = client else {
            return "Onbekende klant"
        }

        var lines: [String] = []
        if let contact = client.contactpersoon, !contact.isEmpty {
            lines.append(contact)
        }
        lines.append(client.bedrijfsnaam)
        lines.append(client.adres)
        lines.append(client.postcodeplaats)

        return lines.joined(separator: "<br>")
    }

    private func generateLineItemsHTML(_ items: [InvoiceLineItem]) -> String {
        items.map { item in
            """
            <tr>
                <td>\(item.datum)</td>
                <td>\(item.omschrijving)</td>
                <td>\(item.eenheid)</td>
                <td>\(item.aantal.asDecimal)</td>
                <td>\(item.tarief.asCurrency)</td>
                <td>\(item.bedrag.asCurrency)</td>
            </tr>
            """
        }.joined(separator: "\n")
    }

    // MARK: - Save Invoice PDF

    func saveInvoicePDF(for invoice: Invoice, to url: URL) async throws {
        guard let pdfData = await generateInvoicePDF(for: invoice) else {
            throw PDFError.generationFailed
        }
        try pdfData.write(to: url)
    }

    // MARK: - Generate and Store PDF

    /// Generate PDF and store it in the documents directory, updating the invoice's pdfPath
    /// - Parameters:
    ///   - invoice: The invoice to generate PDF for
    ///   - modelContext: SwiftData model context for saving
    /// - Returns: URL to the stored PDF
    @MainActor
    func generateAndStorePDF(for invoice: Invoice, modelContext: ModelContext) async throws -> URL {
        guard let pdfData = await generateInvoicePDF(for: invoice) else {
            throw PDFError.generationFailed
        }

        let year = Calendar.current.component(.year, from: invoice.factuurdatum)

        // Store the PDF
        let relativePath = try DocumentStorageService.shared.storePDF(
            pdfData,
            type: .invoice,
            identifier: invoice.factuurnummer,
            year: year,
            customBasePath: settings.dataDirectory
        )

        // Update the invoice record
        invoice.pdfPath = relativePath
        invoice.updateTimestamp()

        // Save changes
        try modelContext.save()

        // Return the full URL
        guard let url = DocumentStorageService.shared.url(for: relativePath, customBasePath: settings.dataDirectory) else {
            throw PDFError.saveFailed
        }

        return url
    }

    /// Generate PDF, store it, and also save to a user-selected location
    /// - Parameters:
    ///   - invoice: The invoice to generate PDF for
    ///   - userURL: The user-selected save location
    ///   - modelContext: SwiftData model context for saving
    /// - Returns: URL to the stored PDF in documents directory
    @MainActor
    func generateStoreAndExportPDF(for invoice: Invoice, to userURL: URL, modelContext: ModelContext) async throws -> URL {
        guard let pdfData = await generateInvoicePDF(for: invoice) else {
            throw PDFError.generationFailed
        }

        // Save to user-selected location
        try pdfData.write(to: userURL)

        // Also store in documents directory
        let year = Calendar.current.component(.year, from: invoice.factuurdatum)
        let relativePath = try DocumentStorageService.shared.storePDF(
            pdfData,
            type: .invoice,
            identifier: invoice.factuurnummer,
            year: year,
            customBasePath: settings.dataDirectory
        )

        // Update the invoice record
        invoice.pdfPath = relativePath
        invoice.updateTimestamp()

        // Save changes
        try modelContext.save()

        guard let url = DocumentStorageService.shared.url(for: relativePath, customBasePath: settings.dataDirectory) else {
            throw PDFError.saveFailed
        }

        return url
    }
}

// MARK: - PDF Errors
enum PDFError: LocalizedError {
    case generationFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Kon PDF niet genereren"
        case .saveFailed:
            return "Kon PDF niet opslaan"
        }
    }
}

// MARK: - WebView Navigation Delegate for PDF Generation

/// Helper delegate that waits for WebView to finish loading before triggering PDF generation
private class PDFWebViewDelegate: NSObject, WKNavigationDelegate {
    private let onLoadComplete: () -> Void
    private var hasCompleted = false
    private let completionLock = NSLock()

    init(onLoadComplete: @escaping () -> Void) {
        self.onLoadComplete = onLoadComplete
        super.init()
    }

    private func completeOnce() {
        completionLock.lock()
        defer { completionLock.unlock() }

        guard !hasCompleted else { return }
        hasCompleted = true

        // Small delay to ensure rendering is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.onLoadComplete()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pdfLogger.debug("WebView finished loading content")
        completeOnce()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pdfLogger.error("WebView navigation failed: \(error.localizedDescription)")
        completeOnce()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pdfLogger.error("WebView provisional navigation failed: \(error.localizedDescription)")
        completeOnce()
    }
}
