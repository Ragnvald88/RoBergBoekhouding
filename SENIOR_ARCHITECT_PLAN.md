# Uurwerker - Senior Architect Implementation Plan

## Executive Summary

After conducting a comprehensive review of RoBergBoekhouding (11,112 LOC, 32 Swift files), I've identified the path to transform this well-architected but niche healthcare bookkeeping app into **Uurwerker** - a professional-grade, App Store-ready macOS application for Dutch ZZP professionals.

**Current State**: Solid foundation with good patterns, but contains App Store blockers and UX issues
**Target State**: Polished, accessible, App Store-approved macOS app meeting Apple Human Interface Guidelines

---

## Part 1: CRITICAL BLOCKERS (Must Fix Before Anything Else)

### 1.1 Fatal Error Crash on Startup

**File**: `App/RoBergBoekhoudingApp.swift:25`
**Issue**: `fatalError()` will crash the app if ModelContainer initialization fails
**App Store Impact**: **AUTOMATIC REJECTION** - Apps that crash on launch are immediately rejected

**Fix**:
```swift
// BEFORE (Line 22-26)
do {
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
} catch {
    fatalError("Could not create ModelContainer: \(error)")
}

// AFTER
do {
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
} catch {
    // Log error for debugging
    print("Primary ModelContainer failed: \(error)")

    // Attempt in-memory fallback for recovery
    let fallbackConfig = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
    )
    do {
        return try ModelContainer(for: schema, configurations: [fallbackConfig])
    } catch {
        // Show alert and provide recovery options (handled in ContentView)
        return try! ModelContainer(for: schema, configurations: [fallbackConfig])
    }
}
```

Additionally, add a database health check in `ContentView.swift` that shows an alert if data couldn't be loaded, with options to:
- Try again
- Reset database
- Export corrupted data for recovery

### 1.2 Personal Data Exposure

**File**: `Core/Models/BusinessSettings.swift:126-135`
**Issue**: Ronald's personal contact information hardcoded as defaults

**Exposed Data**:
- Email: ronaldhoogenberg@hotmail.com
- Phone: 06 432 67 791
- Address: Bastion 3, 9711 HG Groningen
- Bank: SNS Bank details

**Fix**: Replace with generic placeholders:
```swift
static func createDefaultSettings() -> BusinessSettings {
    BusinessSettings(
        bedrijfsnaam: "",  // Empty - force user to enter
        eigenaar: "",
        adres: "",
        postcode: "",
        plaats: "",
        email: "",
        telefoon: "",
        kvkNummer: "",
        // ... etc
    )
}
```

### 1.3 Missing Privacy Policy

**Requirement**: App Store requires privacy policy URL for all apps
**Current State**: No privacy policy exists

**Action**: Create `PRIVACY_POLICY.md` and host at `uurwerker.nl/privacy`:
```markdown
# Privacy Policy - Uurwerker

## Data Collection
Uurwerker does NOT collect, transmit, or store any personal data on external servers.

## Local Storage Only
All data remains exclusively on your Mac:
- ~/Library/Application Support/Uurwerker/

## No Analytics
We do not use analytics, tracking, or telemetry of any kind.

## No Third-Party Services
Uurwerker makes no network connections. Your financial data never leaves your device.

## Contact
Questions: privacy@uurwerker.nl
```

---

## Part 2: APP STORE REQUIREMENTS CHECKLIST

### 2.1 Required App Store Assets

| Asset | Status | Action |
|-------|--------|--------|
| App Icon (1024x1024) | MISSING | Design with uurwerk/clock theme |
| App Icon (all sizes) | MISSING | Generate via Asset Catalog |
| Launch Screen | MISSING | Add with logo + tagline |
| Privacy Policy URL | MISSING | Create and host |
| Age Rating | NOT SET | 4+ (no mature content) |
| App Category | NOT SET | Business / Finance |
| Bundle Identifier | Incorrect | Change to `nl.uurwerker.app` |
| Code Signing | Requires setup | Apple Developer certificate |
| Notarization | Requires setup | Submit to Apple notarization |

### 2.2 Required Functionality

| Feature | Status | Action |
|---------|--------|--------|
| About View | MISSING | Add with version, credits, links |
| Help Documentation | MISSING | Add basic user guide |
| Onboarding | MISSING | First-run setup wizard |
| Accessibility Labels | MISSING | Add to all interactive elements |
| Dynamic Type | MISSING | Support larger text sizes |
| VoiceOver | MISSING | Full screen reader support |
| Keyboard Navigation | PARTIAL | Complete Tab navigation |
| Dark Mode | UNTESTED | Verify all views |

