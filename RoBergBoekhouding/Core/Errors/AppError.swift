import Foundation

// MARK: - Application Error Types
/// Comprehensive error handling for Uurwerker app
enum AppError: LocalizedError, Equatable {
    // MARK: - Data Errors
    case dataCorruption(details: String)
    case databaseInitFailed(reason: String)
    case saveFailed(entity: String, reason: String)
    case deleteFailed(entity: String, reason: String)
    case fetchFailed(entity: String, reason: String)

    // MARK: - PDF Errors
    case pdfGenerationFailed(reason: String)
    case pdfRenderTimeout
    case pdfSaveFailed(path: String)
    case pdfNotFound(identifier: String)

    // MARK: - File Errors
    case fileNotFound(path: String)
    case fileReadFailed(path: String)
    case fileWriteFailed(path: String)
    case directoryCreationFailed(path: String)
    case permissionDenied(resource: String)
    case insufficientDiskSpace

    // MARK: - Import/Export Errors
    case importFailed(type: String, reason: String)
    case exportFailed(type: String, reason: String)
    case invalidFileFormat(expected: String, got: String)
    case encodingError(encoding: String)
    case parsingError(line: Int?, details: String)

    // MARK: - Validation Errors
    case validationFailed(field: String, reason: String)
    case duplicateEntry(type: String, identifier: String)
    case requiredFieldMissing(field: String)
    case invalidValue(field: String, value: String)

    // MARK: - Business Logic Errors
    case invoiceAlreadyExists(number: String)
    case clientNotFound(identifier: String)
    case noEntriesSelected
    case invoiceNotEditable(status: String)

    // MARK: - Unknown
    case unknown(Error)

    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        // Data Errors
        case .dataCorruption(let details):
            return "Databasefout: \(details)"
        case .databaseInitFailed(let reason):
            return "Database kon niet worden geopend: \(reason)"
        case .saveFailed(let entity, let reason):
            return "\(entity) opslaan mislukt: \(reason)"
        case .deleteFailed(let entity, let reason):
            return "\(entity) verwijderen mislukt: \(reason)"
        case .fetchFailed(let entity, let reason):
            return "\(entity) ophalen mislukt: \(reason)"

        // PDF Errors
        case .pdfGenerationFailed(let reason):
            return "PDF maken mislukt: \(reason)"
        case .pdfRenderTimeout:
            return "PDF maken duurde te lang"
        case .pdfSaveFailed(let path):
            return "PDF opslaan mislukt naar: \(path)"
        case .pdfNotFound(let identifier):
            return "PDF niet gevonden: \(identifier)"

        // File Errors
        case .fileNotFound(let path):
            return "Bestand niet gevonden: \(path)"
        case .fileReadFailed(let path):
            return "Bestand lezen mislukt: \(path)"
        case .fileWriteFailed(let path):
            return "Bestand schrijven mislukt: \(path)"
        case .directoryCreationFailed(let path):
            return "Map aanmaken mislukt: \(path)"
        case .permissionDenied(let resource):
            return "Geen toegang tot: \(resource)"
        case .insufficientDiskSpace:
            return "Onvoldoende schijfruimte"

        // Import/Export Errors
        case .importFailed(let type, let reason):
            return "\(type) import mislukt: \(reason)"
        case .exportFailed(let type, let reason):
            return "\(type) export mislukt: \(reason)"
        case .invalidFileFormat(let expected, let got):
            return "Ongeldig bestandsformaat. Verwacht: \(expected), gevonden: \(got)"
        case .encodingError(let encoding):
            return "Tekstcodering niet ondersteund: \(encoding)"
        case .parsingError(let line, let details):
            if let line = line {
                return "Fout op regel \(line): \(details)"
            }
            return "Parseer fout: \(details)"

        // Validation Errors
        case .validationFailed(let field, let reason):
            return "\(field): \(reason)"
        case .duplicateEntry(let type, let identifier):
            return "\(type) '\(identifier)' bestaat al"
        case .requiredFieldMissing(let field):
            return "\(field) is verplicht"
        case .invalidValue(let field, let value):
            return "Ongeldige waarde voor \(field): \(value)"

        // Business Logic Errors
        case .invoiceAlreadyExists(let number):
            return "Factuur \(number) bestaat al"
        case .clientNotFound(let identifier):
            return "Klant niet gevonden: \(identifier)"
        case .noEntriesSelected:
            return "Selecteer minimaal één registratie"
        case .invoiceNotEditable(let status):
            return "Factuur met status '\(status)' kan niet worden bewerkt"

        case .unknown(let error):
            return "Onverwachte fout: \(error.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .dataCorruption:
            return "De database is mogelijk beschadigd."
        case .pdfRenderTimeout:
            return "Het systeem is mogelijk te traag of overbelast."
        case .insufficientDiskSpace:
            return "Er is niet genoeg ruimte op de schijf."
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .dataCorruption:
            return "Start de app opnieuw. Als het probleem aanhoudt, herstel een backup of neem contact op met support."
        case .databaseInitFailed:
            return "Probeer de app opnieuw te starten. Controleer of er voldoende schijfruimte is."
        case .pdfGenerationFailed, .pdfRenderTimeout:
            return "Probeer het opnieuw. Sluit andere programma's als het systeem traag is."
        case .pdfSaveFailed, .fileWriteFailed:
            return "Controleer of er voldoende schijfruimte is en of u schrijfrechten heeft."
        case .permissionDenied:
            return "Controleer de bestandspermissies in Systeemvoorkeuren > Privacy & Beveiliging."
        case .insufficientDiskSpace:
            return "Maak schijfruimte vrij en probeer opnieuw."
        case .importFailed:
            return "Controleer of het bestand het juiste formaat heeft."
        case .encodingError:
            return "Probeer het bestand op te slaan als UTF-8."
        default:
            return "Probeer het opnieuw. Als het probleem aanhoudt, neem contact op met support."
        }
    }

    // MARK: - Equatable
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Error Alert Presentation
struct ErrorAlert: Identifiable {
    let id = UUID()
    let error: AppError

    var title: String {
        switch error {
        case .dataCorruption, .databaseInitFailed, .saveFailed, .deleteFailed, .fetchFailed:
            return "Databasefout"
        case .pdfGenerationFailed, .pdfRenderTimeout, .pdfSaveFailed, .pdfNotFound:
            return "PDF Fout"
        case .fileNotFound, .fileReadFailed, .fileWriteFailed, .directoryCreationFailed, .permissionDenied, .insufficientDiskSpace:
            return "Bestandsfout"
        case .importFailed, .exportFailed, .invalidFileFormat, .encodingError, .parsingError:
            return "Import/Export Fout"
        case .validationFailed, .duplicateEntry, .requiredFieldMissing, .invalidValue:
            return "Validatiefout"
        case .invoiceAlreadyExists, .clientNotFound, .noEntriesSelected, .invoiceNotEditable:
            return "Fout"
        case .unknown:
            return "Onverwachte Fout"
        }
    }

    var message: String {
        var result = error.errorDescription ?? "Er is een fout opgetreden"
        if let suggestion = error.recoverySuggestion {
            result += "\n\n\(suggestion)"
        }
        return result
    }
}

// MARK: - Result Extension
extension Result where Failure == AppError {
    var appError: AppError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
