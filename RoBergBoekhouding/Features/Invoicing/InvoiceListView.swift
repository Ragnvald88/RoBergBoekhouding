import SwiftUI
import SwiftData

struct InvoiceListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Invoice.factuurdatum, order: .reverse) private var allInvoices: [Invoice]

    @State private var selectedInvoice: Invoice?
    @State private var statusFilter: InvoiceStatus?
    @State private var invoiceToDelete: Invoice?

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

                // List
                if filteredInvoices.isEmpty {
                    ContentUnavailableView(
                        "Geen facturen",
                        systemImage: "doc.text",
                        description: Text("Klik op 'Nieuwe Factuur' om te beginnen")
                    )
                } else {
                    List(filteredInvoices, selection: $selectedInvoice) { invoice in
                        InvoiceRow(invoice: invoice) {
                            invoiceToDelete = invoice
                        }
                        .tag(invoice)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 350, idealWidth: 400)

            // Detail View
            if let invoice = selectedInvoice {
                InvoiceDetailView(invoice: invoice) {
                    invoiceToDelete = invoice
                }
            } else {
                ContentUnavailableView(
                    "Selecteer een factuur",
                    systemImage: "doc.text",
                    description: Text("Kies een factuur uit de lijst om details te bekijken")
                )
            }
        }
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
        .alert("Factuur verwijderen", isPresented: Binding(
            get: { invoiceToDelete != nil },
            set: { if !$0 { invoiceToDelete = nil } }
        )) {
            Button("Annuleren", role: .cancel) {
                invoiceToDelete = nil
            }
            Button("Verwijderen", role: .destructive) {
                if let invoice = invoiceToDelete {
                    deleteInvoice(invoice)
                }
            }
        } message: {
            if let invoice = invoiceToDelete {
                Text("Weet je zeker dat je factuur \(invoice.factuurnummer) wilt verwijderen? Dit verwijdert ook alle bijbehorende PDF bestanden.")
            }
        }
    }

    // MARK: - Delete Invoice
    private func deleteInvoice(_ invoice: Invoice) {
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

        // Clear selection if this invoice was selected
        if selectedInvoice?.id == invoice.id {
            selectedInvoice = nil
        }

        // Delete the invoice
        modelContext.delete(invoice)
        try? modelContext.save()

        invoiceToDelete = nil
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
    let invoice: Invoice
    let onDelete: () -> Void

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
            if invoice.hasGeneratedPdf {
                Button {
                    invoice.openGeneratedPdf()
                } label: {
                    Label("Open PDF", systemImage: "doc.fill")
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
                    // Status submenu
                    Menu {
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
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

                StatusBadge(status: invoice.status)
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

            // Header
            HStack {
                Text("Datum")
                    .frame(width: 60, alignment: .leading)
                Text("Omschrijving")
                Spacer()
                Text("Aantal")
                    .frame(width: 60, alignment: .trailing)
                Text("Tarief")
                    .frame(width: 80, alignment: .trailing)
                Text("Bedrag")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Divider()

            // Items
            ForEach(invoice.lineItems) { item in
                HStack {
                    Text(item.datum)
                        .frame(width: 60, alignment: .leading)
                    Text(item.omschrijving)
                    Spacer()
                    Text("\(item.aantal.asDecimal) \(item.eenheid)")
                        .frame(width: 60, alignment: .trailing)
                    Text(item.tarief.asCurrency)
                        .frame(width: 80, alignment: .trailing)
                    Text(item.bedrag.asCurrency)
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.subheadline)
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
