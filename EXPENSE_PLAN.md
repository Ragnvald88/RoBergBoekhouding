# Expense Management Enhancement Plan

## Research Summary

### Receipt OCR Best Practices
Based on research from [Bench Accounting](https://www.bench.co/blog/accounting/best-receipt-apps), [Dext](https://dext.com/us/blog/single/the-most-accurate-receipt-ocr-software), and [Klippa](https://www.klippa.com/en/blog/information/ocr-software-receipts/):

- Extract: merchant name, date, total amount, VAT
- Auto-categorize based on merchant recognition
- Leave uncertain fields blank for user correction
- Store original receipt image
- Use machine learning for improved accuracy over time

### Dutch Depreciation Rules (Afschrijving)
Based on research from [Dutch Tax Authorities](https://business.gov.nl/finance-and-taxes/business-taxes/filing-tax-returns/deducting-costs-from-your-tax-return-amortisation/), [TaxSavers](https://taxsavers.nl/self-employed-tax-return/investments-depreciation-costs/), and [PWC Tax Summaries](https://taxsummaries.pwc.com/netherlands/corporate/deductions):

| Rule | Value |
|------|-------|
| **Threshold** | < €450 = direct deduction, ≥ €450 = depreciation |
| **Max annual rate** | 20% (5-year minimum depreciation) |
| **Method** | Linear: (purchase - residual) / years |
| **Residual value** | Typically 10% of purchase price |
| **Start date** | From date asset comes into use |

---

## Implementation Plan

### Phase 1: New Asset Model (Depreciation Support)

#### 1.1 Create Asset Model
```swift
@Model
final class Asset {
    var id: UUID
    var naam: String                      // "MacBook Pro 16"
    var omschrijving: String?             // Additional details
    var aanschafdatum: Date               // Purchase date
    var inGebruikDatum: Date              // Date put into use
    var aanschafwaarde: Decimal           // Purchase price (excl. BTW)
    var restwaarde: Decimal               // Residual value (typically 10%)
    var afschrijvingsjaren: Int           // Depreciation years (min 5)
    var categorieRaw: String              // Asset category
    var leverancier: String?
    var documentPath: String?             // Receipt/invoice
    var zakelijkPercentage: Decimal       // Business use %
    var isActief: Bool                    // Still in use
    var verkoopDatum: Date?               // Date sold/disposed
    var verkoopWaarde: Decimal?           // Sale value if sold
    var notities: String?

    // Computed properties
    var jaarlijkseAfschrijving: Decimal   // Annual depreciation amount
    var boekwaarde: Decimal               // Current book value
    var afschrijvingTotDatum: Decimal     // Depreciation to date
}
```

#### 1.2 Asset Categories
```swift
enum AssetCategory: String, CaseIterable {
    case computer = "Computer/Laptop"
    case telefoon = "Telefoon/Tablet"
    case kantoorinventaris = "Kantoorinventaris"
    case medischeApparatuur = "Medische apparatuur"
    case vervoermiddel = "Vervoermiddel"
    case software = "Software licenties"
    case overig = "Overige bedrijfsmiddelen"
}
```

### Phase 2: Enhanced Expense Model

#### 2.1 Update Expense Model
Add fields:
```swift
var isInvestering: Bool                   // Is this a depreciable asset?
var btwBedrag: Decimal?                   // VAT amount if applicable
var btwTarief: BTWTarief?                 // VAT rate
var factuurNummer: String?                // Supplier invoice number
var ocrVertrouwen: Double?                // OCR confidence score (0-1)
var asset: Asset?                         // Link to Asset if depreciated
```

#### 2.2 Smart Expense Detection
When expense ≥ €450:
- Prompt user: "Dit bedrag komt in aanmerking voor afschrijving. Wil je dit als bedrijfsmiddel registreren?"
- If yes → Create Asset linked to Expense
- If no → Regular expense (user's choice)

### Phase 3: Receipt OCR with Vision Framework

#### 3.1 OCR Service
```swift
class ReceiptOCRService {
    // Use macOS Vision framework for text recognition
    func scanReceipt(from url: URL) async -> ScannedReceiptData

    struct ScannedReceiptData {
        var merchantName: String?
        var date: Date?
        var totalAmount: Decimal?
        var btwAmount: Decimal?
        var items: [LineItem]?
        var confidence: Double           // Overall confidence score
        var rawText: String              // Full extracted text
    }
}
```

#### 3.2 Data Extraction Patterns
Detect common Dutch receipt patterns:
- Date: `dd-mm-yyyy`, `dd/mm/yyyy`, `dd.mm.yyyy`
- Amount: `€ 123,45`, `EUR 123.45`, `Totaal: 123,45`
- BTW: `BTW 21%`, `9% BTW`, `BTW €12,34`
- Invoice number: `Factuurnummer:`, `Factuur nr.`, `Invoice #`

#### 3.3 Merchant Recognition
Build simple merchant → category mapping:
```swift
let merchantCategories: [String: ExpenseCategory] = [
    "bol.com": .kleineAankopen,
    "coolblue": .kleineAankopen,
    "kpn": .telefoonInternet,
    "vodafone": .telefoonInternet,
    "ns.nl": .reiskosten,
    "shell": .reiskosten,
    "albert heijn": .representatie,
    // etc.
]
```

### Phase 4: Enhanced UI

#### 4.1 Expense Form Improvements
Current flow:
1. User clicks "Nieuwe uitgave"
2. Empty form appears

New flow:
1. User clicks "Nieuwe uitgave"
2. Option appears: "Bonnetje uploaden" or "Handmatig invoeren"
3. If upload:
   - Scan receipt with OCR
   - Pre-fill detected fields
   - Highlight uncertain fields (yellow border)
   - Show confidence indicator
4. User reviews and corrects
5. If amount ≥ €450: "Afschrijven?" toggle appears

#### 4.2 Asset Form (for depreciation)
Fields:
- Naam (required)
- Aanschafdatum
- In gebruik datum
- Aanschafwaarde (excl. BTW)
- BTW bedrag
- Restwaarde (default 10%)
- Afschrijvingsjaren (default 5, min 5)
- Zakelijk percentage
- Categorie
- Leverancier
- Bonnetje/factuur upload

#### 4.3 Expense List View Improvements
- Section headers by month (like TimeEntryListView)
- Visual distinction for:
  - Regular expenses (normal)
  - Depreciable assets (with depreciation badge)
  - Recurring expenses (repeat icon)
- Filter by: category, asset/expense, recurring

#### 4.4 Asset Overview Section
New section in Rapportages or separate sidebar item:
- List of all assets
- Per asset: boekwaarde, jaarlijkse afschrijving, remaining years
- Total depreciation per year
- Assets due for disposal (fully depreciated)

### Phase 5: Reporting Integration

#### 5.1 Annual Report Updates
Add sections:
- **Afschrijvingen**: Total depreciation for year
- **Investeringen**: New assets purchased this year
- **Boekwaarde activa**: Total book value of all assets

#### 5.2 Dashboard Updates
Add KPI for:
- Total depreciation this year
- Upcoming large depreciation items

---

## File Changes Required

### New Files
1. `Asset.swift` - New model
2. `AssetCategory.swift` - Enum (or add to Enums.swift)
3. `ReceiptOCRService.swift` - Vision-based OCR
4. `AssetFormView.swift` - Asset creation/editing
5. `AssetListView.swift` - Asset overview

### Modified Files
1. `Expense.swift` - Add depreciation link fields
2. `ExpenseFormView.swift` - Add OCR, depreciation toggle
3. `ExpenseListView.swift` - Improve grouping, add asset display
4. `Enums.swift` - Add AssetCategory
5. `DashboardView.swift` - Add depreciation KPI
6. `AnnualReportView.swift` - Add depreciation section
7. `BackupService.swift` - Include Asset in backups

### No Changes Needed
- Invoice system (expenses don't generate invoices)
- TimeEntry system (unrelated)
- Client system (unrelated)

---

## Implementation Order

1. **Asset Model** - Foundation for depreciation
2. **Update Expense Model** - Link expenses to assets
3. **Asset Form UI** - Create/edit assets
4. **Expense Form Updates** - Depreciation toggle
5. **OCR Service** - Receipt scanning
6. **Expense Form OCR** - Integration
7. **Asset List View** - Overview of assets
8. **Reporting** - Depreciation in reports
9. **Dashboard** - Depreciation KPIs

---

## Technical Notes

### macOS Vision Framework for OCR
```swift
import Vision

func recognizeText(in image: CGImage) async throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["nl-NL", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}
```

### Depreciation Calculation
```swift
extension Asset {
    /// Annual depreciation amount
    var jaarlijkseAfschrijving: Decimal {
        let afschrijfbaar = aanschafwaarde - restwaarde
        return (afschrijfbaar / Decimal(afschrijvingsjaren)) * (zakelijkPercentage / 100)
    }

    /// Current book value
    var boekwaarde: Decimal {
        let years = yearsInUse
        let totalDepreciation = min(jaarlijkseAfschrijving * Decimal(years), aanschafwaarde - restwaarde)
        return aanschafwaarde - totalDepreciation
    }

    /// Years asset has been in use
    var yearsInUse: Int {
        let calendar = Calendar.current
        let now = verkoopDatum ?? Date()
        return calendar.dateComponents([.year], from: inGebruikDatum, to: now).year ?? 0
    }
}
```

---

## User Stories

1. **As a ZZP'er, I want to upload a receipt and have the app auto-fill expense details** so I don't have to type everything manually.

2. **As a ZZP'er, I want the app to recognize when a purchase qualifies for depreciation** so I don't miss tax benefits.

3. **As a ZZP'er, I want to see my total depreciation per year** so I can accurately report costs on my tax return.

4. **As a ZZP'er, I want to track the book value of my business assets** so I know the current value of my inventory.

5. **As a ZZP'er, I want uncertain OCR fields left blank** so I can verify and fill in correct values myself.

---

## Estimated Effort

| Phase | Complexity | Files |
|-------|------------|-------|
| 1. Asset Model | Low | 2 |
| 2. Expense Updates | Low | 2 |
| 3. OCR Service | Medium | 1 |
| 4. UI Forms | Medium | 3 |
| 5. Reporting | Low | 2 |

Total: ~10 files, medium overall complexity.
