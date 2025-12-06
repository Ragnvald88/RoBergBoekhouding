import Foundation
import SwiftData
import os.log

/// Logger for database operations
private let databaseLogger = Logger(subsystem: "nl.uurwerker", category: "Database")

// MARK: - ModelContext Extensions for Safe Operations

extension ModelContext {
    /// Save the context with proper error handling and logging
    /// - Parameter entity: Optional name of the entity being saved for better error messages
    /// - Throws: AppError.saveFailed if the save operation fails
    func safeSave(entity: String = "Data") throws {
        do {
            try self.save()
            databaseLogger.debug("Successfully saved \(entity)")
        } catch {
            databaseLogger.error("Failed to save \(entity): \(error.localizedDescription)")
            throw AppError.saveFailed(entity: entity, reason: error.localizedDescription)
        }
    }

    /// Save the context, logging errors but not throwing
    /// Use this for non-critical saves where you want to continue even if save fails
    /// - Parameter entity: Optional name of the entity being saved for better error messages
    /// - Returns: true if save succeeded, false otherwise
    @discardableResult
    func trySave(entity: String = "Data") -> Bool {
        do {
            try self.save()
            databaseLogger.debug("Successfully saved \(entity)")
            return true
        } catch {
            databaseLogger.error("Failed to save \(entity): \(error.localizedDescription)")
            return false
        }
    }

    /// Safely delete an entity with proper error handling
    /// - Parameters:
    ///   - model: The model instance to delete
    ///   - saveImmediately: Whether to save the context after deletion
    /// - Throws: AppError.deleteFailed if the delete or save operation fails
    func safeDelete<T: PersistentModel>(_ model: T, saveImmediately: Bool = true) throws {
        let entityName = String(describing: T.self)
        self.delete(model)

        if saveImmediately {
            do {
                try self.save()
                databaseLogger.debug("Successfully deleted \(entityName)")
            } catch {
                databaseLogger.error("Failed to save after deleting \(entityName): \(error.localizedDescription)")
                throw AppError.deleteFailed(entity: entityName, reason: error.localizedDescription)
            }
        }
    }

    /// Safely fetch with proper error handling
    /// - Parameters:
    ///   - descriptor: The fetch descriptor
    ///   - entity: Name of the entity for error messages
    /// - Returns: Array of fetched results
    /// - Throws: AppError.fetchFailed if the fetch operation fails
    func safeFetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, entity: String? = nil) throws -> [T] {
        let entityName = entity ?? String(describing: T.self)
        do {
            let results = try self.fetch(descriptor)
            databaseLogger.debug("Fetched \(results.count) \(entityName) records")
            return results
        } catch {
            databaseLogger.error("Failed to fetch \(entityName): \(error.localizedDescription)")
            throw AppError.fetchFailed(entity: entityName, reason: error.localizedDescription)
        }
    }
}

// MARK: - Error Handling View Helpers

import SwiftUI

/// A view modifier that adds error alert presentation capability
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?

    func body(content: Content) -> some View {
        content
            .alert(
                errorAlert?.title ?? "Fout",
                isPresented: .init(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: errorAlert
            ) { _ in
                Button("OK") { error = nil }
            } message: { alert in
                Text(alert.message)
            }
    }

    private var errorAlert: ErrorAlert? {
        guard let error = error else { return nil }
        return ErrorAlert(error: error)
    }
}

extension View {
    /// Add error alert presentation to a view
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

// MARK: - Save Result Helper

/// Result type for save operations that may fail
enum SaveResult {
    case success
    case failure(AppError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var error: AppError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Helper function to perform a save operation and return a result
func performSave(
    context: ModelContext,
    entity: String,
    operation: () throws -> Void
) -> SaveResult {
    do {
        try operation()
        try context.save()
        databaseLogger.info("Successfully saved \(entity)")
        return .success
    } catch let error as AppError {
        databaseLogger.error("Save failed for \(entity): \(error.errorDescription ?? "Unknown error")")
        return .failure(error)
    } catch {
        databaseLogger.error("Save failed for \(entity): \(error.localizedDescription)")
        return .failure(.saveFailed(entity: entity, reason: error.localizedDescription))
    }
}
