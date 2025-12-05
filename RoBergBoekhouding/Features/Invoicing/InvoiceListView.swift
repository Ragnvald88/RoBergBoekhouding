import SwiftUI
import SwiftData

struct InvoiceListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Invoice.factuurdatum, order: .reverse) private var allInvoices: [Invoice]

    @State private var selectedInvoiceIDs: Set<Invoice.ID> = []
    @State private var statusFilter: InvoiceStatus?
    @State private var invoicesToDelete: [Invoice] = []
    @State private var showDeleteAlert = false
    @State private var invoiceForPDFPreview: Invoice?
    @State private var showPDFPreview = false

    private var filteredInvoices: [Invoice] {
        var invoices = allInvoices.filterByYear(appState.selectedYear)

        if let status = statusFilter {
            invoices = invoices.filterByStatus(status)
        }

        if !appState.searchText.isEmpty {
            invoices = invoices.filter {
                $0.factuurnummer.localizedCaseInsensitiveContains(appState.searchText) ||
                $0.client?.bedrijfsnaam.localizedCaseInsensitiveContains(appState.searchText) == true
            }
        }

        return invoices
    }

    /// Currently selected invoices based on IDs
    private var selectedInvoices: [Invoice] {
        filteredInvoices.filter { selectedInvoiceIDs.contains($0.id) }
    }

    /// Single selected invoice for detail view (first selected)
    private var selectedInvoice: Invoice? {
        guard let firstID = selectedInvoiceIDs.first else { return nil }
        return filteredInvoices.first { $0.id == firstID }
    }

    var body: some View {
        HSplitView {
            // Invoice List
            VStack(spacing: 0) {
                // Summary Bar
                summaryBar

                Divider()

                // Filter Bar
                filterBar

                Divider()

                // List - use frame with maxHeight to ensure proper sizing
                if filteredInvoices.isEmpty {
                    ContentUnavailableView(
                        "Geen facturen",
                        systemImage: "doc.text",
                        description: Text("Klik op 'Nieuwe Factuur' om te beginnen")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredInvoices, id: \.id, selection: $selectedInvoiceIDs) { invoice in
                        InvoiceRow(
                            invoice: invoice,
                            onDelete: {
                                invoicesToDelete = [invoice]
                                showDeleteAlert = true
                            },
                            onShowPDF: {
                                invoiceForPDFPreview = invoice
                                showPDFPreview = true
                            },
                            onNewInvoice: {
                                appState.showNewInvoice = true
                            }
                        )
                        .tag(invoice.id)
                    }
                    .listStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 350, idealWidth: 400, maxWidth: 500)
            .frame(maxHeight: .infinity)

            // Detail View
            if selectedInvoiceIDs.count > 1 {
                // Multiple selection view
                multipleSelectionView
            } else if let invoice = selectedInvoice {
                InvoiceDetailView(invoice: invoice) {
                    invoicesToDelete = [invoice]
                    showDeleteAlert = true
                }
            } else {
                ContentUnavailableView(
                    "Selecteer een factuur",
                    systemImage: "doc.text",
                    description: Text("Kies een factuur uit de lijst om details te bekijken")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Facturen")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Jaar", selection: $appState.selectedYear) {
                    ForEach(appState.availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 80)

                Button("Nieuwe Factuur", systemImage: "plus") {
                    appState.showNewInvoice = true
                }
            }
        }
        .searchable(text: $appState.searchText, prompt: "Zoek factuur")
        .sheet(isPresented: $appState.showNewInvoice) {
            InvoiceGeneratorView()
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteAlert) {
            Button("Annuleren", role: .cancel) {
                invoicesToDelete = []
            }
            Button("Verwijderen", role: .destructive) {
                deleteInvoices(invoicesToDelete)
            }
        } message: {
            Text(deleteAlertMessage)
        }
        .sheet(isPresented: $showPDFPreview) {
            if let invoice = invoiceForPDFPreview {
                InvoicePreviewView(invoice: invoice)
            }
        }
    }

    // MARK: - Delete Alert Text
    private var deleteAlertTitle: String {
        if invoicesToDelete.count == 1 {
            return "Factuur verwijderen"
        } else {
            return "\(invoicesToDelete.count) facturen verwijderen"
        }
    }

    private var deleteAlertMessage: String {
        if invoicesToDelete.count == 1, let invoice = invoicesToDelete.first {
            return "Weet je zeker dat je factuur \(invoice.factuurnummer) wilt verwijderen? Dit verwijdert ook alle bijbehorende PDF bestanden."
        } else {
            let numbers = invoicesToDelete.map { $0.factuurnummer }.joined(separator: ", ")
            return "Weet je zeker dat je \(invoicesToDelete.count) facturen wilt verwijderen? (\(numbers)) Dit verwijdert ook alle bijbehorende PDF bestanden."
        }
    }

    // MARK: - Multiple Selection View
    private var multipleSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("\(selectedInvoices.count) facturen geselecteerd")
                .font(.title2.weight(.medium))

            // Summary of selected invoices
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Totaal bedrag:")
                    Spacer()
                    Text(selectedInvoices.reduce(Decimal.zero) { $0 + $1.totaalbedrag }.asCurrency)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Facturen:")
                    Spacer()
                    Text(selectedInvoices.map { $0.factuurnummer }.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 400)

            // Bulk status change
            VStack(spacing: 8) {
                Text("Status wijzigen naar:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(InvoiceStatus.allCases, id: \.self) { status in
                        Button {
                            bulkUpdateStatus(status)
                        } label: {
                            Text(status.displayName)
                        }
                        .buttonStyle(.bordered)
                        .tint(statusColor(status))
                    }
                }
            }

            Divider()
                .frame(maxWidth: 300)

            // Bulk actions
            HStack(spacing: 16) {
                Button(role: .destructive) {
                    invoicesToDelete = selectedInvoices
                    showDeleteAlert = true
                } label: {
                    Label("Verwijder selectie", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button {
                    selectedInvoiceIDs.removeAll()
                } label: {
                    Label("Deselecteer alles", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bulkUpdateStatus(_ status: InvoiceStatus) {
        for invoice in selectedInvoices {
            invoice.updateStatus(status)
        }
        try? modelContext.save()
    }

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .concept: return .gray
        case .verzonden: return .orange
        case .betaald: return .green
        case .herinnering: return .red
        case .oninbaar: return .purple
        }
    }

    // MARK: - Delete Invoices
    private func deleteInvoices(_ invoices: [Invoice]) {
        for invoice in invoices {
            // Delete associated PDFs
            invoice.deleteAllPdfs()

            // Unlink time entries
            if let entries = invoice.timeEntries {
                for entry in entries {
                    entry.isInvoiced = false
                    entry.factuurnummer = nil
                    entry.invoice = nil
                }
            }

            // Remove from selection
            selectedInvoiceIDs.remove(invoice.id)

            // Delete the invoice
            modelContext.delete(invoice)
        }

        try? modelContext.save()
        invoicesToDelete = []
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Totaal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredInvoices.totalAmount.asCurrency)
                    .font(.subheadline.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Betaald")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredInvoices.totalPaid.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Openstaand")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(filteredInvoices.totalOutstanding.asCurrency)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "Alle",
                    isSelected: statusFilter == nil,
                    action: { statusFilter = nil }
                )

                ForEach(InvoiceStatus.allCases, id: \.self) { status in
                    FilterChip(
                        label: status.displayName,
                        count: filteredInvoices.countByStatus(status),
                        isSelected: statusFilter == status,
                        action: { statusFilter = status }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Invoice Row
struct InvoiceRow: View {
    @Environment(\.modelContext) private var modelContext
    let invoice: Invoice
    let onDelete: () -> Void
    let onShowPDF: () -> Void
    var onNewInvoice: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.factuurnummer)
                        .font(.subheadline.weight(.medium))

                    // PDF indicator
                    PDFIndicatorBadge(
                        hasGeneratedPDF: invoice.hasGeneratedPdf,
                        hasImportedPDF: invoice.hasImportedPdf
                    )

                    Spacer()

                    Text(invoice.totaalbedrag.asCurrency)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                }

                HStack {
                    Text(invoice.client?.bedrijfsnaam ?? "Onbekend")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(invoice.factuurdatumFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if invoice.isOverdue {
                    Text("\(abs(invoice.daysUntilDue)) dagen te laat")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // New invoice option
            if let onNewInvoice {
                Button {
                    onNewInvoice()
                } label: {
                    Label("Nieuwe factuur", systemImage: "plus")
                }

                Divider()
            }

            // PDF Preview - always available
            Button {
                onShowPDF()
            } label: {
                Label("PDF voorvertoning", systemImage: "doc.richtext")
            }

            if invoice.hasGeneratedPdf {
                Button {
                    invoice.openGeneratedPdf()
                } label: {
                    Label("Open opgeslagen PDF", systemImage: "doc.fill")
                }
            }

            if invoice.hasImportedPdf {
                Button {
                    invoice.openImportedPdf()
                } label: {
                    Label("Open originele import", systemImage: "arrow.down.doc.fill")
                }
            }

            Divider()

            // Status change submenu
            Menu {
                ForEach(invoice.status.otherStatuses, id: \.self) { status in
                    Button {
                        invoice.updateStatus(status)
                        try? modelContext.save()
                    } label: {
                        Label(status.displayName, systemImage: statusIcon(status))
                    }
                }
            } label: {
                Label("Status wijzigen", systemImage: "flag")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Verwijderen", systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        switch invoice.status {
        case .concept: return .gray
        case .verzonden: return .orange
        case .betaald: return .green
        case .herinnering: return .red
        case .oninbaar: return .purple
        }
    }

    private func statusIcon(_ status: InvoiceStatus) -> String {
        switch status {
        case .concept: return "doc"
        case .verzonden: return "paperplane"
        case .betaald: return "checkmark.circle"
        case .herinnering: return "exclamationmark.triangle"
        case .oninbaar: return "xmark.circle"
        }
    }
}

// MARK: - Invoice Detail View
struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let invoice: Invoice
    let onDelete: () -> Void

    @State private var showingStatusPicker = false
    @State private var showingPDFPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // PDF Actions (if any PDF available)
                if invoice.hasPdf {
                    pdfActionsSection
                }

                Divider()

                // Client Info
                clientSection

                Divider()

                // Line Items
                lineItemsSection

                Divider()

                // Totals
                totalsSection
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // PDF Preview/Export button
                Button("PDF", systemImage: "doc.richtext") {
                    showingPDFPreview = true
                }

                // Actions Menu
                Menu {
                    // Status submenu - show all other statuses
                    Menu {
                        ForEach(invoice.status.otherStatuses, id: \.self) { status in
                            Button(status.displayName) {
                                updateStatus(status)
                            }
                        }
                    } label: {
                        Label("Status wijzigen", systemImage: "flag")
                    }

                    Divider()

                    // Delete action
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Verwijderen", systemImage: "trash")
                    }
                } label: {
                    Label("Acties", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            InvoicePreviewView(invoice: invoice)
        }
    }

    // MARK: - PDF Actions Section
    private var pdfActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PDF Documenten")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if invoice.hasGeneratedPdf {
                    Button {
                        invoice.openGeneratedPdf()
                    } label: {
                        Label("Open PDF", systemImage: "doc.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                if invoice.hasImportedPdf {
                    Button {
                        invoice.openImportedPdf()
                    } label: {
                        Label("Originele import", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.factuurnummer)
                    .font(.title.weight(.bold))

                InvoiceStatusBadge(status: invoice.status)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Factuurdatum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(invoice.factuurdatumFormatted)
                    .font(.subheadline)

                Text("Vervaldatum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(invoice.vervaldatumFormatted)
                    .font(.subheadline)
                    .foregroundStyle(invoice.isOverdue ? .red : .primary)
            }
        }
    }

    // MARK: - Client Section
    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Klant")
                .font(.headline)

            if let client = invoice.client {
                VStack(alignment: .leading, spacing: 2) {
                    if let contact = client.contactpersoon {
                        Text(contact)
                            .font(.subheadline)
                    }
                    Text(client.bedrijfsnaam)
                        .font(.subheadline.weight(.medium))
                    Text(client.fullAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Onbekende klant")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Line Items Section
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regels")
                .font(.headline)

            if invoice.lineItems.isEmpty {
                Text("Geen regels gevonden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Responsive table using Grid
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    // Header row
                    GridRow {
                        Text("Datum")
                        Text("Omschrijving")
                        Text("Aantal")
                            .gridColumnAlignment(.trailing)
                        Text("Bedrag")
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                    Divider()
                        .gridCellColumns(4)

                    // Data rows
                    ForEach(invoice.lineItems) { item in
                        GridRow {
                            Text(item.datum)
                                .font(.caption)
                            Text(item.omschrijving)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("\(item.aantal.asDecimal) \(item.eenheid)")
                                .font(.caption.monospacedDigit())
                            Text(item.bedrag.asCurrency)
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Totals Section
    private var totalsSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text("Totaal uren")
                Spacer()
                Text(invoice.totaalUrenBedrag.asCurrency)
            }
            .font(.subheadline)

            HStack {
                Text("Totaal kilometers")
                Spacer()
                Text(invoice.totaalKmBedrag.asCurrency)
            }
            .font(.subheadline)

            Divider()

            HStack {
                Text("TOTAAL")
                    .fontWeight(.bold)
                Spacer()
                Text(invoice.totaalbedrag.asCurrency)
                    .font(.title2.weight(.bold))
            }
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Methods
    private func updateStatus(_ status: InvoiceStatus) {
        invoice.updateStatus(status)
        try? modelContext.save()
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                if let count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    InvoiceListView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
