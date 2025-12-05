import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var selectedImportType: ImportTypeOption = .clients
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var pdfImportResults: [PDFImportResult] = []
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var errorMessage: String?
    @State private var createInvoicesFromEntries = true

    enum ImportTypeOption: String, CaseIterable {
        case clients = "Klanten"
        case timeEntries = "Urenregistraties"
        case pdfInvoices = "PDF Facturen"

        var icon: String {
            switch self {
            case .clients: return "person.2"
            case .timeEntries: return "clock"
            case .pdfInvoices: return "doc.text"
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Gegevens importeren")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Import Type Selection
            Picker("Type", selection: $selectedImportType) {
                ForEach(ImportTypeOption.allCases, id: \.self) { option in
                    Label(option.rawValue, systemImage: option.icon).tag(option)
                }
            }
            .pickerStyle(.segmented)

            // Instructions
            instructionsView

            // Options
            optionsView

            // Error Message
            if let error = errorMessage {
                errorView(error)
            }

            // Results
            resultsView

            Spacer()

            // Buttons
            buttonsView
        }
        .padding()
        .frame(width: 550, height: 600)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: selectedImportType == .pdfInvoices
        ) { result in
            handleFileSelection(result)
        }
        .onChange(of: selectedImportType) { _, _ in
            importResult = nil
            pdfImportResults = []
            errorMessage = nil
        }
        .overlay {
            if isImporting {
                loadingOverlay
            }
        }
    }

    // MARK: - Subviews

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verwacht bestandsformaat:")
                .font(.subheadline.weight(.medium))

            switch selectedImportType {
            case .clients:
                VStack(alignment: .leading, spacing: 4) {
                    Text("CSV: ID;Bedrijfsnaam;Naam;Adres;Postcode_Plaats")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Bestand: klanten.csv")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            case .timeEntries:
                VStack(alignment: .leading, spacing: 4) {
                    Text("CSV: Datum;CODE;Klant;Activiteit;Locatie;Uren;...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Bestand: URENREGISTERexport.csv")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            case .pdfInvoices:
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF facturen met factuurnummer, klant, regels")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Selecteer een of meerdere PDF bestanden")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Ondersteunt 2024 en 2025 factuurformaten")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Divider()

            if selectedImportType == .pdfInvoices {
                Text("De app leest: factuurnummer, datum, klant, uren, km, tarieven, totalen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Ondersteunde coderingen: UTF-8, Windows-1252, ISO-8859-1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var optionsView: some View {
        if selectedImportType == .timeEntries {
            Toggle(isOn: $createInvoicesFromEntries) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Facturen aanmaken")
                        .font(.subheadline)
                    Text("Maak automatisch facturen aan voor entries met een factuurnummer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 4)
        }
    }

    private func errorView(_ error: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var resultsView: some View {
        // CSV Import Result
        if let result = importResult {
            csvResultView(result)
        }

        // PDF Import Results
        if !pdfImportResults.isEmpty {
            pdfResultsView
        }
    }

    private func csvResultView(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.errorMessages.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.errorMessages.isEmpty ? .green : .orange)
                Text(result.summary)
                    .font(.subheadline.weight(.medium))
            }

            if !result.infoMessages.isEmpty {
                ForEach(result.infoMessages, id: \.self) { message in
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text(message)
                            .font(.caption)
                    }
                }
            }

            if !result.errorMessages.isEmpty {
                Divider()
                Text("Fouten:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.errorMessages.prefix(10), id: \.self) { error in
                            Text("• \(error)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if result.errorMessages.count > 10 {
                            Text("... en \(result.errorMessages.count - 10) meer fouten")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var pdfResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let successCount = pdfImportResults.filter { $0.success }.count
            let failCount = pdfImportResults.count - successCount

            HStack {
                Image(systemName: failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(failCount == 0 ? .green : .orange)
                Text("\(successCount) facturen geïmporteerd")
                    .font(.subheadline.weight(.medium))
                if failCount > 0 {
                    Text("(\(failCount) mislukt)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Summary stats
            let totalAmount = pdfImportResults.filter { $0.success }.reduce(Decimal(0)) { $0 + $1.totalAmount }
            let totalEntries = pdfImportResults.filter { $0.success }.reduce(0) { $0 + $1.timeEntriesCreated }

            if totalAmount > 0 {
                HStack {
                    Image(systemName: "eurosign.circle.fill")
                        .foregroundStyle(.green)
                    Text("Totaal: \(totalAmount.asCurrency)")
                        .font(.caption)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(totalEntries) urenregistraties")
                        .font(.caption)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pdfImportResults, id: \.invoiceNumber) { result in
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(result.success ? .green : .red)
                                .font(.caption)
                            Text(result.invoiceNumber)
                                .font(.caption.monospaced())
                            if result.success {
                                Text("- \(result.totalAmount.asCurrency)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("- \(result.message)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var buttonsView: some View {
        HStack(spacing: 12) {
            // Cancel/Close button - always visible
            Button("Sluiten") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .help("Sluit dit venster (Esc)")

            Spacer()

            // Reset button - only after import
            if importResult != nil || !pdfImportResults.isEmpty {
                Button {
                    importResult = nil
                    pdfImportResults = []
                    errorMessage = nil
                } label: {
                    Label("Nog een import", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help("Start een nieuwe import")
            }

            // Primary action button
            Button {
                showingFilePicker = true
            } label: {
                Label(
                    selectedImportType == .pdfInvoices ? "Selecteer PDF's" : "Selecteer bestand",
                    systemImage: "folder"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)
            .help("Kies een bestand om te importeren")
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Importeren...")
                    .font(.subheadline)
                Text(selectedImportType == .pdfInvoices ?
                     "PDF facturen worden gelezen en verwerkt" :
                     "Even geduld, dit kan even duren bij grote bestanden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - File Types

    private var allowedFileTypes: [UTType] {
        switch selectedImportType {
        case .clients, .timeEntries:
            return [.commaSeparatedText, .plainText, .data]
        case .pdfInvoices:
            return [.pdf]
        }
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        errorMessage = nil
        importResult = nil
        pdfImportResults = []

        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                errorMessage = "Geen bestand geselecteerd"
                return
            }

            if selectedImportType == .pdfInvoices {
                performPDFImport(from: urls)
            } else {
                guard let url = urls.first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                performCSVImport(from: url, securityScoped: hasAccess)
            }

        case .failure(let error):
            errorMessage = "Fout bij selecteren: \(error.localizedDescription)"
        }
    }

    private func performCSVImport(from url: URL, securityScoped: Bool = false) {
        isImporting = true
        errorMessage = nil

        Task {
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let service = CSVImportService(modelContext: modelContext)

            do {
                let result: ImportResult
                switch selectedImportType {
                case .clients:
                    result = try await service.importClients(from: url)
                case .timeEntries:
                    result = try await service.importTimeEntries(from: url, createInvoices: createInvoicesFromEntries)
                case .pdfInvoices:
                    // Should not reach here
                    result = ImportResult(imported: 0, skipped: 0, errors: [], type: .clients)
                }

                await MainActor.run {
                    importResult = result
                    isImporting = false

                    if result.imported > 0 {
                        NotificationCenter.default.post(name: .dataImported, object: result)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import fout: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }

    private func performPDFImport(from urls: [URL]) {
        isImporting = true
        errorMessage = nil

        // Run on main thread since PDFInvoiceImportService is @MainActor
        Task { @MainActor in
            let service = PDFInvoiceImportService(modelContext: modelContext)
            var results: [PDFImportResult] = []

            for url in urls {
                let hasAccess = url.startAccessingSecurityScopedResource()

                do {
                    let result = try service.importInvoice(from: url)
                    results.append(result)
                } catch {
                    results.append(PDFImportResult(
                        success: false,
                        invoiceNumber: url.lastPathComponent,
                        message: error.localizedDescription,
                        timeEntriesCreated: 0,
                        totalAmount: 0
                    ))
                }

                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            pdfImportResults = results
            isImporting = false

            let successCount = results.filter { $0.success }.count
            if successCount > 0 {
                NotificationCenter.default.post(name: .dataImported, object: results)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImportView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
