import Foundation

// MARK: - Client Type
enum ClientType: String, Codable, CaseIterable {
    case dagpraktijk = "Dagpraktijk"
    case anwDienst = "ANW Dienst"
    case administratie = "Administratie"

    var displayName: String {
        switch self {
        case .dagpraktijk: return "Dagpraktijk"
        case .anwDienst: return "ANW Dienst"
        case .administratie: return "Administratie"
        }
    }

    var defaultHourlyRate: Decimal {
        switch self {
        case .dagpraktijk: return 70.00
        case .anwDienst: return 124.00
        case .administratie: return 0.00
        }
    }
}

// MARK: - Invoice Status
enum InvoiceStatus: String, Codable, CaseIterable {
    case concept = "Concept"
    case verzonden = "Verzonden"
    case betaald = "Betaald"
    case herinnering = "Herinnering"
    case oninbaar = "Oninbaar"

    var displayName: String { rawValue }

    var color: String {
        switch self {
        case .concept: return "gray"
        case .verzonden: return "orange"
        case .betaald: return "green"
        case .herinnering: return "red"
        case .oninbaar: return "purple"
        }
    }

    /// All other statuses (excluding current)
    var otherStatuses: [InvoiceStatus] {
        InvoiceStatus.allCases.filter { $0 != self }
    }
}

// MARK: - Expense Category (matching VvAA/Dutch tax structure)
enum ExpenseCategory: String, Codable, CaseIterable {
    case accountancy = "Administratie- en accountantskosten"
    case verzekeringen = "Verzekeringen"
    case pensioenpremie = "Pensioenen"
    case lidmaatschappen = "Contributies en abonnementen"
    case investeringen = "Inventaris en afschrijvingen"
    case kleineAankopen = "Kleine aanschaffen"
    case telefoonInternet = "Telefoon- en internetkosten"
    case representatie = "Representatiekosten"
    case opleidingskosten = "Opleidingskosten"
    case reiskosten = "Reiskosten"
    case bankkosten = "Bankkosten"
    case overig = "Overige kosten"

    var displayName: String { rawValue }

    var taxCategory: String {
        switch self {
        case .accountancy: return "Algemene kosten"
        case .verzekeringen: return "Bedrijfslasten"
        case .pensioenpremie: return "Personeelskosten"
        case .lidmaatschappen: return "Kantoorkosten"
        case .investeringen: return "Afschrijvingen"
        case .kleineAankopen: return "Kantoorkosten"
        case .telefoonInternet: return "Kantoorkosten"
        case .representatie: return "Verkoopkosten"
        case .opleidingskosten: return "Personeelskosten"
        case .reiskosten: return "Autokosten"
        case .bankkosten: return "Financiele kosten"
        case .overig: return "Overige bedrijfskosten"
        }
    }

    var icon: String {
        switch self {
        case .accountancy: return "doc.text"
        case .verzekeringen: return "shield"
        case .pensioenpremie: return "banknote"
        case .lidmaatschappen: return "person.3"
        case .investeringen: return "desktopcomputer"
        case .kleineAankopen: return "bag"
        case .telefoonInternet: return "phone"
        case .representatie: return "fork.knife"
        case .opleidingskosten: return "book"
        case .reiskosten: return "car"
        case .bankkosten: return "creditcard"
        case .overig: return "ellipsis.circle"
        }
    }
}

// MARK: - Activity Codes (matching URENREGISTERexport.csv)
enum ActivityCode: String, Codable, CaseIterable {
    case wDagpraktijk70 = "WDAGPRAKTIJK_70"
    case wDagpraktijk77_50 = "WDAGPRAKTIJK_77,50"
    case wDagpraktijk80 = "WDAGPRAKTIJK_80"
    case anwDrWeekendDag = "ANW_DR_WEEKEND_DAG"
    case anwGrWeekendDag = "ANW_GR_WEEKEND_DAG"
    case anwDrWerkdagAvond = "ANW_DR_WERKDAG_AVOND"
    case anwDrWerkdagNacht = "ANW_DR_WERKDAG_NACHT"
    case anwDrWerkdagAvondAchterwacht = "ANW_DR_WERKDAG_AVOND_ACHTERWACHT"
    case anwGrWeekendAvond = "ANW_GR_WEEKEND_AVOND"
    case admin = "Admin"
    case nschl = "NSCHL"

    var displayName: String {
        switch self {
        case .wDagpraktijk70: return "Waarneming Dagpraktijk (€70)"
        case .wDagpraktijk77_50: return "Waarneming Dagpraktijk (€77,50)"
        case .wDagpraktijk80: return "Waarneming Dagpraktijk (€80)"
        case .anwDrWeekendDag: return "ANW Drenthe Weekend Dag"
        case .anwGrWeekendDag: return "ANW Groningen Weekend Dag"
        case .anwDrWerkdagAvond: return "ANW Drenthe Werkdag Avond"
        case .anwDrWerkdagNacht: return "ANW Drenthe Werkdag Nacht"
        case .anwDrWerkdagAvondAchterwacht: return "ANW Drenthe Avond Achterwacht"
        case .anwGrWeekendAvond: return "ANW Groningen Weekend Avond"
        case .admin: return "Administratie"
        case .nschl: return "Nascholing"
        }
    }

    var hourlyRate: Decimal {
        switch self {
        case .wDagpraktijk70: return 70.00
        case .wDagpraktijk77_50: return 77.50
        case .wDagpraktijk80: return 80.00
        case .anwDrWeekendDag, .anwGrWeekendDag, .anwDrWerkdagAvond,
             .anwDrWerkdagNacht, .anwDrWerkdagAvondAchterwacht, .anwGrWeekendAvond:
            return 124.00
        case .admin, .nschl: return 0.00
        }
    }

    var isBillable: Bool {
        switch self {
        case .admin, .nschl: return false
        default: return true
        }
    }
}

// MARK: - Sidebar Navigation
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case urenregistratie = "Urenregistratie"
    case facturen = "Facturen"
    case klanten = "Klanten"
    case uitgaven = "Uitgaven"
    case rapportages = "Rapportages"
    case instellingen = "Instellingen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie"
        case .urenregistratie: return "clock"
        case .facturen: return "doc.text"
        case .klanten: return "person.2"
        case .uitgaven: return "creditcard"
        case .rapportages: return "chart.bar.doc.horizontal"
        case .instellingen: return "gear"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: return .main
        case .urenregistratie, .uitgaven: return .registratie
        case .facturen, .klanten: return .facturatie
        case .rapportages: return .financieel
        case .instellingen: return .main
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case main = ""
    case registratie = "Registratie"
    case facturatie = "Facturatie"
    case financieel = "Financieel"
}
