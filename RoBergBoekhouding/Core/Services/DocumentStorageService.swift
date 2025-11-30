import Foundation
import AppKit

/// Centralized service for managing persistent document storage (PDFs, receipts, etc.)
class DocumentStorageService {
    static let shared = DocumentStorageService()

    // MARK: - Document Types

    enum DocumentType: String {
        case invoice = "Invoices"
        case expense = "Expenses"
        case importedPDF = "Imports"
    }

    // MARK: - Errors

    enum StorageError: LocalizedError {
        case cannotCreateDirectory
        case cannotWriteFile
        case fileNotFound
        case invalidPath

        var errorDescription: String? {
            switch self {
            case .cannotCreateDirectory:
                return "Kan documentenmap niet aanmaken"
            case .cannotWriteFile:
                return "Kan bestand niet opslaan"
            case .fileNotFound:
                return "Bestand niet gevonden"
            case .invalidPath:
                return "Ongeldig bestandspad"
            }
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    /// Default documents directory in Application Support
    var defaultDocumentsDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to user's home directory if Application Support unavailable
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/RoBergBoekhouding", isDirectory: true)
        }
        return appSupport.appendingPathComponent("RoBergBoekhouding/Documents", isDirectory: true)
    }

    // MARK: - Public Methods

    /// Get the base documents directory (custom or default)
    func documentsDirectory(customPath: String? = nil) -> URL {
        if let custom = customPath, !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        return defaultDocumentsDirectory
    }

    /// Store a PDF and return the relative path for database storage
    /// - Parameters:
    ///   - data: The PDF data to store
    ///   - type: Type of document (invoice, expense, import)
    ///   - identifier: Unique identifier (e.g., invoice number, expense ID)
    ///   - year: Year for folder organization
    ///   - customBasePath: Optional custom base path (from settings)
    /// - Returns: Relative path to the stored file (for database storage)
    func storePDF(
        _ data: Data,
        type: DocumentType,
        identifier: String,
        year: Int,
        customBasePath: String? = nil
    ) throws -> String {
        let baseDir = documentsDirectory(customPath: customBasePath)
        let typeDir = baseDir.appendingPathComponent(type.rawValue, isDirectory: true)
        let yearDir = typeDir.appendingPathComponent(String(year), isDirectory: true)

        // Create directory structure
        try createDirectoryIfNeeded(at: yearDir)

        // Sanitize filename
        let safeIdentifier = identifier.replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeIdentifier).pdf"
        let fileURL = yearDir.appendingPathComponent(filename)

        // Write file
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StorageError.cannotWriteFile
        }

        // Return relative path for storage
        return "\(type.rawValue)/\(year)/\(filename)"
    }

    /// Retrieve PDF data from a relative path
    /// - Parameters:
    ///   - relativePath: Relative path as stored in database
    ///   - customBasePath: Optional custom base path (from settings)
    /// - Returns: PDF data if found
    func retrievePDF(at relativePath: String, customBasePath: String? = nil) -> Data? {
        guard let url = url(for: relativePath, customBasePath: customBasePath) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    /// Get the full URL for a relative path
    /// - Parameters:
    ///   - relativePath: Relative path as stored in database
    ///   - customBasePath: Optional custom base path (from settings)
    /// - Returns: Full URL to the file
    func url(for relativePath: String, customBasePath: String? = nil) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        let baseDir = documentsDirectory(customPath: customBasePath)
        let fullURL = baseDir.appendingPathComponent(relativePath)

        // Verify file exists
        guard fileManager.fileExists(atPath: fullURL.path) else {
            return nil
        }

        return fullURL
    }

    /// Check if a document exists at the given relative path
    func documentExists(at relativePath: String, customBasePath: String? = nil) -> Bool {
        guard !relativePath.isEmpty else { return false }
        let baseDir = documentsDirectory(customPath: customBasePath)
        let fullURL = baseDir.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: fullURL.path)
    }

    /// Delete a stored PDF
    /// - Parameters:
    ///   - relativePath: Relative path as stored in database
    ///   - customBasePath: Optional custom base path (from settings)
    func deletePDF(at relativePath: String, customBasePath: String? = nil) throws {
        guard let url = url(for: relativePath, customBasePath: customBasePath) else {
            throw StorageError.fileNotFound
        }
        try fileManager.removeItem(at: url)
    }

    /// Ensure the full directory structure exists
    func ensureDirectoryStructure(customBasePath: String? = nil) throws {
        let baseDir = documentsDirectory(customPath: customBasePath)

        for type in DocumentType.allCases {
            let typeDir = baseDir.appendingPathComponent(type.rawValue, isDirectory: true)
            try createDirectoryIfNeeded(at: typeDir)
        }
    }

    /// Open a PDF in the system's default PDF viewer
    func openPDF(at relativePath: String, customBasePath: String? = nil) -> Bool {
        guard let url = url(for: relativePath, customBasePath: customBasePath) else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    /// Open the documents folder in Finder
    func openDocumentsFolder(customBasePath: String? = nil) {
        let baseDir = documentsDirectory(customPath: customBasePath)
        NSWorkspace.shared.open(baseDir)
    }

    /// Get all stored documents of a specific type for a year
    func listDocuments(type: DocumentType, year: Int, customBasePath: String? = nil) -> [URL] {
        let baseDir = documentsDirectory(customPath: customBasePath)
        let yearDir = baseDir
            .appendingPathComponent(type.rawValue, isDirectory: true)
            .appendingPathComponent(String(year), isDirectory: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: yearDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension.lowercased() == "pdf" }
    }

    /// Calculate total storage used by documents
    func totalStorageUsed(customBasePath: String? = nil) -> Int64 {
        let baseDir = documentsDirectory(customPath: customBasePath)
        return calculateFolderSize(at: baseDir)
    }

    // MARK: - Private Helpers

    private func createDirectoryIfNeeded(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw StorageError.cannotCreateDirectory
        }
    }

    private func calculateFolderSize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
}

// MARK: - CaseIterable Extension

extension DocumentStorageService.DocumentType: CaseIterable {}

// MARK: - Formatted Storage Size

extension DocumentStorageService {
    /// Get human-readable storage size
    func formattedStorageUsed(customBasePath: String? = nil) -> String {
        let bytes = totalStorageUsed(customBasePath: customBasePath)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
