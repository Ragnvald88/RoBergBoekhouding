import SwiftUI
import SwiftData

struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let client: Client?

    // Form State
    @State private var bedrijfsnaam: String = ""
    @State private var contactpersoon: String = ""
    @State private var adres: String = ""
    @State private var postcodeplaats: String = ""
    @State private var telefoon: String = ""
    @State private var email: String = ""
    @State private var clientType: ClientType = .dagpraktijk
    @State private var standaardUurtarief: Decimal = 70.00
    @State private var standaardKmTarief: Decimal = 0.23
    @State private var afstandRetour: Int = 0
    @State private var isActive: Bool = true
    @State private var showingDeleteAlert: Bool = false

    private var isEditing: Bool { client != nil }
    private var canSave: Bool { !bedrijfsnaam.isEmpty }

    private var deleteWarningMessage: String {
        guard let client else { return "" }
        var message = "Weet je zeker dat je '\(client.bedrijfsnaam)' wilt verwijderen?"

        let entryCount = client.timeEntries?.count ?? 0
        let invoiceCount = client.invoices?.count ?? 0

        if entryCount > 0 || invoiceCount > 0 {
            message += "\n\nDit verwijdert ook:"
            if entryCount > 0 {
                message += "\n• \(entryCount) urenregistratie\(entryCount == 1 ? "" : "s")"
            }
            if invoiceCount > 0 {
                message += "\n• \(invoiceCount) factu\(invoiceCount == 1 ? "ur" : "ren")"
            }
        }

        message += "\n\nDit kan niet ongedaan worden gemaakt."
        return message
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form
            Form {
                Section("Basisgegevens") {
                    TextField("Bedrijfsnaam *", text: $bedrijfsnaam)
                    TextField("Contactpersoon", text: $contactpersoon)

                    Picker("Type klant", selection: $clientType) {
                        ForEach(ClientType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: clientType) { _, newType in
                        applyTypeDefaults(newType)
                    }

                    Toggle("Actief", isOn: $isActive)
                }

                Section("Adres") {
                    TextField("Adres", text: $adres)
                    TextField("Postcode en plaats", text: $postcodeplaats)
                }

                Section("Contact") {
                    TextField("Telefoon", text: $telefoon)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                }

                Section("Tarieven") {
                    LabeledContent("Standaard uurtarief") {
                        TextField("", value: $standaardUurtarief, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Kilometertarief") {
                        TextField("", value: $standaardKmTarief, format: .currency(code: "EUR"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Retourafstand") {
                        HStack(spacing: 4) {
                            TextField("", value: $afstandRetour, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            footer
        }
        .frame(width: 450, height: 550)
        .onAppear {
            if let client {
                loadClient(client)
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text(isEditing ? "Klant bewerken" : "Nieuwe klant")
                .font(.headline)
            Spacer()
            Button("Annuleren") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }

    // MARK: - Footer
    private var footer: some View {
        HStack {
            if isEditing {
                Button("Verwijderen", role: .destructive) {
                    showingDeleteAlert = true
                }
            }

            Spacer()

            Button("Opslaan") {
                saveClient()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding()
        .alert("Klant verwijderen", isPresented: $showingDeleteAlert) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                deleteClient()
            }
        } message: {
            Text(deleteWarningMessage)
        }
    }

    // MARK: - Methods
    private func applyTypeDefaults(_ type: ClientType) {
        standaardUurtarief = type.defaultHourlyRate
    }

    private func loadClient(_ client: Client) {
        bedrijfsnaam = client.bedrijfsnaam
        contactpersoon = client.contactpersoon ?? ""
        adres = client.adres
        postcodeplaats = client.postcodeplaats
        telefoon = client.telefoon ?? ""
        email = client.email ?? ""
        clientType = client.clientType
        standaardUurtarief = client.standaardUurtarief
        standaardKmTarief = client.standaardKmTarief
        afstandRetour = client.afstandRetour
        isActive = client.isActive
    }

    private func saveClient() {
        if let client {
            // Update existing
            client.bedrijfsnaam = bedrijfsnaam
            client.contactpersoon = contactpersoon.isEmpty ? nil : contactpersoon
            client.adres = adres
            client.postcodeplaats = postcodeplaats
            client.telefoon = telefoon.isEmpty ? nil : telefoon
            client.email = email.isEmpty ? nil : email
            client.clientType = clientType
            client.standaardUurtarief = standaardUurtarief
            client.standaardKmTarief = standaardKmTarief
            client.afstandRetour = afstandRetour
            client.isActive = isActive
            client.updateTimestamp()
        } else {
            // Create new
            let newClient = Client(
                bedrijfsnaam: bedrijfsnaam,
                contactpersoon: contactpersoon.isEmpty ? nil : contactpersoon,
                adres: adres,
                postcodeplaats: postcodeplaats,
                telefoon: telefoon.isEmpty ? nil : telefoon,
                email: email.isEmpty ? nil : email,
                standaardUurtarief: standaardUurtarief,
                standaardKmTarief: standaardKmTarief,
                afstandRetour: afstandRetour,
                clientType: clientType,
                isActive: isActive
            )
            modelContext.insert(newClient)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteClient() {
        guard let client else { return }
        modelContext.delete(client)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    ClientFormView(client: nil)
        .modelContainer(for: [Client.self, TimeEntry.self, Invoice.self, Expense.self, BusinessSettings.self], inMemory: true)
}
