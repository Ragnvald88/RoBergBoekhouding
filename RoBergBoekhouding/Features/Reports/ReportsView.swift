import SwiftUI
import SwiftData

struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query private var timeEntries: [TimeEntry]
    @Query private var invoices: [Invoice]
    @Query private var expenses: [Expense]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Rapportages")
                        .font(.title2.weight(.semibold))

                    Spacer()

                    Picker("Jaar", selection: $appState.selectedYear) {
                        ForEach(appState.availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .frame(width: 100)
                }

                // Report Cards Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // Annual Summary
                    ReportCard(
                        title: "Jaaroverzicht",
                        description: "Volledige financiele samenvatting",
                        icon: "doc.text.fill",
                        color: .blue
                    ) {
                        exportAnnualSummary()
                    }

                    // Hours & Kilometers
                    ReportCard(
                        title: "Uren & Kilometers",
                        description: "Voor belastingaangifte",
                        icon: "clock.fill",
                        color: .green
                    ) {
                        exportHoursReport()
                    }

                    // Kilometer Report
                    ReportCard(
                        title: "Kilometeradministratie",
                        description: "Gedetailleerd km-overzicht",
                        icon: "car.fill",
                        color: .orange
                    ) {
                        exportKilometerReport()
                    }

                    // Revenue by Client
                    ReportCard(
                        title: "Omzet per klant",
                        description: "Inkomsten per opdrachtgever",
                        icon: "person.2.fill",
                        color: .purple
                    ) {
                        exportClientReport()
                    }

                    // Expense Summary
                    ReportCard(
                        title: "Uitgaven",
                        description: "Kosten per categorie",
                        icon: "creditcard.fill",
                        color: .red
                    ) {
                        exportExpenseReport()
                    }

                    // Invoice Overview
                    ReportCard(
                        title: "Factuuroverzicht",
                        description: "Alle facturen van het jaar",
                        icon: "doc.richtext.fill",
                        color: .indigo
                    ) {
                        exportInvoiceReport()
                    }
                }

                Divider()

                // Quick Stats for Selected Year
                yearSummarySection
            }
            .padding(24)
        }
        .navigationTitle("Rapportages")
    }

    // MARK: - Year Summary Section
    private var yearSummarySection: some View {
        let yearEntries = timeEntries.filterByYear(appState.selectedYear)
        let yearInvoices = invoices.filterByYear(appState.selectedYear)
        let yearExpenses = expenses.filterByYear(appState.selectedYear)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Samenvatting \(appState.selectedYear)")
                .font(.headline)

            HStack(spacing: 20) {
                // Revenue
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inkomsten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    StatRowView(label: "Totale omzet", value: yearEntries.totalRevenue.asCurrency)
                    StatRowView(label: "Totaal uren", value: "\(yearEntries.totalHours.asDecimal)")
                    StatRowView(label: "Totaal km", value: "\(yearEntries.totalKilometers.formatted)")
                    StatRowView(label: "Gefactureerd", value: yearInvoices.totalAmount.asCurrency)
                    StatRowView(label: "Betaald", value: yearInvoices.totalPaid.asCurrency, color: .green)
                    StatRowView(label: "Openstaand", value: yearInvoices.totalOutstanding.asCurrency, color: .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Expenses
                VStack(alignment: .leading, spacing: 8) {
                    Text("Uitgaven")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    StatRowView(label: "Totaal uitgaven", value: yearExpenses.totalBusinessAmount.asCurrency)

                    ForEach(yearExpenses.summaryByCategory.prefix(5), id: \.category) { item in
                        StatRowView(label: item.category.displayName, value: item.total.asCurrency)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Result
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resultaat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    let profit = yearEntries.totalRevenue - yearExpenses.totalBusinessAmount

                    StatRowView(label: "Bruto omzet", value: yearEntries.totalRevenue.asCurrency)
                    StatRowView(label: "Totaal kosten", value: yearExpenses.totalBusinessAmount.asCurrency)

                    Divider()

                    StatRowView(
                        label: "Netto resultaat",
                        value: profit.asCurrency,
                        color: profit >= 0 ? .green : .red
                    )
                    .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }

    // MARK: - Export Methods

    private func exportAnnualSummary() {
        let service = ExportService(modelContext: modelContext)
        let content = service.exportAnnualSummary(
            year: appState.selectedYear,
            entries: timeEntries,
            expenses: expenses
        )
        saveToFile(content: content, filename: "Jaaroverzicht_\(appState.selectedYear).txt")
    }

    private func exportHoursReport() {
        let yearEntries = timeEntries.filterByYear(appState.selectedYear)

        var csv = "URENOVERZICHT \(appState.selectedYear)\n"
        csv += "RoBerg huisartswaarnemer\n\n"
        csv += "Totaal uren: \(yearEntries.totalHours.asDecimal)\n"
        csv += "Totaal factureerbare uren: \(yearEntries.totalBillableHours.asDecimal)\n"
        csv += "Totaal kilometers: \(yearEntries.totalKilometers)\n\n"

        csv += "Maand;Uren;Factureerbaar;Kilometers;Omzet\n"

        for month in 1...12 {
            let monthEntries = yearEntries.filterByMonth(month, year: appState.selectedYear)
            let monthName = monthNames[month - 1]
            csv += "\(monthName);\(monthEntries.totalHours.asDecimal);\(monthEntries.totalBillableHours.asDecimal);\(monthEntries.totalKilometers);\(monthEntries.totalRevenue.asCurrency)\n"
        }

        saveToFile(content: csv, filename: "Urenoverzicht_\(appState.selectedYear).csv")
    }

    private func exportKilometerReport() {
        let service = ExportService(modelContext: modelContext)
        let content = service.exportKilometerReport(year: appState.selectedYear, entries: timeEntries)
        saveToFile(content: content, filename: "Kilometeradministratie_\(appState.selectedYear).csv")
    }

    private func exportClientReport() {
        let yearEntries = timeEntries.filterByYear(appState.selectedYear)
        let byClient = yearEntries.groupedByClient.sorted { $0.entries.totalRevenue > $1.entries.totalRevenue }

        var csv = "Klant;Uren;Kilometers;Omzet\n"

        for item in byClient {
            let name = item.client?.bedrijfsnaam ?? "Onbekend"
            csv += "\(name);\(item.entries.totalHours.asDecimal);\(item.entries.totalKilometers);\(item.entries.totalRevenue.asCurrency)\n"
        }

        csv += "\nTOTAAL;\(yearEntries.totalHours.asDecimal);\(yearEntries.totalKilometers);\(yearEntries.totalRevenue.asCurrency)\n"

        saveToFile(content: csv, filename: "Omzet_per_klant_\(appState.selectedYear).csv")
    }

    private func exportExpenseReport() {
        let yearExpenses = expenses.filterByYear(appState.selectedYear)

        var csv = "Datum;Omschrijving;Leverancier;Categorie;Bedrag;Zakelijk %%;Zakelijk Bedrag\n"

        for expense in yearExpenses.sortedByDate.reversed() {
            csv += "\(expense.datumFormatted);\(expense.omschrijving);\(expense.leverancier ?? "");\(expense.categorie.displayName);\(expense.bedrag.asCurrency);\(Int(truncating: expense.zakelijkPercentage as NSDecimalNumber))%;\(expense.zakelijkBedrag.asCurrency)\n"
        }

        csv += "\n"
        csv += "PER CATEGORIE:\n"
        for (category, total) in yearExpenses.summaryByCategory {
            csv += "\(category.displayName);;\(total.asCurrency)\n"
        }
        csv += "\nTOTAAL ZAKELIJK;;\(yearExpenses.totalBusinessAmount.asCurrency)\n"

        saveToFile(content: csv, filename: "Uitgaven_\(appState.selectedYear).csv")
    }

    private func exportInvoiceReport() {
        let yearInvoices = invoices.filterByYear(appState.selectedYear)

        var csv = "Factuurnummer;Datum;Klant;Uren;Kilometers;Bedrag;Status\n"

        for invoice in yearInvoices.sortedByDate.reversed() {
            csv += "\(invoice.factuurnummer);\(invoice.factuurdatumFormatted);\(invoice.client?.bedrijfsnaam ?? "Onbekend");\(invoice.totaalUren.asDecimal);\(invoice.totaalKilometers);\(invoice.totaalbedrag.asCurrency);\(invoice.status.displayName)\n"
        }

        csv += "\nTOTAAL;;;;\(yearInvoices.totalAmount.asCurrency)\n"
        csv += "BETAALD;;;;\(yearInvoices.totalPaid.asCurrency)\n"
        csv += "OPENSTAAND;;;;\(yearInvoices.totalOutstanding.asCurrency)\n"

        saveToFile(content: csv, filename: "Factuuroverzicht_\(appState.selectedYear).csv")
    }

    private func saveToFile(content: String, filename: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .commaSeparatedText]
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    print("Error saving file: \(error)")
                }
            }
        }
    }

    private var monthNames: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols.map { $0.capitalized }
    }
}

// MARK: - Report Card
struct ReportCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)

                    Spacer()

                    Image(systemName: "arrow.down.doc")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ReportsView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