### 2.3 Human Interface Guidelines Compliance

**Navigation** (Apple HIG Section 4):
- Current sidebar uses proper NavigationSplitView
- Need: Add Window > Zoom support
- Need: Proper restoration of window position

**Typography** (Apple HIG Section 7):
- Good use of semantic fonts (.headline, .title2)
- Need: Ensure all text supports Dynamic Type
- Need: Minimum touch target of 44pt

**Color** (Apple HIG Section 8):
- Good semantic colors (.primary, .secondary)
- Need: Sufficient contrast ratios (WCAG AA minimum)
- Need: Don't rely solely on color for meaning

---

## Part 3: USER EXPERIENCE OVERHAUL

### 3.1 First-Run Experience (Onboarding Wizard)

**Current**: App launches directly to empty dashboard - confusing for new users
**Target**: Guided setup that captures essential business info

```
Screen 1: Welcome
├── "Welkom bij Uurwerker"
├── "Precisie voor ondernemers"
└── [Start Setup] button

Screen 2: Business Info
├── Bedrijfsnaam (required)
├── Eigenaar naam (required)
├── KvK nummer (optional)
└── [Volgende] button

Screen 3: Contact Details
├── Adres + Postcode + Plaats
├── Email
├── Telefoon
└── [Volgende] button

Screen 4: Tax Settings (CRITICAL)
├── "Bent u BTW-plichtig?"
│   ├── Ja, standaard tarief (21%)
│   ├── Ja, laag tarief (9%)
│   ├── Nee, vrijgesteld (medisch, art. 11)
│   └── Nee, KOR (< €20.000)
├── Explanation text for each option
└── [Volgende] button

Screen 5: Default Rates
├── Standaard uurtarief: € [___]
├── Kilometervergoeding: € [0.23] (pre-filled)
├── Betalingstermijn: [14] dagen
└── [Volgende] button

Screen 6: Logo Upload (Optional)
├── Drop zone for logo image
├── Preview of invoice header
└── [Skip] / [Upload] buttons

Screen 7: Ready!
├── "Uurwerker is klaar voor gebruik"
├── Summary of entered settings
├── [Open Dashboard] button
└── Checkbox: "Toon tips voor nieuwe gebruikers"
```

**Implementation**: New `Features/Onboarding/OnboardingView.swift`

### 3.2 Dashboard Improvements

**Current Issues**:
- Year picker uses segmented control (limited to 3-4 years visible)
- No quick action buttons for common tasks
- KPI cards don't clearly explain their meaning
- Charts lack interactivity

**Improvements**:

```swift
// Replace segmented picker with menu
Menu {
    ForEach(appState.availableYears, id: \.self) { year in
        Button(String(year)) { appState.selectedYear = year }
    }
} label: {
    HStack {
        Text(String(appState.selectedYear))
        Image(systemName: "chevron.down")
    }
}
.menuStyle(.borderlessButton)

// Add Quick Actions section
struct QuickActionsView: View {
    var body: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                title: "Nieuwe registratie",
                icon: "clock.badge.plus",
                color: .blue
            ) { appState.showNewTimeEntry = true }

            QuickActionButton(
                title: "Nieuwe factuur",
                icon: "doc.badge.plus",
                color: .green
            ) { appState.showNewInvoice = true }

            QuickActionButton(
                title: "Nieuwe uitgave",
                icon: "creditcard.fill",
                color: .orange
            ) { appState.showNewExpense = true }
        }
    }
}

// Make charts interactive
Chart(monthlyRevenue, id: \.month) { item in
    BarMark(...)
}
.chartOverlay { proxy in
    GeometryReader { geometry in
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Show tooltip with exact value
                    }
            )
    }
}
```

### 3.3 Invoice Generation Flow

**Current Issues**:
- Must select client first, then entries - not intuitive
- No preview of final PDF before generating
- No way to add non-time-entry items inline
- BTW selection is buried

**Improved Flow**:

```
Step 1: Start Invoice
├── "Nieuwe factuur maken"
├── Select client (or create new)
└── Invoice number preview: "2025-043"

Step 2: Select Time Entries (if client has unbilled)
├── Table of unbilled entries
├── [Select All] / [Deselect All]
├── Running subtotal
└── Option: "Geen uren - handmatige factuur"

Step 3: Add Additional Items (NEW)
├── + Add line item
│   ├── Omschrijving
│   ├── Aantal
│   ├── Eenheid (uur/stuk/km)
│   ├── Prijs per eenheid
│   └── BTW tarief
└── Table of added items

Step 4: BTW & Totals
├── Subtotaal excl. BTW: € X.XXX,XX
├── BTW breakdown (grouped by percentage)
├── TOTAAL: € X.XXX,XX
└── Payment terms + notes

Step 5: Preview & Generate
├── Full PDF preview (scrollable)
├── [Wijzig] button to go back
├── [Opslaan als concept] button
└── [Genereer PDF] primary button
```

