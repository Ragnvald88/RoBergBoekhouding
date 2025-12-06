import SwiftUI
import Combine

// MARK: - Active Modal Enum

/// Represents which modal sheet is currently active
/// Using an enum prevents multiple modals from being shown simultaneously
enum ActiveModal: Identifiable, Equatable {
    case newTimeEntry
    case editTimeEntry(TimeEntry)
    case newInvoice
    case newExpense
    case editExpense(Expense)
    case newClient
    case editClient(Client)
    case importSheet
    case exportSheet

    var id: String {
        switch self {
        case .newTimeEntry: return "newTimeEntry"
        case .editTimeEntry(let entry): return "editTimeEntry-\(entry.id)"
        case .newInvoice: return "newInvoice"
        case .newExpense: return "newExpense"
        case .editExpense(let expense): return "editExpense-\(expense.id)"
        case .newClient: return "newClient"
        case .editClient(let client): return "editClient-\(client.id)"
        case .importSheet: return "importSheet"
        case .exportSheet: return "exportSheet"
        }
    }
}

/// Global application state
@MainActor
final class AppState: ObservableObject {
    // MARK: - Navigation
    @Published var selectedSidebarItem: SidebarItem = .dashboard

    // MARK: - Modal State (Unified)
    /// The currently active modal, if any. Only one modal can be active at a time.
    @Published var activeModal: ActiveModal?

    // MARK: - Legacy Modal States (for backward compatibility)
    // These computed properties map to the new activeModal system
    var showNewTimeEntry: Bool {
        get { if case .newTimeEntry = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .newTimeEntry : nil }
    }

    var showNewInvoice: Bool {
        get { if case .newInvoice = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .newInvoice : nil }
    }

    var showNewExpense: Bool {
        get { if case .newExpense = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .newExpense : nil }
    }

    var showNewClient: Bool {
        get { if case .newClient = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .newClient : nil }
    }

    var showImportSheet: Bool {
        get { if case .importSheet = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .importSheet : nil }
    }

    var showExportSheet: Bool {
        get { if case .exportSheet = activeModal { return true } else { return false } }
        set { activeModal = newValue ? .exportSheet : nil }
    }

    // MARK: - Selection States
    @Published var selectedClient: Client?
    @Published var selectedTimeEntry: TimeEntry?
    @Published var selectedInvoice: Invoice?
    @Published var selectedExpense: Expense?

    // MARK: - Filter States
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedMonth: Int? = nil
    @Published var searchText: String = ""

    // MARK: - Error State
    @Published var currentError: AppError?

    // MARK: - Alert States (Legacy - prefer currentError for new code)
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    // MARK: - Loading States
    @Published var isLoading = false
    @Published var loadingMessage = ""

    // MARK: - Available Years
    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((2023...currentYear).reversed())
    }

    // MARK: - Modal Methods

    /// Show a modal
    func showModal(_ modal: ActiveModal) {
        activeModal = modal
    }

    /// Dismiss the current modal
    func dismissModal() {
        activeModal = nil
    }

    // MARK: - Error Methods

    /// Show an error
    func showError(_ error: AppError) {
        currentError = error
    }

    /// Dismiss the current error
    func dismissError() {
        currentError = nil
    }

    // MARK: - Alert Methods

    /// Show an alert (legacy - prefer showError for new code)
    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    /// Show loading indicator
    func showLoading(_ message: String) {
        loadingMessage = message
        isLoading = true
    }

    /// Hide loading indicator
    func hideLoading() {
        isLoading = false
        loadingMessage = ""
    }

    /// Navigate to a sidebar item
    func navigateTo(_ item: SidebarItem) {
        selectedSidebarItem = item
    }

    /// Reset all selections
    func resetSelections() {
        selectedClient = nil
        selectedTimeEntry = nil
        selectedInvoice = nil
        selectedExpense = nil
    }

    /// Reset all filters
    func resetFilters() {
        selectedYear = Calendar.current.component(.year, from: Date())
        selectedMonth = nil
        searchText = ""
    }

    /// Close all modals
    func closeAllModals() {
        activeModal = nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let dataImported = Notification.Name("dataImported")
    static let invoiceCreated = Notification.Name("invoiceCreated")
    static let settingsUpdated = Notification.Name("settingsUpdated")
}
