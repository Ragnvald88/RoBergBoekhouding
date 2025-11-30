import Foundation
import SwiftData

// MARK: - Export Service
class ExportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export Time Entries to CSV

    func exportTimeEntriesToCSV(entries: [TimeEntry]) -> String {
        var csv = "Datum;CODE;Klant;Activiteit;Locatie;Uren;Visite_kilometers;Retourafstand woon/werk km;Uurtarief;Kilometertarief;Totaalbedrag Uren;Totaalbedrag km;Totaalbedrag;Factuurnummer;Opmerkingen\n"

        for entry in entries.sortedByDate.reversed() {
            let row = [
                entry.datumFormatted.replacingOccurrences(of: "-", with: "/"),
                entry.code,
                entry.client?.bedrijfsnaam ?? "",
                entry.activiteit,
                entry.locatie,
                entry.uren.asDecimal.replacingOccurrences(of: ".", with: ","),
                entry.visiteKilometers?.asDecimal.replacingOccurrences(of: ".", with: ",") ?? "",
                "\(entry.retourafstandWoonWerk)",
                "€ \(entry.uurtarief.asDecimal)",
                "€ \(entry.kilometertarief.asDecimal)",
                "€ \(entry.totaalbedragUren.asDecimal)",
                "€ \(entry.totaalbedragKm.asDecimal)",
                "€ \(entry.totaalbedrag.asDecimal)",
                entry.factuurnummer ?? "",
                entry.opmerkingen ?? ""
            ].joined(separator: ";")

            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Export Annual Summary

    func exportAnnualSummary(year: Int, entries: [TimeEntry], expenses: [Expense]) -> String {
        let yearEntries = entries.filterByYear(year)
        let yearExpenses = expenses.filterByYear(year)

        var report = """
        JAAROVERZICHT \(year)
        RoBerg huisartswaarnemer

        ================================================================================
        INKOMSTEN
        ================================================================================

        Totaal uren: \(yearEntries.totalHours.asDecimal)
        Totaal kilometers: \(yearEntries.totalKilometers.formatted)
        Totaal omzet: \(yearEntries.totalRevenue.asCurrency)

        Omzet per klant:
        """

        let byClient = yearEntries.groupedByClient.sorted { $0.entries.totalRevenue > $1.entries.totalRevenue }
        for item in byClient {
            let name = item.client?.bedrijfsnaam ?? "Onbekend"
            let revenue = item.entries.totalRevenue
            report += "\n  - \(name): \(revenue.asCurrency)"
        }

        report += """


        ================================================================================
        UITGAVEN
        ================================================================================

        Totaal uitgaven: \(yearExpenses.totalBusinessAmount.asCurrency)

        Uitgaven per categorie:
        """

        for (category, total) in yearExpenses.summaryByCategory {
            report += "\n  - \(category.displayName): \(total.asCurrency)"
        }

        let profit = yearEntries.totalRevenue - yearExpenses.totalBusinessAmount
        report += """


        ================================================================================
        RESULTAAT
        ================================================================================

        Bruto omzet:        \(yearEntries.totalRevenue.asCurrency)
        Totaal kosten:      \(yearExpenses.totalBusinessAmount.asCurrency)
        -----------------------------------------
        Netto resultaat:    \(profit.asCurrency)

        ================================================================================
        """

        return report
    }

    // MARK: - Export Kilometer Report

    func exportKilometerReport(year: Int, entries: [TimeEntry]) -> String {
        let yearEntries = entries.filterByYear(year).billableOnly

        var csv = "Datum;Klant;Locatie;Retourafstand;Visite km;Totaal km;Tarief;Bedrag\n"

        for entry in yearEntries.sortedByDate.reversed() {
            let row = [
                entry.datumFormatted,
                entry.client?.bedrijfsnaam ?? "",
                entry.locatie,
                "\(entry.retourafstandWoonWerk)",
                entry.visiteKilometers?.asDecimal ?? "0",
                "\(entry.totaalKilometers)",
                entry.kilometertarief.asCurrency,
                entry.totaalbedragKm.asCurrency
            ].joined(separator: ";")

            csv += row + "\n"
        }

        // Add totals
        csv += "\n"
        csv += ";;TOTAAL;\(yearEntries.totalKilometers);;;\(yearEntries.reduce(0) { $0 + $1.totaalbedragKm }.asCurrency)\n"

        return csv
    }
}
