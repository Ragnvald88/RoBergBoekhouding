# Uurwerker - Next Level Plan

## Expert Team Analyse

Dit plan is opgesteld door een virtueel team van 4 experts:
- **Emma** - Brand & Naming Specialist
- **Thomas** - Product/UX Expert
- **Sophie** - Technical/App Store Expert
- **Lars** - Business/Market Analyst

---

## 1. NAAM & BRANDING (Emma)

### Gekozen naam: **Uurwerker**

De naam "Uurwerker" is gekozen na uitgebreide analyse:

| Criterium | Score |
|-----------|-------|
| Origineel en niet in gebruik | ✅ Geen bestaande app gevonden |
| Makkelijk uit te spreken | ✅ 100% Nederlands |
| Memorabel | ✅ Slim woordspel |
| Relevant voor ZZP/boekhouding | ✅ Directe link naar werk en uren |
| Beschikbaar als App Store naam | ✅ Beschikbaar |
| Maximaal 12 karakters | ✅ 9 karakters |

### Waarom Uurwerker perfect is:

- **Dubbele betekenis**:
  - "Uur" + "werker" = Iemand die uren werkt/registreert
  - Klinkt als "uurwerk" = precisie, betrouwbaarheid, timing
- **Associaties**:
  - Precisie van een Zwitsers uurwerk
  - Hardwerkende ZZP'er
  - Tijdregistratie als kernfunctie
- **Professioneel maar toegankelijk**
- **Domein**: uurwerker.nl is een fysieke locatie (Groningen), geen app-conflict

### Branding

- **Tagline**: "Uurwerker - Precisie voor ondernemers"
- **Alternatieve taglines**:
  - "Uurwerker - Jouw tijd, jouw geld"
  - "Uurwerker - Elk uur telt"
