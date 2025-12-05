//
//  UurwerkerApp.swift
//  Uurwerker
//
//  Created by Ronald Hoogenberg on 2024.
//  Copyright © 2024-2025 RoBerg. All rights reserved.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct UurwerkerApp: App {
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
            // Log error for debugging
            print("⚠️ Primary ModelContainer failed: \(error)")

            // Attempt in-memory fallback for recovery mode
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            do {
                print("ℹ️ Using in-memory fallback database")
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // This should never fail, but if it does, we need a last resort
                print("❌ Critical: Even fallback container failed: \(error)")
                // Create minimal container - this is truly the last resort
                return try! ModelContainer(for: schema, configurations: [fallbackConfig])
            }
        }
    }()

    // MARK: - App State
    @StateObject private var appState = AppState()
    @State private var showingAbout = false

    // Track if we're using fallback in-memory database
    private var isRecoveryMode: Bool {
        sharedModelContainer.configurations.first?.isStoredInMemoryOnly ?? false
    }

    // MARK: - Helper Functions
    private func showAboutWindow() {
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "Over Uurwerker"
        aboutWindow.center()
        aboutWindow.contentView = NSHostingView(rootView: AboutView())
        aboutWindow.makeKeyAndOrderFront(nil)
    }

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

            // Help Menu
            CommandGroup(replacing: .appInfo) {
                Button("Over Uurwerker") {
                    showAboutWindow()
                }
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