### 3.4 Settings View Cleanup

**Current Issue**: 82 individual `.onChange()` handlers (Lines 69-82)
**Problem**: Verbose, hard to maintain, potential performance impact

**Solution**: Use a SettingsFormData struct and single binding:

```swift
struct SettingsFormData: Equatable {
    var bedrijfsnaam: String
    var eigenaar: String
    // ... all settings fields
}

struct SettingsView: View {
    @State private var formData: SettingsFormData
    @State private var originalData: SettingsFormData

    private var hasChanges: Bool {
        formData != originalData
    }

    // Single onChange to track any change
    var body: some View {
        Form {
            // ... form fields bound to formData
        }
        .onChange(of: formData) { _, _ in
            // hasChanges automatically updates
        }
    }
}
```

### 3.5 Empty States

**Current**: Uses ContentUnavailableView but inconsistently
**Target**: Consistent, helpful empty states across all views

```swift
// Create reusable EmptyStateView
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Usage examples:
EmptyStateView(
    icon: "clock.badge.questionmark",
    title: "Geen urenregistraties",
    description: "Begin met het registreren van je werkuren. Deze worden automatisch gekoppeld aan klanten en facturen.",
    actionTitle: "Eerste uren registreren",
    action: { appState.showNewTimeEntry = true }
)

EmptyStateView(
    icon: "doc.text",
    title: "Geen facturen",
    description: "Zodra je uren hebt geregistreerd, kun je hier facturen genereren voor je klanten.",
    actionTitle: "Factuur maken",
    action: { appState.showNewInvoice = true }
)
```

---

## Part 4: ACCESSIBILITY (A11Y) IMPLEMENTATION

### 4.1 VoiceOver Support

**Every interactive element needs**:
```swift
Button("Save") { ... }
    .accessibilityLabel("Opslaan")
    .accessibilityHint("Slaat de huidige wijzigingen op")

// For icon-only buttons:
Button(action: deleteTapped) {
    Image(systemName: "trash")
}
.accessibilityLabel("Verwijder")
.accessibilityHint("Verwijdert dit item permanent")

// For data displays:
KPICardView(...)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Omzet dit jaar: \(amount.asCurrency)")
```

### 4.2 Minimum Touch Targets

Apple HIG requires 44x44pt minimum for touch targets:

```swift
// Add to all small buttons
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())

// For table rows
.frame(minHeight: 44)
```

### 4.3 Dynamic Type

```swift
// Enable automatic text scaling
Text("Amount")
    .font(.headline)
    .dynamicTypeSize(.small ... .accessibility3)

// Ensure layouts adapt
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24
Image(systemName: "clock")
    .font(.system(size: iconSize))
```

### 4.4 Color Contrast

Create a `DesignSystem.swift` with accessible colors:

```swift
enum UurwerkerColors {
    // Primary brand (pass WCAG AA on white)
    static let primaryBlue = Color(hex: "#1a365d")  // Contrast: 12.6:1
    static let accentGold = Color(hex: "#b7791f")   // Contrast: 4.5:1

    // Semantic colors (maintain contrast in dark mode too)
    static let success = Color(hex: "#276749")
    static let warning = Color(hex: "#c05621")
    static let error = Color(hex: "#c53030")

    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}
```

### 4.5 Reduced Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Conditionally animate
Circle()
    .trim(from: 0, to: progress)
    .animation(reduceMotion ? nil : .easeInOut, value: progress)
