import Foundation
import AppKit
import os.log

/// Logger for document storage operations
private let storageLogger = Logger(subsystem: "nl.uurwerker", category: "DocumentStorage")

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
        case pathTraversalAttempt
        case pathOutsideSandbox

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
            case .pathTraversalAttempt:
                return "Onveilig bestandspad gedetecteerd"
            case .pathOutsideSandbox:
                return "Pad valt buiten toegestane map"
            }
        }
    }

    // MARK: - Path Validation

    /// Characters allowed in identifiers (alphanumeric, dash, underscore, space, period)
    private static let allowedIdentifierCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_. "))

    /// Sanitize an identifier to prevent path traversal attacks
    /// - Parameter identifier: The raw identifier
    /// - Returns: A safe identifier for use in filenames
    private func sanitizeIdentifier(_ identifier: String) -> String {
        // Remove any path traversal sequences
        var safe = identifier
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        // Filter to only allowed characters
        safe = String(safe.unicodeScalars.filter {
            Self.allowedIdentifierCharacters.contains($0)
        })

        // Ensure not empty
        if safe.isEmpty {
            safe = "document"
        }

        // Limit length
        if safe.count > 100 {
            safe = String(safe.prefix(100))
        }

        storageLogger.debug("Sanitized identifier: '\(identifier)' -> '\(safe)'")
        return safe
    }

    /// Validate that a resolved path is within the expected base directory
    /// - Parameters:
    ///   - path: The path to validate
    ///   - baseDirectory: The expected base directory
    /// - Returns: true if path is safely within base directory
    private func isPathWithinBase(_ path: URL, baseDirectory: URL) -> Bool {
        let resolvedPath = path.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedBase = baseDirectory.standardizedFileURL.resolvingSymlinksInPath()

        return resolvedPath.path.hasPrefix(resolvedBase.path)
    }

    /// Validate a custom base path
    /// - Parameter path: The custom path to validate
    /// - Returns: A validated URL
    /// - Throws: StorageError if path is invalid or dangerous
    private func validateCustomPath(_ path: String) throws -> URL {
        guard !path.isEmpty else {
            throw StorageError.invalidPath
        }

        // Check for path traversal patterns
        if path.contains("..") {
            storageLogger.warning("Path traversal attempt detected in custom path: \(path)")
            throw StorageError.pathTraversalAttempt
        }

        let url = URL(fileURLWithPath: path).standardizedFileURL

        // Verify it's not a system directory
        let systemPaths = ["/System", "/Library", "/usr", "/bin", "/sbin", "/private", "/var"]
        for systemPath in systemPaths {
            if url.path.hasPrefix(systemPath) {
                storageLogger.warning("Attempt to use system path: \(path)")
                throw StorageError.pathOutsideSandbox
            }
        }

        return url
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    /// Default documents directory in Application Support
    var defaultDocumentsDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to user's home directory if Application Support unavailable
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/Uurwerker", isDirectory: true)
        }
        return appSupport.appendingPathComponent("Uurwerker/Documents", isDirectory: true)
    }

    // MARK: - Public Methods

    /// Get the base documents directory (custom or default)
    /// For validated custom paths, use validatedDocumentsDirectory instead
    func documentsDirectory(customPath: String? = nil) -> URL {
        if let custom = customPath, !custom.isEmpty {
            // Try to validate, fallback to default if validation fails
            if let validated = try? validateCustomPath(custom) {
                return validated
            } else {
                storageLogger.warning("Invalid custom path, falling back to default: \(custom)")
                return defaultDocumentsDirectory
            }
        }
        return defaultDocumentsDirectory
    }

    /// Get the base documents directory with explicit validation
    /// - Parameter customPath: Optional custom path
    /// - Returns: Validated URL
    /// - Throws: StorageError if custom path is invalid
    func validatedDocumentsDirectory(customPath: String? = nil) throws -> URL {
        if let custom = customPath, !custom.isEmpty {
            return try validateCustomPath(custom)
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

        // Sanitize filename using proper validation
        let safeIdentifier = sanitizeIdentifier(identifier)
        let filename = "\(safeIdentifier).pdf"
        let fileURL = yearDir.appendingPathComponent(filename)

        // Verify the final path is within our base directory (defense in depth)
        guard isPathWithinBase(fileURL, baseDirectory: baseDir) else {
            storageLogger.error("Path traversal attempt blocked: \(fileURL.path)")
            throw StorageError.pathTraversalAttempt
        }

        // Write file
        do {
            try data.write(to: fileURL, options: [.atomic])
            storageLogger.info("Stored PDF: \(filename)")
        } catch {
            storageLogger.error("Failed to write PDF: \(error.localizedDescription)")
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

        // Check for path traversal in relative path
        if relativePath.contains("..") {
            storageLogger.warning("Path traversal attempt in relative path: \(relativePath)")
            return nil
        }

        let baseDir = documentsDirectory(customPath: customBasePath)
        let fullURL = baseDir.appendingPathComponent(relativePath)

        // Verify the resolved path is within base directory
        guard isPathWithinBase(fullURL, baseDirectory: baseDir) else {
            storageLogger.warning("Path escaped base directory: \(fullURL.path)")
            return nil
        }

        // Verify file exists
        guard fileManager.fileExists(atPath: fullURL.path) else {
            return nil
        }

        return fullURL
    }

    /// Check if a document exists at the given relative path
    func documentExists(at relativePath: String, customBasePath: String? = nil) -> Bool {
        guard !relativePath.isEmpty else { return false }

        // Check for path traversal
        if relativePath.contains("..") {
            storageLogger.warning("Path traversal attempt in document check: \(relativePath)")
            return false
        }

        let baseDir = documentsDirectory(customPath: customBasePath)
        let fullURL = baseDir.appendingPathComponent(relativePath)

        // Verify the resolved path is within base directory
        guard isPathWithinBase(fullURL, baseDirectory: baseDir) else {
            return false
        }

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
