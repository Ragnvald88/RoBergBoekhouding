import SwiftUI
import PDFKit
import AppKit

/// Native PDF viewer using PDFKit
struct PDFViewerView: NSViewRepresentable {
    let pdfData: Data?
    let pdfURL: URL?

    init(data: Data) {
        self.pdfData = data
        self.pdfURL = nil
    }

    init(url: URL) {
        self.pdfData = nil
        self.pdfURL = url
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .windowBackgroundColor
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let data = pdfData {
            pdfView.document = PDFDocument(data: data)
        } else if let url = pdfURL {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - PDF Viewer Window

/// A complete PDF viewer window with toolbar controls
struct PDFViewerWindowView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let pdfData: Data?
    let pdfURL: URL?

    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var zoomLevel: CGFloat = 1.0

    init(title: String, data: Data) {
        self.title = title
        self.pdfData = data
        self.pdfURL = nil
    }

    init(title: String, url: URL) {
        self.title = title
        self.pdfData = nil
        self.pdfURL = url
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                // Page indicator
                if totalPages > 1 {
                    Text("Pagina \(currentPage) van \(totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button {
                        printPDF()
                    } label: {
                        Image(systemName: "printer")
                    }
                    .buttonStyle(.borderless)
                    .help("Afdrukken")

                    Button {
                        openInFinder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Toon in Finder")

                    Button("Sluiten") {
                        dismiss()
                    }
                }
            }
            .padding()

            Divider()

            // PDF Content
            if let data = pdfData {
                PDFViewerView(data: data)
            } else if let url = pdfURL {
                PDFViewerView(url: url)
            } else {
                ContentUnavailableView(
                    "Geen PDF beschikbaar",
                    systemImage: "doc.questionmark",
                    description: Text("Het PDF bestand kon niet worden geladen.")
                )
            }
        }
        .frame(minWidth: 600, minHeight: 800)
        .onAppear {
            loadPageCount()
        }
    }

    private func loadPageCount() {
        var document: PDFDocument?

        if let data = pdfData {
            document = PDFDocument(data: data)
        } else if let url = pdfURL {
            document = PDFDocument(url: url)
        }

        totalPages = document?.pageCount ?? 1
    }

    private func printPDF() {
        var document: PDFDocument?

        if let data = pdfData {
            document = PDFDocument(data: data)
        } else if let url = pdfURL {
            document = PDFDocument(url: url)
        }

        guard let doc = document else { return }

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic

        let printOperation = doc.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true)
        printOperation?.run()
    }

    private func openInFinder() {
        if let url = pdfURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

// MARK: - PDF Thumbnail View

/// Small PDF thumbnail for list views
struct PDFThumbnailView: View {
    let pdfURL: URL?
    let size: CGFloat

    @State private var thumbnail: NSImage?

    init(url: URL?, size: CGFloat = 40) {
        self.pdfURL = url
        self.size = size
    }

    var body: some View {
        Group {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(radius: 1)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let url = pdfURL,
              let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale = size / min(pageRect.width, pageRect.height)
        let thumbnailSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
    }
}

// MARK: - PDF Indicator Badge

/// Badge to show PDF availability in lists
struct PDFIndicatorBadge: View {
    let hasGeneratedPDF: Bool
    let hasImportedPDF: Bool

    var body: some View {
        HStack(spacing: 2) {
            if hasGeneratedPDF {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                    .help("Gegenereerde PDF beschikbaar")
            }
            if hasImportedPDF {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .help("Originele import beschikbaar")
            }
        }
    }
}

// MARK: - Preview

#Preview("PDF Viewer") {
    // Create a simple test PDF
    let pdfData: Data? = {
        let document = PDFDocument()
        let page = PDFPage()
        document.insert(page, at: 0)
        return document.dataRepresentation()
    }()

    if let data = pdfData {
        PDFViewerWindowView(title: "Test PDF", data: data)
    } else {
        Text("Could not create preview PDF")
    }
}

#Preview("PDF Indicator") {
    VStack(spacing: 20) {
        HStack {
            Text("Factuur 2025-001")
            Spacer()
            PDFIndicatorBadge(hasGeneratedPDF: true, hasImportedPDF: false)
        }

        HStack {
            Text("Factuur 2025-002")
            Spacer()
            PDFIndicatorBadge(hasGeneratedPDF: false, hasImportedPDF: true)
        }

        HStack {
            Text("Factuur 2025-003")
            Spacer()
            PDFIndicatorBadge(hasGeneratedPDF: true, hasImportedPDF: true)
        }
    }
    .padding()
    .frame(width: 300)
}