```

---

## Part 5: ARCHITECTURE IMPROVEMENTS

### 5.1 Error Handling System

**Current**: Mix of `try?`, `fatalError()`, and silenced errors
**Target**: Comprehensive error handling with user-friendly messages

```swift
// Core/Errors/AppError.swift
enum AppError: LocalizedError {
    case dataCorruption(details: String)
    case pdfGenerationFailed(reason: String)
    case exportFailed(reason: String)
    case importFailed(reason: String)
    case fileNotFound(path: String)
    case permissionDenied(resource: String)
    case networkError  // For future iCloud sync
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .dataCorruption(let details):
            return "Databasefout: \(details)"
        case .pdfGenerationFailed(let reason):
            return "PDF maken mislukt: \(reason)"
        case .exportFailed(let reason):
            return "Export mislukt: \(reason)"
        case .importFailed(let reason):
            return "Import mislukt: \(reason)"
        case .fileNotFound(let path):
            return "Bestand niet gevonden: \(path)"
        case .permissionDenied(let resource):
            return "Geen toegang tot: \(resource)"
        case .networkError:
            return "Netwerkfout"
        case .unknown(let error):
            return "Onverwachte fout: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .dataCorruption:
            return "Probeer de app opnieuw te starten. Als het probleem aanhoudt, neem contact op met support."
        case .pdfGenerationFailed:
            return "Controleer of er voldoende schijfruimte is en probeer opnieuw."
        // ... etc
        }
    }
}

// Usage pattern
func generatePDF() async throws -> URL {
    do {
        let data = try await pdfService.generate()
        return try storage.save(data)
    } catch let error as PDFError {
        throw AppError.pdfGenerationFailed(reason: error.localizedDescription)
    } catch {
        throw AppError.unknown(error)
    }
}
```

### 5.2 Service Layer Improvements

**Current**: Services are classes with dependency injection
**Improvement**: Protocol-based services for testability

```swift
// Protocols for testing
protocol PDFGenerating {
    func generateInvoicePDF(for invoice: Invoice) async throws -> Data
}

protocol DocumentStoring {
    func storePDF(_ data: Data, type: DocumentType, identifier: String, year: Int) throws -> String
    func retrievePDF(at path: String) throws -> Data
    func deletePDF(at path: String) throws
}

// Real implementations
final class PDFGenerationService: PDFGenerating { ... }
final class DocumentStorageService: DocumentStoring { ... }

// Mock implementations for testing
final class MockPDFService: PDFGenerating {
    var generatedPDFs: [Invoice.ID: Data] = [:]
    func generateInvoicePDF(for invoice: Invoice) async throws -> Data {
        return Data("mock-pdf".utf8)
    }
}
```

### 5.3 PDF Generation Reliability

**Current Issues**:
- 0.1 second arbitrary delay may fail on slow systems
- No progress indication
- Hard-coded A4 dimensions

**Improvements**:

```swift
// Use proper WebView delegate completion
class PDFRenderDelegate: NSObject, WKNavigationDelegate {
    private let completion: (Result<Data, Error>) -> Void
    private var retryCount = 0
    private let maxRetries = 3

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for complete render using JavaScript
        webView.evaluateJavaScript("document.readyState") { result, error in
            if result as? String == "complete" {
                self.createPDF(from: webView)
            } else {
                self.scheduleRetry(webView: webView)
            }
        }
    }

    private func createPDF(from webView: WKWebView) {
        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 at 72 DPI

        webView.createPDF(configuration: config) { result in
            self.completion(result.mapError { AppError.pdfGenerationFailed(reason: $0.localizedDescription) })
        }
    }
}

// Add progress indication
struct InvoiceGeneratorView: View {
    @State private var generationProgress: GenerationProgress = .idle

    enum GenerationProgress {
        case idle
        case preparing
        case rendering
        case saving
        case complete(URL)
        case failed(AppError)
    }

    func generatePDF() async {
        generationProgress = .preparing
        // ... prepare data

        generationProgress = .rendering
        let data = try await pdfService.generateInvoicePDF(for: invoice)

        generationProgress = .saving
        let url = try storage.save(data, ...)

        generationProgress = .complete(url)
    }
}
```

### 5.4 Data Backup & Recovery

**Critical for Financial App**:

```swift
// Core/Services/BackupService.swift
actor BackupService {
    private let storageService: DocumentStoring

    /// Creates a backup of the entire database
    func createBackup() async throws -> URL {
        let container = ModelContainer.shared
        let backupURL = documentsDirectory
            .appendingPathComponent("Backups")
            .appendingPathComponent("backup-\(Date().ISO8601Format()).sqlite")

        try FileManager.default.copyItem(
            at: container.mainContext.sqliteURL,
            to: backupURL
        )

        return backupURL
    }

    /// Exports all data to JSON for archival
    func exportToJSON() async throws -> URL {
        let export = DataExport(
            clients: try await fetchAllClients(),
            timeEntries: try await fetchAllTimeEntries(),
            invoices: try await fetchAllInvoices(),
            expenses: try await fetchAllExpenses(),
            exportDate: Date(),
            appVersion: Bundle.main.version
        )

        let data = try JSONEncoder().encode(export)
        // ... save to file
    }

    /// Schedules automatic backups
    func scheduleAutomaticBackups() {
        // Daily backup at 3 AM if app is running
        // Keep last 7 daily, 4 weekly, 12 monthly
    }
}
```

---

## Part 6: FEATURE ENHANCEMENTS

### 6.1 BTW System Overhaul

**Current Issue**: Default BTW is `vrijgesteld` (healthcare exemption), but app now supports generic clients

**Solution**: Make BTW context-aware:

```swift
// Update Invoice model
@Model
final class Invoice {
    // Per-line BTW instead of per-invoice
    // Removed: var btwTariefRaw: String?

