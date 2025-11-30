import SwiftUI
import SwiftData

@main
struct RoBergBoekhoudingApp: App {
    // MARK: - SwiftData Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Client.self,
            TimeEntry.self,
            Invoice.self,
            Expense.self,
            BusinessSettings.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - App State
    @StateObject private var appState = AppState()

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("Nieuwe Urenregistratie") {
                    appState.selectedSidebarItem = .urenregistratie
                    appState.showNewTimeEntry = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Nieuwe Factuur") {
                    appState.selectedSidebarItem = .facturen
                    appState.showNewInvoice = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Nieuwe Uitgave") {
                    appState.selectedSidebarItem = .uitgaven
                    appState.showNewExpense = true
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Divider()

                Button("Importeer CSV...") {
                    appState.showImportSheet = true
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            // View Menu
            CommandGroup(after: .sidebar) {
                Button("Toon Dashboard") {
                    appState.selectedSidebarItem = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Toon Urenregistratie") {
                    appState.selectedSidebarItem = .urenregistratie
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Toon Facturen") {
                    appState.selectedSidebarItem = .facturen
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Toon Klanten") {
                    appState.selectedSidebarItem = .klanten
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Toon Uitgaven") {
                    appState.selectedSidebarItem = .uitgaven
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Toon Rapportages") {
                    appState.selectedSidebarItem = .rapportages
                }
                .keyboardShortcut("6", modifiers: .command)
            }
        }

        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