- **Kleuren**: Donkerblauw (#1a365d) + Goud/amber accent (#d69e2e)
  - Blauw: Vertrouwen, professionaliteit
  - Goud: Waarde, kwaliteit, precisie (kleur van horlogewijzers)
- **Icon concept**: Gestileerde klok/tandwiel combinatie met moderne uitstraling

---

## 2. PRODUCT VISIE (Thomas)

### Huidige staat vs. Gewenste staat

```
HUIDIGE APP (RoBergBoekhouding)     GEWENSTE APP (Uurwerker)
├── Urenregistratie (GP-specifiek)  ├── Universele tijdregistratie
├── Facturen (basis)                ├── Professionele facturatie
├── Klanten                         ├── Klant & Project management
├── Uitgaven                        ├── Uitgaven met BTW-categorieën
└── Rapporten (beperkt)             ├── Fiscale rapportages
                                    ├── BTW-aangifte ondersteuning
                                    ├── Offertes/Quotes
                                    └── Dashboard met KPI's
```

### Kernprincipes

1. **Privacy First** - Alle data blijft lokaal op de Mac
2. **Offline First** - Werkt zonder internet
3. **One-Time Purchase** - Geen abonnement
4. **Dutch Native** - Specifiek voor Nederlandse wetgeving
5. **Simple by Default, Powerful When Needed**

### Feature Roadmap

#### Fase 1: Universele ZZP Basis (MVP)
- [ ] Generieke branche-ondersteuning (niet alleen zorg)
- [ ] BTW-tarieven (0%, 9%, 21%)
- [ ] Kleineondernemersregeling (KOR) ondersteuning
- [ ] Meerdere facturatiemodellen (uur, vast bedrag, product)
- [ ] Professionele factuursjablonen
- [ ] Logo upload en customization

#### Fase 2: Fiscale Compliance
- [ ] Zelfstandigenaftrek tracking (1225 uren)
- [ ] Startersaftrek ondersteuning
- [ ] BTW-kwartaaloverzicht
- [ ] Jaaroverzicht voor belastingaangifte
- [ ] Winst & Verlies rekening
- [ ] Balans overzicht

#### Fase 3: Professionele Features
- [ ] Offertes/Quotes maken
- [ ] Creditnota's
- [ ] Herinneringen voor betalingen
- [ ] Recurring invoices
- [ ] Meerdere bedrijfsprofielen
- [ ] Projecten met budgetten

#### Fase 4: Integraties
- [ ] Bank statement import (MT940/CSV)
- [ ] iCloud backup/sync
- [ ] Export naar accountant (compatible formaat)
- [ ] Kalender integratie voor deadlines

---

## 3. TECHNISCHE REQUIREMENTS (Sophie)

### App Store Vereisten Checklist

#### Verplicht voor goedkeuring:
- [ ] **Privacy Policy** - URL naar privacy beleid
- [ ] **App Icon** - Alle vereiste formaten (16x16 tot 1024x1024)
- [ ] **Launch Screen** - Professionele splash screen
- [ ] **About/Help sectie** - App info en documentatie
- [ ] **Sandboxing** - Proper file access entitlements
- [ ] **Code Signing** - Developer ID certificaat
- [ ] **Notarization** - Apple notarization voor distributie
- [ ] **Age Rating** - 4+ (geen mature content)
- [ ] **Accessibility** - VoiceOver support
- [ ] **Human Interface Guidelines** - Native macOS look & feel

#### Technische verbeteringen:

```swift
// VEREIST: Proper error handling pattern
enum AppError: LocalizedError {
    case dataCorruption
    case exportFailed(reason: String)
    case importFailed(reason: String)
    case pdfGenerationFailed

    var errorDescription: String? {
        switch self {
        case .dataCorruption:
            return "Er is een probleem met de gegevens"
        case .exportFailed(let reason):
            return "Export mislukt: \(reason)"
        // etc.
        }
    }
}
```

```swift
// VEREIST: Accessibility labels
Image(systemName: "doc.fill")
    .accessibilityLabel("PDF document")
    .accessibilityHint("Tik om te openen")
```

### Architectuur Updates

```
Uurwerker/
├── App/
│   ├── UurwerkerApp.swift        // Renamed entry point
│   ├── AppState.swift
│   └── ContentView.swift
├── Core/
│   ├── Models/
│   │   ├── Client.swift
│   │   ├── Project.swift         // NEW: Project support
│   │   ├── TimeEntry.swift
│   │   ├── Invoice.swift
│   │   ├── Quote.swift           // NEW: Offertes
│   │   ├── Expense.swift
│   │   ├── TaxSettings.swift     // NEW: BTW/Fiscal settings
│   │   └── BusinessSettings.swift
│   ├── Services/
│   │   ├── PDFGenerationService.swift
│   │   ├── TaxCalculationService.swift  // NEW
│   │   ├── ExportService.swift
│   │   └── BackupService.swift          // NEW
│   └── Utilities/
│       └── DutchFormatters.swift
├── Features/
│   ├── Dashboard/
│   ├── TimeTracking/
│   ├── Projects/                 // NEW
│   ├── Invoicing/
│   ├── Quotes/                   // NEW
│   ├── Clients/
│   ├── Expenses/
│   ├── Reports/
│   │   ├── TaxReportView.swift   // NEW
│   │   └── VATReportView.swift   // NEW
│   └── Settings/
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings       // NEW: Localization
    └── InvoiceTemplates/         // NEW: Multiple templates
```

---

## 4. MARKTANALYSE (Lars)

### Concurrentieanalyse

| App | Type | Prijs | Nadelen |
|-----|------|-------|---------|
| Moneybird | Cloud | €15-45/maand | Abonnement, data bij derden |
| e-Boekhouden | Cloud | €12/maand | Abonnement, complex |
| Jortt | Cloud | €7/maand | Beperkte features |
| Exact | Desktop/Cloud | €€€ | Te complex voor ZZP |
| Excel | Desktop | €€ | Geen automatisering |

### Unieke Selling Points van Uurwerker

1. **Geen abonnement** - Eenmalige aanschaf (€49-79 suggested)
2. **100% Privacy** - Geen cloud, geen data delen
3. **Native macOS** - Sneller dan web-apps
4. **Nederlandse focus** - Specifiek voor NL fiscale regels
5. **Simpel & Krachtig** - Makkelijk te leren, veel mogelijk

### Doelgroep

**Primair:**
- ZZP'ers in Nederland (1.2+ miljoen)
- Freelancers (IT, creatief, consultancy)
- Kleine eenmanszaken
- Startende ondernemers

**Secundair:**
- Kleine VOF's
- Huisartsen, therapeuten, coaches
- Fotografen, designers, developers

### Prijsstrategie

| Tier | Prijs | Inclusief |
|------|-------|-----------|
| **Uurwerker Basis** | €49 | Alle basisfuncties |
| **Uurwerker Pro** | €79 | + Meerdere bedrijven, templates, export |

---

## 5. IMPLEMENTATIE INSTRUCTIES VOOR CLAUDE CODE

### Stap 1: Hernoemen en Rebranding

```bash
# Te wijzigen bestanden:
1. Project naam: RoBergBoekhouding → Uurwerker
2. Bundle identifier: com.roberg.boekhouding → nl.uurwerker.app
3. App naam in code
4. Alle references naar "RoBerg" verwijderen
```

**Actie voor Claude Code:**
```
Hernoem de app van "RoBergBoekhouding" naar "Uurwerker":
1. Maak nieuw Xcode project genaamd "Uurwerker" OF hernoem bestaand project
2. Update bundle identifier naar "nl.uurwerker.app"
3. Vervang alle hardcoded "RoBerg" references
4. Update CLAUDE.md met nieuwe projectnaam
5. Hernoem RoBergBoekhoudingApp.swift naar UurwerkerApp.swift
6. Update @main App struct naam
```

### Stap 2: BTW Ondersteuning

**Nieuw model: TaxSettings.swift**
```swift
@Model
final class TaxSettings {
    var btwPlichtig: Bool = true
    var btwTarief: BTWTarief = .standaard  // 0%, 9%, 21%
    var kleineondernemersregeling: Bool = false
    var korDrempel: Decimal = 20000  // KOR drempel
}

enum BTWTarief: String, Codable, CaseIterable {
    case vrijgesteld = "0%"
    case laag = "9%"
    case standaard = "21%"

    var percentage: Decimal {
        switch self {
        case .vrijgesteld: return 0
        case .laag: return 0.09
        case .standaard: return 0.21
        }
    }
}
```

**Actie voor Claude Code:**
```
Voeg BTW ondersteuning toe:
1. Maak TaxSettings.swift model
2. Voeg BTW veld toe aan Invoice model
3. Update Invoice totaal berekening met BTW
4. Voeg BTW selectie toe aan InvoiceGeneratorView
5. Update PDF template met BTW regel
```

### Stap 3: Generieke Branche Ondersteuning

**Wijzig ClientType enum:**
```swift
enum ClientType: String, Codable, CaseIterable {
    case zakelijk = "Zakelijk"
    case particulier = "Particulier"
    case overheid = "Overheid"

    // Verwijder: dagpraktijk, anwDienst, administratie
}
```

**Actie voor Claude Code:**
```
Maak de app branche-onafhankelijk:
1. Vervang zorg-specifieke ClientType met generieke types
2. Verwijder hardcoded uurtarieven voor zorg
3. Maak ActivityCode configureerbaar per gebruiker
4. Update sample data met generieke voorbeelden
```

### Stap 4: Logo en Branding Customization

**Nieuw in BusinessSettings:**
```swift
var logoPath: String?           // Pad naar logo afbeelding
var primaryColor: String?       // Hex kleurcode
var invoiceFooterText: String?  // Custom footer tekst
```

**Actie voor Claude Code:**
```
Voeg branding customization toe:
1. Voeg logo upload mogelijkheid toe aan SettingsView
2. Voeg kleurkiezer toe voor factuur accent kleur
3. Update PDFGenerationService om logo te gebruiken
4. Voeg preview van factuur met branding toe
```

### Stap 5: Professionele Factuursjablonen

**Actie voor Claude Code:**
```
Maak meerdere factuursjablonen:
1. Template 1: Modern (huidig design verfijnd)
2. Template 2: Klassiek (meer traditioneel)
3. Template 3: Minimaal (strakke lijnen)
4. Voeg template keuze toe aan Settings
5. Maak templates responsief voor verschillende content
```

### Stap 6: Offertes/Quotes

**Nieuw model: Quote.swift**
```swift
@Model
final class Quote {
    var id: UUID
    var offertenummer: String      // "OFF-2025-001"
    var client: Client?
    var items: [QuoteItem]
    var geldigTot: Date
    var status: QuoteStatus        // concept, verzonden, geaccepteerd, afgewezen
    var notities: String?

    // Kan omgezet worden naar Invoice
    func convertToInvoice() -> Invoice { ... }
}
```

**Actie voor Claude Code:**
```
Voeg offerte functionaliteit toe:
1. Maak Quote.swift model
2. Maak QuoteListView en QuoteFormView
3. Voeg "Quotes" toe aan sidebar navigatie
4. Implementeer "Omzetten naar factuur" functie
5. Maak PDF template voor offertes
```

### Stap 7: Fiscale Rapportages

**Actie voor Claude Code:**
```
Voeg fiscale rapportages toe:
1. BTW Kwartaaloverzicht:
   - Totaal omzet
   - Totaal BTW te betalen
   - Export naar CSV/PDF

2. Jaaroverzicht voor belastingaangifte:
   - Omzet per categorie
   - Kosten per categorie
   - Winst berekening
   - Zelfstandigenaftrek status

3. Zelfstandigenaftrek tracker:
   - Voortgang naar 1225 uren
   - Waarschuwing als niet op schema
```

### Stap 8: App Store Voorbereiding

**Actie voor Claude Code:**
```
Bereid app voor op App Store:
1. Voeg About view toe met:
   - App versie
   - Licentie informatie
   - Link naar privacy policy
   - Contact informatie

2. Voeg Help/Onboarding toe:
   - Eerste keer wizard
   - Tips voor nieuwe gebruikers

3. Accessibility:
   - VoiceOver labels op alle controls
   - Dynamic Type support

4. Proper Error Handling:
   - Alle try? vervangen door proper do-catch
   - User-friendly error messages
```

### Stap 9: App Icon

**Actie voor Claude Code:**
```
Beschrijf app icon voor designer:
- Concept: Gestileerde klok/tandwiel combinatie
- Kleuren: Donkerblauw (#1a365d) met goud/amber accent (#d69e2e)
- Stijl: Modern, minimalistisch, macOS Big Sur style
- Elementen:
  - Cirkel met uurwerk-achtige tandwieltanden
  - Wijzers die naar een tijdstip wijzen
  - Of: abstracte "U" vorm met klok-elementen
- Uitstraling: Precisie, professionaliteit, tijdmanagement
```

---

## 6. PRIORITERING

### Must Have (v1.0)
1. ✅ Hernoemen naar Uurwerker
2. ✅ BTW ondersteuning (0%, 9%, 21%)
3. ✅ Generieke branche ondersteuning
4. ✅ Logo upload
5. ✅ About/Help sectie
6. ✅ Proper error handling
7. ✅ Accessibility basics

### Should Have (v1.1)
1. Offertes/Quotes
2. Meerdere factuursjablonen
3. BTW kwartaaloverzicht
4. Zelfstandigenaftrek tracker
5. Recurring invoices

### Nice to Have (v1.2+)
1. Bank statement import
2. iCloud sync
3. Meerdere bedrijfsprofielen
4. Kalender integratie
5. Projecten met budgetten

---

## 7. DEFINITIE VAN SUCCES

### Metrics voor "Next Level"

1. **Kwaliteit**
   - 0 crashes in normale gebruik
   - <2 seconden launch time
   - Alle data operaties <100ms

2. **App Store**
   - Goedkeuring bij eerste submit
   - 4.5+ sterren rating
   - Featured in "Made for Mac" sectie

3. **Gebruikers**
   - 1000+ downloads in eerste maand
   - 50+ positieve reviews
   - <5% refund rate

---

## 8. VOLGENDE STAPPEN

1. ~~**Bevestig naam**~~ ✅ "Uurwerker" bevestigd
2. **Begin met Stap 1**: Hernoemen project naar Uurwerker
3. **Implementeer Must Haves** in volgorde
4. **Test grondig** na elke fase
5. **Bereid App Store assets voor** (screenshots, beschrijving)
6. **Submit naar App Store**

---

## 9. AANVULLENDE INSTRUCTIES

### Data Migratie
Bij het hernoemen van de app:
- Bestaande gebruikersdata moet behouden blijven
- SwiftData database locatie wijzigt mee met nieuwe app naam
- Overweeg een migratiepad voor bestaande data

### Backward Compatibility
- Huidige RoBergBoekhouding data moet importeerbaar zijn in Uurwerker
- Documenteer het migratieproces voor bestaande gebruikers

### Testprotocol per Stap
Voor elke implementatiestap:
1. Controleer dat de app compileert zonder errors
2. Controleer dat bestaande functionaliteit werkt
3. Test de nieuwe functionaliteit handmatig
4. Verifieer dat geen regressies zijn ontstaan

### App Store Beschrijving (concept)

```
Uurwerker - Precisie voor ondernemers

De slimme boekhoudapp voor Nederlandse ZZP'ers.
Geen abonnement, geen cloud, gewoon een krachtige
native Mac app die jouw administratie moeiteloos maakt.

✓ Urenregistratie en facturatie
✓ BTW-berekening (0%, 9%, 21%)
✓ Zelfstandigenaftrek tracking
✓ Professionele PDF facturen
✓ 100% privacy - data blijft op jouw Mac

Speciaal ontworpen voor de Nederlandse ZZP'er.
```

### Privacy Policy Template
Maak privacy policy pagina met:
- Geen data verzameling
- Alle data lokaal opgeslagen
- Geen analytics
- Geen third-party services
- GDPR compliant

### Kritieke Implementatie Details

#### Xcode Project Hernoemen (Stap 1 - Uitgebreid)
Het hernoemen van een Xcode project is complex. Aanbevolen aanpak:

**Optie A: Nieuw project maken (AANBEVOLEN)**
1. Maak nieuw Xcode project "Uurwerker"
2. Kopieer alle Swift bestanden naar nieuw project
3. Kopieer Assets.xcassets
4. Configureer SwiftData modellen in nieuw project
5. Test migratie van bestaande data

**Optie B: Bestaand project hernoemen**
1. Sluit Xcode volledig
2. Hernoem .xcodeproj folder
3. Open project.pbxproj in teksteditor
4. Vervang alle "RoBergBoekhouding" references
5. Hernoem target en scheme
6. Update Info.plist entries
7. Verwijder derived data

#### BTW op Factuurregels
BTW moet per factuurregels worden toegepast, niet per factuur:
```swift
// Invoice model aanpassing:
@Model
final class InvoiceLineItem {
    var beschrijving: String
    var aantal: Decimal
    var prijsPerEenheid: Decimal
    var btwTarief: BTWTarief  // Per regel instelbaar

    var bedragExclBTW: Decimal { aantal * prijsPerEenheid }
    var btwBedrag: Decimal { bedragExclBTW * btwTarief.percentage }
    var bedragInclBTW: Decimal { bedragExclBTW + btwBedrag }
}
```

#### Factuur PDF met BTW Breakdown
PDF moet tonen:
```
Beschrijving         Aantal  Prijs    BTW%   Subtotaal
─────────────────────────────────────────────────────
Consulting uren      10      €80,00   21%    €800,00
Softwarelicentie     1       €200,00  21%    €200,00
─────────────────────────────────────────────────────
                              Subtotaal excl. BTW: €1.000,00
                              BTW 21%:             €210,00
                              ─────────────────────────────
                              TOTAAL:              €1.210,00
```

#### Flexibele Factuurregels
Huidige app koppelt alleen TimeEntries aan facturen. Voor algemeen ZZP-gebruik:
- Los product/dienst toevoegen (niet alleen uren)
- Handmatige regeltoevoeging
- Km-vergoeding als optionele regel
- Diverse posten ondersteuning

#### Kilometer Registratie Vereenvoudigen
Verwijder healthcare-specifieke velden:
- `retourafstandWoonWerk` → Optioneel "Reiskosten" veld
- `visiteKilometers` → Verwijderen of generiek maken
- Km-tarief configureerbaar in Settings (standaard €0,23)

#### Eerste Gebruik Wizard
Bij eerste launch van Uurwerker:
1. Welkomscherm met uitleg
2. Bedrijfsgegevens invoeren (naam, KVK, BTW-nummer)
3. BTW-instelling kiezen (vrijgesteld/9%/21%/KOR)
4. Standaard uurtarief instellen
5. Optioneel: Logo uploaden
6. Klaar om te beginnen

#### Keyboard Shortcuts
Voor power users:
- ⌘N: Nieuwe urenregistratie
- ⌘⇧N: Nieuwe factuur
- ⌘⇧I: Import
- ⌘E: Export
- ⌘,: Instellingen

#### Minimum Viable Product Definitie
**Absoluut nodig voor v1.0 App Store:**
1. Hernoemen naar Uurwerker ✓
2. Generieke ClientType (zakelijk/particulier) ✓
3. BTW ondersteuning (0%/9%/21%) ✓
4. Flexibele factuurregels ✓
5. Logo upload ✓
6. About scherm met versie ✓
7. Privacy policy link ✓
8. App icon ✓

**Kan wachten tot v1.1:**
- Offertes/Quotes
- Meerdere templates
- Zelfstandigenaftrek tracker
- KOR berekening

### Waarschuwingen

1. **GEEN BREAKING CHANGES** aan bestaande data
   - SwiftData migreert automatisch voor nieuwe velden met defaults
   - Verwijder NOOIT bestaande properties zonder migratiestrategie

2. **BTW Berekening is Kritiek**
   - Test grondig met verschillende tarieven
   - Afrondingen moeten correct zijn (2 decimalen)
   - BTW-vrije facturen moeten "BTW verlegd" of "Vrijgesteld artikel 11" tonen

3. **App Store Review**
   - Geen placeholder teksten laten staan
   - Alle knoppen moeten werken
   - Geen hardcoded testdata
   - Dark mode moet correct werken

---

## 10. IMPLEMENTATIE VOLGORDE

De aanbevolen volgorde voor Claude Code:

```
Week 1: Basis
├── Stap 1: Hernoemen project
├── Stap 3: Generieke branche (verwijder zorg-specifiek)
└── Test: Bestaande functionaliteit werkt nog

Week 2: BTW & Facturatie
├── Stap 2: BTW ondersteuning toevoegen
├── Flexibele factuurregels implementeren
└── Test: Factuur met BTW correct

Week 3: Branding & UX
├── Stap 4: Logo upload
├── About/Help scherm
├── First-run wizard
└── Test: Complete flow voor nieuwe gebruiker

Week 4: Polish & Submit
├── Accessibility check
├── Error handling verbeteren
├── App icon finaliseren
├── Privacy policy pagina maken
└── App Store submit voorbereiden
```

---

*Dit document dient als instructie voor Claude Code. Elke "Actie voor Claude Code" sectie kan direct uitgevoerd worden. Volg de implementatievolgorde in sectie 10.*