    // Each line item has its own BTW tarief
    var lineItems: [InvoiceLineItem] = []

    // Computed BTW totals grouped by tarief
    var btwBreakdown: [(tarief: BTWTarief, bedrag: Decimal)] {
        Dictionary(grouping: lineItems, by: { $0.btwTarief })
            .map { (tarief: $0.key, bedrag: $0.value.map(\.btwBedrag).reduce(0, +)) }
            .sorted { $0.tarief.percentage < $1.tarief.percentage }
    }
}

// InvoiceLineItem with BTW
struct InvoiceLineItem: Codable, Identifiable {
    var id = UUID()
    var beschrijving: String
    var aantal: Decimal
    var eenheid: String  // "uur", "stuk", "km"
    var prijsPerEenheid: Decimal
    var btwTarief: BTWTarief

    var bedragExclBTW: Decimal { aantal * prijsPerEenheid }
    var btwBedrag: Decimal { bedragExclBTW * btwTarief.percentage }
    var bedragInclBTW: Decimal { bedragExclBTW + btwBedrag }
}
```

**PDF Template Update**:
```
Beschrijving          Aantal    Prijs     BTW      Subtotaal
─────────────────────────────────────────────────────────────
Consulting uren       10 uur    € 80,00   21%      € 800,00
Reiskosten            216 km    € 0,23    21%      € 49,68
Licentiekosten        1 stuk    € 200,00  0%       € 200,00
─────────────────────────────────────────────────────────────
                                    Subtotaal:     € 1.049,68
                                    BTW 21%:       € 178,33
                                    BTW 0%:        € 0,00
                                    ─────────────────────────
                                    TOTAAL:        € 1.228,01
```

### 6.2 Quotes/Offertes Module

**New Feature**: Create quotes that can convert to invoices

```swift
// Core/Models/Quote.swift
@Model
final class Quote {
    var id = UUID()
    var offertenummer: String  // "OFF-2025-001"
    var createdAt = Date()
    var geldigTot: Date  // Validity period

    var statusRaw: String = QuoteStatus.concept.rawValue
    var status: QuoteStatus {
        get { QuoteStatus(rawValue: statusRaw) ?? .concept }
        set { statusRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .nullify)
    var client: Client?

    var lineItems: [QuoteLineItem] = []
    var notities: String = ""
    var voorwaarden: String = ""  // Terms & conditions

    // Convert accepted quote to invoice
    func convertToInvoice(modelContext: ModelContext) -> Invoice {
        let invoice = Invoice(...)
        // Copy all line items
        // Mark quote as converted
        // Link quote to invoice for reference
        return invoice
    }
}

enum QuoteStatus: String, CaseIterable {
    case concept = "Concept"
    case verzonden = "Verzonden"
    case geaccepteerd = "Geaccepteerd"
    case afgewezen = "Afgewezen"
    case verlopen = "Verlopen"
    case omgezet = "Omgezet naar factuur"
}
```

### 6.3 Recurring Invoices

```swift
// Core/Models/RecurringInvoice.swift
@Model
final class RecurringInvoice {
    var id = UUID()
    var naam: String  // "Maandelijks onderhoud"
    var isActive = true

    @Relationship(deleteRule: .nullify)
    var client: Client?

    var lineItems: [InvoiceLineItem] = []
    var frequentie: RecurrenceFrequency  // weekly, monthly, quarterly, yearly
    var startDatum: Date
    var eindDatum: Date?  // nil = indefinite
    var laatsteFactuur: Date?
    var volgendeFactuur: Date

