import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear {
            ensureSettingsExist()
        }
        .alert(appState.alertTitle, isPresented: $appState.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.alertMessage)
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: appState.loadingMessage)
            }
        }
        .sheet(isPresented: $appState.showImportSheet) {
            ImportView()
                .environmentObject(appState)
        }
    }

    private func ensureSettingsExist() {
        _ = BusinessSettings.ensureSettingsExist(in: modelContext)
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedSidebarItem) {
            // Main Section
            Section {
                NavigationLink(value: SidebarItem.dashboard) {
                    Label("Dashboard", systemImage: SidebarItem.dashboard.icon)
                }
            }

            // Registratie Section
            Section("Registratie") {
                NavigationLink(value: SidebarItem.urenregistratie) {
                    Label("Urenregistratie", systemImage: SidebarItem.urenregistratie.icon)
                }
                NavigationLink(value: SidebarItem.uitgaven) {
                    Label("Uitgaven", systemImage: SidebarItem.uitgaven.icon)
                }
            }

            // Facturatie Section
            Section("Facturatie") {
                NavigationLink(value: SidebarItem.facturen) {
                    Label("Facturen", systemImage: SidebarItem.facturen.icon)
                }
                NavigationLink(value: SidebarItem.klanten) {
                    Label("Klanten", systemImage: SidebarItem.klanten.icon)
                }
            }

            // Financieel Section
            Section("Financieel") {
                NavigationLink(value: SidebarItem.rapportages) {
                    Label("Rapportages", systemImage: SidebarItem.rapportages.icon)
                }
            }

            // Settings
            Section {
                NavigationLink(value: SidebarItem.instellingen) {
                    Label("Instellingen", systemImage: SidebarItem.instellingen.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("RoBerg")
        .toolbar {
            ToolbarItem {
                Button(action: { appState.showImportSheet = true }) {
                    Label("Importeren", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}

// MARK: - Detail View
struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .dashboard:
                DashboardView()
            case .urenregistratie:
                TimeEntryListView()
            case .facturen:
                InvoiceListView()
            case .klanten:
                ClientListView()
            case .uitgaven:
                ExpenseListView()
            case .rapportages:
                ReportsView()
            case .instellingen:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
