import SwiftUI
import SwiftData

struct ClientListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Client.bedrijfsnaam) private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var showingDeleteAlert = false
    @State private var clientToDelete: Client?

    private var filteredClients: [Client] {
        if appState.searchText.isEmpty {
            return clients
        }
        return clients.filter {
            $0.bedrijfsnaam.localizedCaseInsensitiveContains(appState.searchText) ||
            $0.contactpersoon?.localizedCaseInsensitiveContains(appState.searchText) == true ||
            $0.postcodeplaats.localizedCaseInsensitiveContains(appState.searchText)
        }
    }

    private var activeClients: [Client] {
        filteredClients.filter { $0.isActive }
    }

    private var inactiveClients: [Client] {
        filteredClients.filter { !$0.isActive }
    }

    var body: some View {
        HSplitView {
            // Client List
            VStack(spacing: 0) {
                // Summary
                HStack {
                    Text("\(activeClients.count) actieve klanten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)

                // List
                List(selection: $selectedClient) {
                    if !activeClients.isEmpty {
                        Section("Actief") {
                            ForEach(activeClients) { client in
                                ClientRow(client: client)
                                    .tag(client)
                            }
                        }
                    }

                    if !inactiveClients.isEmpty {
                        Section("Inactief") {
                            ForEach(inactiveClients) { client in
                                ClientRow(client: client)
                                    .tag(client)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            .frame(maxHeight: .infinity)

            // Detail View
            if let client = selectedClient {
                ClientDetailView(client: client)
            } else {
                ContentUnavailableView(
                    "Selecteer een klant",
                    systemImage: "person.2",
                    description: Text("Kies een klant uit de lijst om details te bekijken")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Klanten")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nieuwe Klant", systemImage: "plus") {
                    appState.showNewClient = true
                }
            }
        }
        .searchable(text: $appState.searchText, prompt: "Zoek klant")
        .sheet(isPresented: $appState.showNewClient) {
            ClientFormView(client: nil)
        }
    }
}

// MARK: - Client Row
struct ClientRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: client.clientType == .anwDienst ? "cross.case.fill" : "building.2")
                .font(.title3)
                .foregroundStyle(client.isActive ? .blue : .gray)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(client.bedrijfsnaam)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(client.isActive ? .primary : .secondary)

                    Spacer()

                    // Unbilled indicator
                    if client.unbilledAmount > 0 {
                        Text(client.unbilledAmount.asCurrency)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                if let contact = client.contactpersoon, !contact.isEmpty {
                    Text(contact)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label("\(client.afstandRetour) km", systemImage: "car")
                    Label(client.standaardUurtarief.asCurrency, systemImage: "eurosign")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    let client: Client

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Stats
                statsSection

                Divider()

                // Details
                detailsSection

                // Recent Entries
                if let entries = client.timeEntries, !entries.isEmpty {
                    Divider()
                    recentEntriesSection(entries: entries)
                }

                // Recent Invoices
                if let invoices = client.invoices, !invoices.isEmpty {
                    Divider()
                    recentInvoicesSection(invoices: invoices)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Bewerken") {
                        showingEditSheet = true
                    }

                    Divider()

                    Button(client.isActive ? "Deactiveren" : "Activeren") {
                        toggleActive()
                    }

                    Divider()

                    Button("Verwijderen", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Label("Acties", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ClientFormView(client: client)
        }
        .alert("Klant verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteClient()
            }
        } message: {
            Text(deleteWarningMessage)
        }
    }

    private var deleteWarningMessage: String {
        var message = "Weet je zeker dat je '\(client.bedrijfsnaam)' wilt verwijderen?"

        let entryCount = client.timeEntries?.count ?? 0
        let invoiceCount = client.invoices?.count ?? 0

        if entryCount > 0 || invoiceCount > 0 {
            message += "\n\nDit verwijdert ook:"
            if entryCount > 0 {
                message += "\n• \(entryCount) urenregistratie\(entryCount == 1 ? "" : "s")"
            }
            if invoiceCount > 0 {
                message += "\n• \(invoiceCount) factu\(invoiceCount == 1 ? "ur" : "ren")"
            }
        }

        message += "\n\nDit kan niet ongedaan worden gemaakt."
        return message
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: client.clientType == .anwDienst ? "cross.case.fill" : "building.2")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(client.bedrijfsnaam)
                    .font(.title2.weight(.semibold))

                if let contact = client.contactpersoon, !contact.isEmpty {
                    Text(contact)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(client.clientType.displayName, systemImage: "tag")
                    if !client.isActive {
                        Label("Inactief", systemImage: "pause.circle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 20) {
            KPICardCompactView(
                title: "Totale omzet",
                value: client.totalRevenue.asCurrency,
                icon: "eurosign.circle",
                color: .green
            )

            KPICardCompactView(
                title: "Totaal uren",
                value: "\(client.totalHours.asDecimal)",
                icon: "clock",
                color: .blue
            )

            KPICardCompactView(
                title: "Totaal km",
                value: "\(client.totalKilometers.formatted)",
                icon: "car",
                color: .orange
            )

            if client.unbilledAmount > 0 {
                KPICardCompactView(
                    title: "Openstaand",
                    value: client.unbilledAmount.asCurrency,
                    icon: "doc.text",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gegevens")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Adres")
                        .foregroundStyle(.secondary)
                    Text(client.fullAddress)
                }

                if let telefoon = client.telefoon, !telefoon.isEmpty {
                    GridRow {
                        Text("Telefoon")
                            .foregroundStyle(.secondary)
                        Text(telefoon)
                    }
                }

                if let email = client.email, !email.isEmpty {
                    GridRow {
                        Text("Email")
                            .foregroundStyle(.secondary)
                        Text(email)
                    }
                }

                GridRow {
                    Text("Standaard uurtarief")
                        .foregroundStyle(.secondary)
                    Text(client.standaardUurtarief.asCurrency)
                }

                GridRow {
                    Text("Kilometertarief")
                        .foregroundStyle(.secondary)
                    Text(client.standaardKmTarief.asCurrency)
                }

                GridRow {
                    Text("Retourafstand")
                        .foregroundStyle(.secondary)
                    Text("\(client.afstandRetour) km")
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: - Recent Entries Section
    private func recentEntriesSection(entries: [TimeEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recente registraties")
                    .font(.headline)
                Spacer()
                Button("Bekijk alles") {
                    appState.selectedSidebarItem = .urenregistratie
                }
                .font(.caption)
            }

            ForEach(Array(entries.sortedByDate.prefix(5))) { entry in
                HStack {
                    Text(entry.datumFormatted)
                        .font(.subheadline)
                    Spacer()
                    Text("\(entry.uren.asDecimal) uur")
                        .font(.subheadline)
                    Text(entry.totaalbedrag.asCurrency)
                        .font(.subheadline.monospacedDigit())
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recent Invoices Section
    private func recentInvoicesSection(invoices: [Invoice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recente facturen")
                    .font(.headline)
                Spacer()
                Button("Bekijk alles") {
                    appState.selectedSidebarItem = .facturen
                }
                .font(.caption)
            }

            ForEach(Array(invoices.sortedByDate.prefix(5))) { invoice in
                HStack {
                    Text(invoice.factuurnummer)
                        .font(.subheadline)
                    Text(invoice.factuurdatumFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(invoice.totaalbedrag.asCurrency)
                        .font(.subheadline.monospacedDigit())
                    StatusBadge(status: invoice.status)
                }
            }
        }
    }

    // MARK: - Methods
    private func toggleActive() {
        client.isActive.toggle()
        client.updateTimestamp()
        try? modelContext.save()
    }

    private func deleteClient() {
        modelContext.delete(client)
        try? modelContext.save()
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: InvoiceStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .concept: return .gray.opacity(0.2)
        case .verzonden: return .orange.opacity(0.2)
        case .betaald: return .green.opacity(0.2)
        case .herinnering: return .red.opacity(0.2)
        case .oninbaar: return .purple.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .concept: return .gray
        case .verzonden: return .orange
        case .betaald: return .green
        case .herinnering: return .red
        case .oninbaar: return .purple
        }
    }
}

// MARK: - Preview
#Preview {
    ClientListView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