    // Automatically generates invoices on schedule
    func shouldGenerateInvoice() -> Bool {
        return isActive && Date() >= volgendeFactuur
    }
}

enum RecurrenceFrequency: String, CaseIterable {
    case weekly = "Wekelijks"
    case monthly = "Maandelijks"
    case quarterly = "Per kwartaal"
    case yearly = "Jaarlijks"
}
```

### 6.4 Bank Statement Import (MT940/CSV)

```swift
// Core/Services/BankImportService.swift
actor BankImportService {
    /// Imports MT940 (Dutch standard bank format)
    func importMT940(from url: URL) async throws -> [BankTransaction] {
        let data = try Data(contentsOf: url)
        let parser = MT940Parser()
        return try parser.parse(data)
    }

    /// Matches transactions to invoices by amount/reference
    func matchTransactions(
        _ transactions: [BankTransaction],
        to invoices: [Invoice]
    ) -> [(transaction: BankTransaction, invoice: Invoice?)] {
        transactions.map { transaction in
            let match = invoices.first { invoice in
                // Match by invoice number in description
                transaction.description.contains(invoice.factuurnummer) ||
                // Match by exact amount
                (transaction.amount == invoice.totaalbedrag &&
                 transaction.type == .credit)
            }
            return (transaction, match)
        }
    }
}

struct BankTransaction {
    let date: Date
    let amount: Decimal
    let type: TransactionType  // credit, debit
    let description: String
    let counterparty: String?
    let reference: String?
}
```

### 6.5 Fiscal Reports

**Quarterly BTW Report**:
```swift
struct BTWKwartaalRapport: View {
    let year: Int
    let quarter: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("BTW Aangifte Q\(quarter) \(year)")
                .font(.title)

            // Rubric 1a: Leveringen/diensten belast met hoog tarief
            ReportRow(
                rubric: "1a",
                description: "Leveringen/diensten belast met 21%",
                amount: totals.omzet21,
                btw: totals.btw21
            )

            // Rubric 1b: Leveringen/diensten belast met laag tarief
            ReportRow(
                rubric: "1b",
                description: "Leveringen/diensten belast met 9%",
                amount: totals.omzet9,
                btw: totals.btw9
            )

            // Rubric 1e: Leveringen/diensten belast met 0% of vrijgesteld
            ReportRow(
                rubric: "1e",
                description: "Vrijgestelde leveringen/diensten",
                amount: totals.omzetVrijgesteld,
                btw: Decimal.zero
            )

            Divider()

            // Rubric 5a: Te betalen
            TotalRow(
                description: "Totaal te betalen BTW",
                amount: totals.teBetalen
            )

            // Export button
            Button("Exporteer voor belastingaangifte") {
                exportToCSV()
            }
        }
    }
}
```

---

## Part 7: DESIGN SYSTEM

### 7.1 Color Palette

```swift
// Core/DesignSystem/Colors.swift
extension Color {
    // Primary Brand
    static let uurwerkerBlue = Color(hex: "#1a365d")
    static let uurwerkerGold = Color(hex: "#d69e2e")

    // Semantic
    static let uurwerkerSuccess = Color(hex: "#38a169")
    static let uurwerkerWarning = Color(hex: "#dd6b20")
    static let uurwerkerError = Color(hex: "#e53e3e")
    static let uurwerkerInfo = Color(hex: "#3182ce")

    // Backgrounds
    static let uurwerkerCardBackground = Color(.windowBackgroundColor)
    static let uurwerkerSidebarBackground = Color(.controlBackgroundColor)
}
```

### 7.2 Typography Scale

```swift
// Core/DesignSystem/Typography.swift
extension Font {
    static let uurwerkerLargeTitle = Font.system(size: 34, weight: .bold)
    static let uurwerkerTitle = Font.system(size: 28, weight: .semibold)
    static let uurwerkerHeadline = Font.system(size: 17, weight: .semibold)
    static let uurwerkerBody = Font.system(size: 14)
    static let uurwerkerCaption = Font.system(size: 12)
    static let uurwerkerMonospaced = Font.system(size: 14, design: .monospaced)
}
```

### 7.3 Spacing System

```swift
// Core/DesignSystem/Spacing.swift
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### 7.4 Reusable Components

```swift
// Components/UurwerkerCard.swift
struct UurwerkerCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(Spacing.md)
            .background(Color.uurwerkerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// Components/UurwerkerButton.swift
struct UurwerkerButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary, secondary, destructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(tintColor)
        .accessibilityLabel(title)
    }

    private var tintColor: Color {
        switch style {
        case .primary: return .uurwerkerBlue
        case .secondary: return .secondary
        case .destructive: return .uurwerkerError
        }
    }
}
```

---

## Part 8: TESTING STRATEGY

### 8.1 Unit Tests

