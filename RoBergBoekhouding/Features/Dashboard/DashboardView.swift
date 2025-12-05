import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query private var timeEntries: [TimeEntry]
    @Query private var invoices: [Invoice]
    @Query private var clients: [Client]
    @Query private var settings: [BusinessSettings]

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var yearEntries: [TimeEntry] {
        timeEntries.filterByYear(currentYear)
    }

    private var yearInvoices: [Invoice] {
        invoices.filterByYear(currentYear)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // KPI Cards
                kpiCardsSection

                // Charts Row
                HStack(spacing: 20) {
                    revenueChartSection
                    zelfstandigenAftrekSection
                }
                .frame(height: 250)

                // Bottom Row
                HStack(spacing: 20) {
                    recentActivitySection
                    outstandingInvoicesSection
                }

                // Uninvoiced work section
                uninvoicedWorkSection
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nieuwe Registratie", systemImage: "plus") {
                    appState.showNewTimeEntry = true
                }
                .accessibilityLabel("Nieuwe tijdregistratie toevoegen")
                .accessibilityHint("Opent formulier om nieuwe uren of kilometers te registreren")
            }
        }
        .sheet(isPresented: $appState.showNewTimeEntry) {
            TimeEntryFormView(entry: nil)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welkom terug")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(Date().fullDutch)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            Picker("Jaar", selection: $appState.selectedYear) {
                ForEach(appState.availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    // MARK: - KPI Cards Section
    private var kpiCardsSection: some View {
        HStack(spacing: 20) {
            // Revenue YTD
            KPICardView(
                title: "Omzet YTD",
                value: yearEntries.totalRevenue.asCurrency,
                subtitle: yearComparisonText,
                icon: "eurosign.circle.fill",
                color: .green
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Omzet dit jaar: \(yearEntries.totalRevenue.asCurrency). \(yearComparisonText)")

            // Hours YTD - show working hours (excludes standby)
            KPICardView(
                title: "Werkuren YTD",
                value: "\(yearEntries.totalWorkingHours.asDecimal)",
                subtitle: standbyHoursSubtitle,
                icon: "clock.fill",
                color: .blue
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Werkuren dit jaar: \(yearEntries.totalWorkingHours.asDecimal). \(standbyHoursSubtitle)")

            // Kilometers YTD
            KPICardView(
                title: "Kilometers YTD",
                value: "\(yearEntries.totalKilometers.formatted) km",
                subtitle: kmRevenueText,
                icon: "car.fill",
                color: .orange
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Kilometers dit jaar: \(yearEntries.totalKilometers.formatted) kilometer. Kilometervergoeding: \(kmRevenueText)")

            // Outstanding
            KPICardView(
                title: "Openstaand",
                value: yearInvoices.totalOutstanding.asCurrency,
                subtitle: "\(yearInvoices.filterByStatus(.verzonden).count) facturen",
                icon: "doc.text.fill",
                color: openstandingColor
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Openstaande facturen: \(yearInvoices.totalOutstanding.asCurrency) in \(yearInvoices.filterByStatus(.verzonden).count) facturen")
        }
    }

    // MARK: - Revenue Chart Section
    private var revenueChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Omzet per maand")
                .font(.headline)

            if monthlyRevenue.isEmpty {
                ContentUnavailableView("Geen gegevens", systemImage: "chart.bar")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(monthlyRevenue, id: \.month) { item in
                    BarMark(
                        x: .value("Maand", item.monthName),
                        y: .value("Omzet", item.revenue)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("€\(intValue / 1000)k")
                            }
                        }
                    }
                }
                .accessibilityLabel("Grafiek van maandelijkse omzet")
                .accessibilityValue(revenueChartAccessibilityDescription)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Zelfstandigenaftrek Section
    private var zelfstandigenAftrekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zelfstandigenaftrek")
                .font(.headline)

            // NOTE: For zelfstandigenaftrek, ALL worked hours count (including admin, training)
            // BUT standby/achterwacht hours do NOT count - only actual work hours
            let target = Decimal(settings.first?.urendrempelZelfstandigenaftrek ?? 1225)
            let workingHours = yearEntries.totalWorkingHours
            let standbyHours = yearEntries.totalStandbyHours
            let progress = min(workingHours / target, 1.0)
            let remaining = max(target - workingHours, 0)

            VStack(spacing: 16) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                    Circle()
                        .trim(from: 0, to: CGFloat(truncating: progress as NSDecimalNumber))
                        .stroke(
                            progress >= 1 ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)

                    VStack(spacing: 4) {
                        Text("\(Int(truncating: (progress * 100) as NSDecimalNumber))%")
                            .font(.system(size: 36, weight: .bold))
                        Text("\(workingHours.asDecimal) uur")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Zelfstandigenaftrek voortgang: \(Int(truncating: (progress * 100) as NSDecimalNumber)) procent, \(workingHours.asDecimal) van \(target.asDecimal) uren")
                .accessibilityValue(progress >= 1 ? "Drempel behaald" : "Nog \(remaining.asDecimal) uur nodig")

                if progress >= 1 {
                    Label("Drempel behaald!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Nog \(remaining.asDecimal) uur nodig")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Show non-working hours separately if any
                if standbyHours > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.xmark")
                            .foregroundStyle(.purple)
                        Text("\(standbyHours.asDecimal) uur (geen werkuren)")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    .help("Uren die niet meetellen voor het urencriterium (bijv. achterwacht, toeslagen)")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recente activiteit")
                    .font(.headline)
                Spacer()
                Button("Bekijk alles") {
                    appState.selectedSidebarItem = .urenregistratie
                }
                .font(.caption)
                .accessibilityLabel("Bekijk alle tijdregistraties")
                .accessibilityHint("Navigeert naar de volledige lijst met tijdregistraties")
            }

            if recentEntries.isEmpty {
                ContentUnavailableView("Geen recente activiteit", systemImage: "clock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentEntries) { entry in
                        RecentActivityRow(entry: entry)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .frame(minHeight: 200)
    }

    // MARK: - Outstanding Invoices Section
    private var outstandingInvoicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Openstaande facturen")
                    .font(.headline)
                Spacer()
                Button("Bekijk alles") {
                    appState.selectedSidebarItem = .facturen
                }
                .font(.caption)
                .accessibilityLabel("Bekijk alle facturen")
                .accessibilityHint("Navigeert naar de volledige factuurlijst")
            }

            if outstandingInvoices.isEmpty {
                ContentUnavailableView("Geen openstaande facturen", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(outstandingInvoices) { invoice in
                        OutstandingInvoiceRow(invoice: invoice)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .frame(minHeight: 200)
    }

    // MARK: - Uninvoiced Work Section
    private var uninvoicedWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nog te factureren per klant")
                    .font(.headline)
                Spacer()
                if !clientsWithUninvoicedWork.isEmpty {
                    Text("Totaal: \(totalUninvoicedAmount.asCurrency)")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                }
            }

            if clientsWithUninvoicedWork.isEmpty {
                HStack {
                    ContentUnavailableView("Alle uren gefactureerd", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 100)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(clientsWithUninvoicedWork, id: \.client.id) { item in
                        UninvoicedClientCard(
                            client: item.client,
                            entries: item.entries,
                            amount: item.amount,
                            onCreateInvoice: {
                                appState.selectedSidebarItem = .facturen
                                appState.showNewInvoice = true
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Computed Properties

    private var yearComparisonText: String {
        let lastYearRevenue = timeEntries.filterByYear(currentYear - 1).totalRevenue
        guard lastYearRevenue > 0 else { return "Eerste jaar" }

        let currentRevenue = yearEntries.totalRevenue
        let change = ((currentRevenue - lastYearRevenue) / lastYearRevenue) * 100
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(Int(truncating: change as NSDecimalNumber))% vs \(currentYear - 1)"
    }

    private var kmRevenueText: String {
        let kmRevenue = yearEntries.reduce(Decimal(0)) { $0 + $1.totaalbedragKm }
        return kmRevenue.asCurrency
    }

    private var standbyHoursSubtitle: String {
        let standby = yearEntries.totalStandbyHours
        if standby > 0 {
            return "+ \(standby.asDecimal) overig"
        }
        return "van \(settings.first?.urendrempelZelfstandigenaftrek ?? 1225)"
    }

    private var openstandingColor: Color {
        let outstanding = yearInvoices.totalOutstanding
        if outstanding > 5000 { return .red }
        if outstanding > 2000 { return .orange }
        return .green
    }

    private var monthlyRevenue: [(month: Int, monthName: String, revenue: Double)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "MMM"

        return (1...12).map { month in
            let entries = yearEntries.filterByMonth(month, year: currentYear)
            let revenue = entries.totalRevenue

            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = 1
            let date = calendar.date(from: components) ?? Date()
            let monthName = formatter.string(from: date)

            return (month, monthName, Double(truncating: revenue as NSDecimalNumber))
        }
    }

    private var recentEntries: [TimeEntry] {
        Array(timeEntries.sortedByDate.prefix(5))
    }

    private var outstandingInvoices: [Invoice] {
        Array(invoices.filter { $0.status == .verzonden || $0.status == .herinnering }
            .sorted { $0.vervaldatum < $1.vervaldatum }
            .prefix(5))
    }

    private var clientsWithUninvoicedWork: [(client: Client, entries: [TimeEntry], amount: Decimal)] {
        clients
            .filter { $0.isActive }
            .compactMap { client -> (client: Client, entries: [TimeEntry], amount: Decimal)? in
                let unbilled = client.unbilledEntries
                guard !unbilled.isEmpty else { return nil }
                let amount = client.unbilledAmount
                return (client, unbilled, amount)
            }
            .sorted { $0.amount > $1.amount }
    }

    private var totalUninvoicedAmount: Decimal {
        clientsWithUninvoicedWork.reduce(0) { $0 + $1.amount }
    }

    private var revenueChartAccessibilityDescription: String {
        guard !monthlyRevenue.isEmpty else { return "Geen gegevens" }

        let highestMonth = monthlyRevenue.max(by: { $0.revenue < $1.revenue })
        let lowestMonth = monthlyRevenue.min(by: { $0.revenue < $1.revenue })
        let totalRevenue = monthlyRevenue.reduce(0.0) { $0 + $1.revenue }

        var description = "Totale omzet: \(Decimal(totalRevenue).asCurrency). "

        if let highest = highestMonth, let lowest = lowestMonth {
            description += "Hoogste maand: \(highest.monthName) met \(Decimal(highest.revenue).asCurrency). "
            description += "Laagste maand: \(lowest.monthName) met \(Decimal(lowest.revenue).asCurrency)."
        }

        return description
    }
}

// MARK: - Recent Activity Row
struct RecentActivityRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.bedrijfsnaam ?? entry.activiteit)
                    .font(.subheadline.weight(.medium))
                Text(entry.datumFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.totaalbedrag.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(entry.isBillable ? .primary : .secondary)
                Text("\(entry.uren.asDecimal) uur")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Outstanding Invoice Row
struct OutstandingInvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.factuurnummer)
                    .font(.subheadline.weight(.medium))
                Text(invoice.client?.bedrijfsnaam ?? "Onbekend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(invoice.totaalbedrag.asCurrency)
                    .font(.subheadline.weight(.medium))

                if invoice.isOverdue {
                    Text("\(abs(invoice.daysUntilDue)) dagen te laat")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Vervalt \(invoice.vervaldatumFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Uninvoiced Client Card
struct UninvoicedClientCard: View {
    let client: Client
    let entries: [TimeEntry]
    let amount: Decimal
    let onCreateInvoice: () -> Void

    private var oldestEntryDays: Int {
        guard let oldest = entries.map({ $0.datum }).min() else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(client.bedrijfsnaam)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entries.count) registraties")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if oldestEntryDays > 30 {
                        Text("\(oldestEntryDays) dagen oud")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Text(amount.asCurrency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.purple)
            }

            Button("Factureer") {
                onCreateInvoice()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Factureer \(client.bedrijfsnaam)")
            .accessibilityHint("Maakt een nieuwe factuur aan voor deze klant met de openstaande registraties")
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
