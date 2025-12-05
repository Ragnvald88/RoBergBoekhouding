# Uurwerker - Claude Code Guide

## Project Overview

Native macOS bookkeeping application for a self-employed GP (huisartswaarnemer) in the Netherlands. Tracks working hours, generates invoices, manages expenses, and provides financial reports.

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData (Apple's ORM, SQLite-based)
- **PDF Generation**: WebKit (WKWebView HTML-to-PDF)
- **PDF Reading**: PDFKit
- **Platform**: macOS 14+ (Sonoma)
- **IDE**: Xcode 15+

## Project Structure

```
Uurwerker/
├── App/                           # Application entry and state
│   ├── UurwerkerApp.swift         # Main app, SwiftData container setup
│   ├── AppState.swift             # Global @Published state
│   └── ContentView.swift          # Root navigation (sidebar + detail)
├── Core/
│   ├── Models/                    # SwiftData @Model classes
│   │   ├── Client.swift           # Customer data
│   │   ├── TimeEntry.swift        # Hour/km registration
│   │   ├── Invoice.swift          # Invoice with line items
│   │   ├── Expense.swift          # Business expenses
│   │   ├── BusinessSettings.swift # App configuration
│   │   └── Enums.swift            # Shared enumerations
│   ├── Services/                  # Business logic
│   │   ├── PDFGenerationService.swift    # HTML-to-PDF invoice generation
│   │   ├── PDFInvoiceImportService.swift # Parse and import PDF invoices
│   │   ├── CSVImportService.swift        # Import clients from CSV
│   │   ├── ExportService.swift           # Export reports
│   │   └── DocumentStorageService.swift  # Centralized PDF/document storage
│   └── Utilities/
│       └── DutchFormatters.swift  # nl_NL locale formatting
├── Features/                      # Feature modules
│   ├── Dashboard/
│   │   ├── DashboardView.swift    # KPIs, charts, overview
│   │   └── KPICardView.swift      # Reusable KPI display
│   ├── TimeTracking/
│   │   ├── TimeEntryListView.swift
│   │   ├── TimeEntryFormView.swift
│   │   └── WeekOverviewView.swift
│   ├── Invoicing/
│   │   ├── InvoiceListView.swift
│   │   ├── InvoiceGeneratorView.swift
│   │   └── InvoicePreviewView.swift
│   ├── Clients/
│   │   ├── ClientListView.swift
│   │   └── ClientFormView.swift
│   ├── Expenses/
│   │   ├── ExpenseListView.swift
│   │   └── ExpenseFormView.swift
│   ├── Reports/
│   │   ├── ReportsView.swift
│   │   ├── AnnualReportView.swift
│   │   ├── SettingsView.swift
│   │   └── ImportView.swift
│   └── Shared/
│       └── PDFViewerView.swift    # Native PDF viewer component
└── Resources/
    └── Assets.xcassets
```

## Architecture Patterns

### SwiftData Models
All data models use `@Model` macro:
```swift
@Model
final class Invoice {
    var id: UUID
    var factuurnummer: String
    var pdfPath: String?           // Path to generated PDF
    var importedPdfPath: String?   // Path to original imported PDF

    @Relationship(deleteRule: .nullify)
    var client: Client?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.invoice)
    var timeEntries: [TimeEntry]? = []
}
```

### State Management
- **AppState**: Global @StateObject in App, passed via @EnvironmentObject
- **@Query**: SwiftUI macro for reactive database queries
- **@Environment(\.modelContext)**: For database operations

### View Pattern
```swift
struct FeatureView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var items: [Model]

    var body: some View { ... }
}
```

### Service Pattern
Services take dependencies via initializer:
```swift
class PDFGenerationService {
    private let settings: BusinessSettings
    init(settings: BusinessSettings) { self.settings = settings }
}
```

## Key Conventions

### Naming
- Dutch for domain terms: `factuurnummer`, `bedrijfsnaam`, `uurtarief`, `klant`
- English for technical terms: `isInvoiced`, `createdAt`, `totalAmount`
- Models: singular (`Client`, `Invoice`, `TimeEntry`)
- Views: `*View`, `*FormView`, `*ListView`
- Services: `*Service`

### Data Types
- Money: `Decimal` (not Double, for financial precision)
- Dates: `Date` with Dutch formatting (dd-MM-yyyy)
- IDs: `UUID`
- Enums: Store as String via `*Raw` pattern for SwiftData compatibility

### Formatting
Use `DutchFormatters` extensions:
```swift
let amount: Decimal = 1234.50
amount.asCurrency  // "€ 1.234,50"
amount.asDecimal   // "1.234,50"
```

## Common Tasks

### Add a new model property
1. Add property to model class with default value
2. Update initializer if needed
3. SwiftData handles schema migration automatically

### Add a new view
1. Create in appropriate Features folder
2. Add @Query for data, @Environment for context
3. Register in ContentView navigation if main section

### Add a service
1. Create in Core/Services/
2. Initialize with required dependencies (settings, modelContext)
3. Use async/await for long operations

### Generate and store PDF
```swift
let service = PDFGenerationService(settings: businessSettings)
let url = try await service.generateAndStorePDF(for: invoice, modelContext: modelContext)
// invoice.pdfPath is automatically updated
```

### Store a document
```swift
let path = try DocumentStorageService.shared.storePDF(
    pdfData,
    type: .invoice,  // or .expense, .importedPDF
    identifier: invoice.factuurnummer,
    year: 2025
)
```

### Open stored PDF
```swift
if let url = invoice.pdfURL() {
    NSWorkspace.shared.open(url)
}
```

## File Paths

Default document storage location:
```
~/Library/Application Support/Uurwerker/Documents/
├── Invoices/{year}/{invoice_number}.pdf    # Generated invoices
├── Expenses/{year}/{expense_id}.pdf        # Receipt scans
└── Imports/{year}/{invoice_number}.pdf     # Imported PDF invoices
```

Configurable via `BusinessSettings.dataDirectory` in Settings.

## Key Models

### Client
- `bedrijfsnaam`: Business name (required)
- `clientType`: dagpraktijk (€70/hr), anwDienst (€124/hr), administratie
- `afstandRetour`: Return distance in km
- `standaardUurtarief`, `standaardKmTarief`: Default rates

### TimeEntry
- `datum`: Work date
- `uren`: Hours worked (Decimal)
- `isBillable`: Admin/training entries are non-billable
- `isInvoiced`: Linked to invoice
- `retourafstandWoonWerk`: Return km
- `visiteKilometers`: Additional visit km

### Invoice
- `factuurnummer`: Format YYYY-NNN (e.g., 2025-042)
- `status`: concept, verzonden, betaald, herinnering, oninbaar
- `pdfPath`: Path to generated PDF (relative to documents directory)
- `importedPdfPath`: Path to imported original PDF

### Expense
- `categorieRaw`: Dutch expense categories
- `zakelijkPercentage`: Business percentage (for mixed use)
- `documentPath`: Receipt PDF path

## Testing

No test suite currently exists. When adding tests:
```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Client.self, TimeEntry.self, ..., configurations: config)
// Use container.mainContext for testing
```

## Build & Run

```bash
# Open in Xcode
open Uurwerker.xcodeproj

# Build from command line
xcodebuild -project Uurwerker.xcodeproj -scheme Uurwerker build

# Run
xcodebuild -project Uurwerker.xcodeproj -scheme Uurwerker -destination 'platform=macOS' run
```

## Business Rules

- All prices exclude BTW (healthcare VAT exemption per article 11-1-g)
- Invoice numbers: `YYYY-NNN` format, auto-incrementing per year
- Default hourly rates: €70 (dagpraktijk), €124 (ANW emergency)
- Default km rate: €0.23/km
- Payment term: 14 days
- Zelfstandigenaftrek threshold: 1225 hours/year minimum (ALL hours count, not just billable)

## Input Validation

Models validate input in their initializers:
- **TimeEntry**: `uren >= 0`, `retourafstandWoonWerk >= 0`, `visiteKilometers >= 0`, rates >= 0
- **Expense**: `bedrag >= 0`, `zakelijkPercentage` clamped to 0-100%

## Invoice Status

Invoice statuses: `concept`, `verzonden`, `betaald`, `herinnering`, `oninbaar`

Users can change between any status using `InvoiceStatus.otherStatuses` (shows all statuses except current).

## PDF Generation

PDF generation uses WKWebView with proper load detection:
```swift
// PDFGenerationService uses WKNavigationDelegate to wait for HTML to fully load
// before generating PDF, avoiding blank pages on slow systems
let service = PDFGenerationService(settings: businessSettings)
let pdfData = await service.generateInvoicePDF(for: invoice)
```

## Multi-Select Support

InvoiceListView supports multi-select for bulk operations:
- Shift+Click or Cmd+Click to select multiple invoices
- Bulk delete available when multiple selected
- Selection uses `Set<Invoice.ID>` pattern

## UI Layout Notes

All list views (InvoiceListView, ClientListView, ExpenseListView, TimeEntryListView) use:
- `.frame(maxWidth: .infinity, maxHeight: .infinity)` on List/Table components
- Proper frame constraints on HSplitView panels
- This prevents layout issues where lists don't render correctly initially

## Deleting Records

### Time Entries
- Select entries in the table (click or Shift+Click for multiple)
- Use toolbar delete button or right-click context menu
- Supports bulk delete of multiple selected entries

### Invoices
- Select invoices in the list (Cmd+Click for multiple)
- Use context menu "Verwijderen" or detail view "Acties" menu
- Deleting an invoice also:
  - Deletes associated PDF files
  - Unlinks time entries (marks them as not invoiced)