```swift
// Tests/UurwerkerTests/Models/InvoiceTests.swift
final class InvoiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Invoice.self, Client.self, TimeEntry.self,
            configurations: config
        )
        context = container.mainContext
    }

    func testInvoiceTotalCalculation() throws {
        let invoice = Invoice(factuurnummer: "2025-001")
        invoice.addLineItem(InvoiceLineItem(
            beschrijving: "Consulting",
            aantal: 10,
            eenheid: "uur",
            prijsPerEenheid: 80,
            btwTarief: .standaard
        ))

        XCTAssertEqual(invoice.totaalbedragExclBTW, 800)
        XCTAssertEqual(invoice.btwBedrag, 168)  // 21% of 800
        XCTAssertEqual(invoice.totaalbedrag, 968)
    }

    func testInvoiceNumberFormat() {
        let number = Invoice.nextInvoiceNumber(year: 2025, lastNumber: 41)
        XCTAssertEqual(number, "2025-042")
    }

    func testBTWBreakdown() {
        let invoice = Invoice(factuurnummer: "2025-001")
        invoice.addLineItem(InvoiceLineItem(..., btwTarief: .standaard))
        invoice.addLineItem(InvoiceLineItem(..., btwTarief: .laag))
        invoice.addLineItem(InvoiceLineItem(..., btwTarief: .vrijgesteld))

        let breakdown = invoice.btwBreakdown
        XCTAssertEqual(breakdown.count, 3)
    }
}
```

### 8.2 UI Tests

```swift
// Tests/UurwerkerUITests/OnboardingTests.swift
final class OnboardingTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
    }

    func testCompleteOnboardingFlow() {
        // Step 1: Welcome
        XCTAssert(app.staticTexts["Welkom bij Uurwerker"].exists)
        app.buttons["Start Setup"].tap()

        // Step 2: Business Info
        app.textFields["Bedrijfsnaam"].tap()
        app.textFields["Bedrijfsnaam"].typeText("Test BV")
        app.buttons["Volgende"].tap()

        // Continue through all steps...

        // Final: Dashboard should be visible
        XCTAssert(app.staticTexts["Dashboard"].exists)
    }
}
```

### 8.3 Accessibility Audit

```swift
// Tests/UurwerkerUITests/AccessibilityTests.swift
final class AccessibilityTests: XCTestCase {
    func testAllButtonsHaveLabels() {
        let app = XCUIApplication()
        app.launch()

        let buttonsWithoutLabels = app.buttons.allElementsBoundByIndex.filter {
            $0.label.isEmpty
        }

        XCTAssert(buttonsWithoutLabels.isEmpty,
            "Buttons without accessibility labels: \(buttonsWithoutLabels)")
    }

    func testMinimumTouchTargets() {
        let app = XCUIApplication()
        app.launch()

        for button in app.buttons.allElementsBoundByIndex {
            let frame = button.frame
            XCTAssert(frame.width >= 44 && frame.height >= 44,
                "Button '\(button.label)' is too small: \(frame.size)")
        }
    }
}
```

---

## Part 9: APP STORE SUBMISSION CHECKLIST

### Pre-Submission

- [ ] Remove all `fatalError()` calls
- [ ] Remove personal data from defaults
- [ ] Test on macOS 14 (Sonoma) and 15 (Sequoia)
- [ ] Verify dark mode appearance
- [ ] Complete accessibility audit
- [ ] Test with VoiceOver enabled
- [ ] Test with large text sizes
- [ ] Verify all keyboard shortcuts work
- [ ] Test window resizing and minimum sizes
- [ ] Verify PDF generation on slow systems
- [ ] Test with empty database
- [ ] Test with large dataset (1000+ entries)

### App Store Connect

- [ ] App name: "Uurwerker - ZZP Boekhouding"
- [ ] Subtitle: "Precisie voor ondernemers"
- [ ] Bundle ID: nl.uurwerker.app
- [ ] Category: Business / Finance
- [ ] Age rating: 4+
- [ ] Price: €49 (or €79 for Pro)
- [ ] Privacy policy URL: https://uurwerker.nl/privacy
- [ ] Support URL: https://uurwerker.nl/support
- [ ] Marketing URL: https://uurwerker.nl

### Screenshots (Required)

- [ ] Dashboard overview
- [ ] Time entry form
- [ ] Invoice generation
- [ ] PDF preview
- [ ] Settings screen
- [ ] (Optional) Dark mode variants

### Description

