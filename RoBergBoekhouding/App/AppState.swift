import SwiftUI
import Combine

/// Global application state
@MainActor
final class AppState: ObservableObject {
    // MARK: - Navigation
    @Published var selectedSidebarItem: SidebarItem = .dashboard

    // MARK: - Modal States
    @Published var showNewTimeEntry = false
    @Published var showNewInvoice = false
    @Published var showNewExpense = false
    @Published var showNewClient = false
    @Published var showImportSheet = false
    @Published var showExportSheet = false

    // MARK: - Selection States
    @Published var selectedClient: Client?
    @Published var selectedTimeEntry: TimeEntry?
    @Published var selectedInvoice: Invoice?
    @Published var selectedExpense: Expense?

    // MARK: - Filter States
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedMonth: Int? = nil
    @Published var searchText: String = ""

    // MARK: - Alert States
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

    // MARK: - Methods

    /// Show an alert
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
        showNewTimeEntry = false
        showNewInvoice = false
        showNewExpense = false
        showNewClient = false
        showImportSheet = false
        showExportSheet = false
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let dataImported = Notification.Name("dataImported")
    static let invoiceCreated = Notification.Name("invoiceCreated")
    static let settingsUpdated = Notification.Name("settingsUpdated")
}
