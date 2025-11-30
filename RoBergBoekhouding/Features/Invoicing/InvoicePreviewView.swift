import SwiftUI
import SwiftData
import WebKit

struct InvoicePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var settings: [BusinessSettings]

    let invoice: Invoice

    @State private var htmlContent: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingDeleteGeneratedAlert = false
    @State private var showingDeleteImportedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Factuur \(invoice.factuurnummer)")
                    .font(.headline)

                // PDF indicators
                PDFIndicatorBadge(
                    hasGeneratedPDF: invoice.hasGeneratedPdf,
                    hasImportedPDF: invoice.hasImportedPdf
                )

                Spacer()

                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.horizontal, 8)
                }

                // PDF action buttons with delete options
                if invoice.hasGeneratedPdf {
                    Menu {
                        Button {
                            invoice.openGeneratedPdf()
                        } label: {
                            Label("Open PDF", systemImage: "eye")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteGeneratedAlert = true
                        } label: {
                            Label("Verwijder PDF", systemImage: "trash")
                        }
                    } label: {
                        Label("PDF", systemImage: "doc.fill")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Gegenereerde PDF acties")
                }

                if invoice.hasImportedPdf {
                    Menu {
                        Button {
                            invoice.openImportedPdf()
                        } label: {
                            Label("Open origineel", systemImage: "eye")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteImportedAlert = true
                        } label: {
                            Label("Verwijder origineel", systemImage: "trash")
                        }
                    } label: {
                        Label("Import", systemImage: "arrow.down.doc.fill")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Geïmporteerde PDF acties")
                }

                // Save to app storage button
                if !invoice.hasGeneratedPdf {
                    Button("Opslaan") {
                        Task {
                            await savePDFToApp()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSaving)
                }

                Button("Exporteer PDF") {
                    exportPDF()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button("Sluiten") {
                    dismiss()
                }
            }
            .padding()
            .alert("Gegenereerde PDF verwijderen", isPresented: $showingDeleteGeneratedAlert) {
                Button("Annuleren", role: .cancel) { }
                Button("Verwijderen", role: .destructive) {
                    deleteGeneratedPdf()
                }
            } message: {
                Text("Weet je zeker dat je de gegenereerde PDF wilt verwijderen? Je kunt deze opnieuw genereren door te exporteren.")
            }
            .alert("Originele import verwijderen", isPresented: $showingDeleteImportedAlert) {
                Button("Annuleren", role: .cancel) { }
                Button("Verwijderen", role: .destructive) {
                    deleteImportedPdf()
                }
            } message: {
                Text("Weet je zeker dat je de originele geïmporteerde PDF wilt verwijderen? Dit kan niet ongedaan worden gemaakt.")
            }

            // Error message
            if let error = saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Sluiten") {
                        saveError = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }

            Divider()

            // Preview
            HTMLPreviewView(html: htmlContent)
        }
        .frame(width: 700, height: 900)
        .onAppear {
            generateHTML()
        }
    }

    private func generateHTML() {
        guard let businessSettings = settings.first else { return }
        let service = PDFGenerationService(settings: businessSettings)
        htmlContent = service.generateInvoiceHTML(for: invoice)
    }

    @MainActor
    private func savePDFToApp() async {
        guard let businessSettings = settings.first else {
            saveError = "Bedrijfsinstellingen niet gevonden"
            return
        }

        isSaving = true
        saveError = nil

        let service = PDFGenerationService(settings: businessSettings)

        do {
            _ = try await service.generateAndStorePDF(for: invoice, modelContext: modelContext)
        } catch {
            saveError = "Kon PDF niet opslaan: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Factuur_\(invoice.factuurnummer).pdf"
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await savePDFAsync(to: url)
                }
            }
        }
    }

    @MainActor
    private func savePDFAsync(to url: URL) async {
        guard let businessSettings = settings.first else {
            saveError = "Bedrijfsinstellingen niet gevonden"
            return
        }

        isSaving = true
        saveError = nil

        let service = PDFGenerationService(settings: businessSettings)

        do {
            // Generate, store in app documents, and export to user location
            _ = try await service.generateStoreAndExportPDF(for: invoice, to: url, modelContext: modelContext)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            saveError = "Kon PDF niet opslaan: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func deleteGeneratedPdf() {
        do {
            try invoice.deleteGeneratedPdf()
            try modelContext.save()
        } catch {
            saveError = "Kon PDF niet verwijderen: \(error.localizedDescription)"
        }
    }

    private func deleteImportedPdf() {
        do {
            try invoice.deleteImportedPdf()
            try modelContext.save()
        } catch {
            saveError = "Kon originele PDF niet verwijderen: \(error.localizedDescription)"
        }
    }
}

// MARK: - HTML Preview View
struct HTMLPreviewView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self, configurations: config)

    // Create sample data
    let settings = BusinessSettings()
    container.mainContext.insert(settings)

    let client = Client(
        bedrijfsnaam: "Huisartspraktijk Raupp",
        contactpersoon: "G.E.M. Raupp",
        adres: "Oostersingel 28",
        postcodeplaats: "9541 BK Vlagtwedde"
    )
    container.mainContext.insert(client)

    let invoice = Invoice(
        factuurnummer: "2025-001",
        status: .concept,
        client: client
    )
    container.mainContext.insert(invoice)

    return InvoicePreviewView(invoice: invoice)
        .modelContainer(container)
}