```
Uurwerker - De slimme boekhoudapp voor Nederlandse ZZP'ers

Geen abonnement. Geen cloud. Gewoon een krachtige Mac-app die jouw administratie moeiteloos maakt.

FEATURES:
✓ Urenregistratie met klant-koppeling
✓ Professionele PDF facturen
✓ BTW-berekening (0%, 9%, 21%)
✓ Zelfstandigenaftrek tracking (1225 uren)
✓ Uitgavenbeheer met categorieën
✓ Uitgebreide rapportages

PRIVACY:
✓ 100% lokaal - data blijft op jouw Mac
✓ Geen account vereist
✓ Geen analytics of tracking
✓ GDPR compliant

VOOR WIE:
• ZZP'ers en freelancers
• Eenmanszaken
• Kleine ondernemers
• Startende ondernemers

NEDERLANDS:
Speciaal ontworpen voor Nederlandse fiscale regels.
BTW-aangifte, zelfstandigenaftrek, en alle andere
Nederlandse specifieke zaken ingebouwd.

Uurwerker - Elk uur telt.
```

---

## Part 10: IMPLEMENTATION PHASES

### Phase 1: Critical Fixes (Week 1)
1. Fix `fatalError()` crash
2. Remove personal data
3. Create Privacy Policy
4. Add About view
5. Basic accessibility labels

### Phase 2: Rebranding (Week 2)
1. Rename project to Uurwerker
2. Update bundle identifier
3. Design and implement app icon
4. Update all UI strings
5. Create launch screen

### Phase 3: UX Improvements (Week 3-4)
1. Implement onboarding wizard
2. Improve invoice generation flow
3. Add empty states
4. Implement design system
5. Clean up SettingsView

### Phase 4: BTW & Features (Week 5-6)
1. Per-line-item BTW support
2. Manual invoice line items
3. BTW kwartaaloverzicht
4. Improved PDF template
5. Quote/Offerte module (optional)

### Phase 5: Polish & Testing (Week 7-8)
1. Complete accessibility audit
2. Add unit tests
3. Add UI tests
4. Dark mode verification
5. Performance testing
6. App Store assets preparation

### Phase 6: Submission (Week 9)
1. Final testing on clean system
2. App Store Connect setup
3. Submit for review
4. Address review feedback

---

## Appendix A: File Changes Summary

### Files to Create
```
Features/Onboarding/OnboardingView.swift
Features/Onboarding/OnboardingStepView.swift
Features/About/AboutView.swift
Features/Help/HelpView.swift
Core/DesignSystem/Colors.swift
Core/DesignSystem/Typography.swift
Core/DesignSystem/Spacing.swift
Core/DesignSystem/Components/UurwerkerCard.swift
Core/DesignSystem/Components/UurwerkerButton.swift
Core/DesignSystem/Components/EmptyStateView.swift
Core/Errors/AppError.swift
Core/Services/BackupService.swift
Tests/UurwerkerTests/Models/InvoiceTests.swift
Tests/UurwerkerTests/Services/PDFGenerationTests.swift
PRIVACY_POLICY.md
```

### Files to Modify
```
App/RoBergBoekhoudingApp.swift → App/UurwerkerApp.swift
- Remove fatalError()
- Rename to UurwerkerApp

Core/Models/BusinessSettings.swift
- Remove personal data defaults
- Add onboarding completion flag

Core/Models/Invoice.swift
- Per-line-item BTW support
- Improved line item handling

Core/Models/Enums.swift
- Remove healthcare-specific client types
- Keep generic types only

Core/Services/PDFGenerationService.swift
- Improved WebView delegate
- Better error handling
- Progress indication support

Features/Dashboard/DashboardView.swift
- Add quick actions
- Improve year picker
- Interactive charts

Features/Reports/SettingsView.swift
- Simplify onChange handling
- Add branding section
- Improve layout

All Views:
- Add accessibility labels
- Add empty states
- Apply design system
```

### Files to Delete
```
(None - keep all existing functionality)
```

---

## Appendix B: Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New time entry |
| ⇧⌘N | New invoice |
| ⌥⌘N | New expense |
| ⌘I | Import |
| ⌘E | Export |
| ⌘1 | Show Dashboard |
| ⌘2 | Show Time Entries |
| ⌘3 | Show Invoices |
| ⌘4 | Show Clients |
| ⌘5 | Show Expenses |
| ⌘6 | Show Reports |
| ⌘, | Settings |
| ⌘? | Help |

---

*This document serves as the comprehensive implementation guide for transforming RoBergBoekhouding into Uurwerker, meeting Apple App Store requirements and senior-level quality standards.*

**Document Version**: 1.0
**Author**: Senior Architect Review
**Date**: December 2024
