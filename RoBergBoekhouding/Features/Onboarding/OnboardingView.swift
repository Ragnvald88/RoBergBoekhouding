import SwiftUI
import SwiftData

// MARK: - Onboarding View
/// First-run wizard to collect business information
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @State private var currentStep = 0
    @State private var formData = OnboardingFormData()
    @State private var isAnimating = false

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressHeader

            // Content
            TabView(selection: $currentStep) {
                WelcomeStep(onContinue: nextStep)
                    .tag(0)

                BusinessInfoStep(formData: $formData, onContinue: nextStep, onBack: previousStep)
                    .tag(1)

                ContactStep(formData: $formData, onContinue: nextStep, onBack: previousStep)
                    .tag(2)

                TaxSettingsStep(formData: $formData, onContinue: nextStep, onBack: previousStep)
                    .tag(3)

                RatesStep(formData: $formData, onContinue: completeOnboarding, onBack: previousStep)
                    .tag(4)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(width: 600, height: 550)
        .background(Color.cardBackground)
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: Spacing.sm) {
            // Step indicators
            HStack(spacing: Spacing.xs) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.uurwerkerBlue : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            Text("Stap \(currentStep + 1) van \(totalSteps)")
                .font(.uurwerkerCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Navigation
    private func nextStep() {
        withAnimation {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    private func previousStep() {
        withAnimation {
            currentStep = max(currentStep - 1, 0)
        }
    }

    private func completeOnboarding() {
        // Save settings
        let settings = BusinessSettings.ensureSettingsExist(in: modelContext)

        // Apply form data
        settings.bedrijfsnaam = formData.bedrijfsnaam
        settings.eigenaar = formData.eigenaar
        settings.adres = formData.adres
        settings.postcodeplaats = "\(formData.postcode) \(formData.plaats)"
        settings.email = formData.email
        settings.telefoon = formData.telefoon
        settings.kvkNummer = formData.kvkNummer
        settings.btwVrijgesteld = !formData.btwPlichtig
        settings.standaardBTWTarief = formData.btwTarief
        settings.standaardUurtariefDag = formData.uurtarief
        settings.standaardKilometertarief = formData.kmTarief
        settings.standaardBetalingstermijn = formData.betalingstermijn
        settings.hasCompletedOnboarding = true

        try? modelContext.save()

        isPresented = false
    }
}

// MARK: - Form Data
struct OnboardingFormData {
    var bedrijfsnaam = ""
    var eigenaar = ""
    var adres = ""
    var postcode = ""
    var plaats = ""
    var email = ""
    var telefoon = ""
    var kvkNummer = ""
    var btwNummer = ""
    var btwPlichtig = true
    var btwTarief: BTWTarief = .standaard
    var uurtarief: Decimal = 75
    var kmTarief: Decimal = 0.23
    var betalingstermijn = 14
}

// MARK: - Welcome Step
private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.uurwerkerBlue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "clock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.uurwerkerBlue)
            }

            VStack(spacing: Spacing.sm) {
                Text("Welkom bij Uurwerker")
                    .font(.uurwerkerLargeTitle)

                Text("Precisie voor ondernemers")
                    .font(.uurwerkerTitle3)
                    .foregroundStyle(.secondary)
            }

            Text("Laten we je administratie instellen.\nDit duurt slechts een paar minuten.")
                .font(.uurwerkerBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Begin met instellen") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.uurwerkerBlue)
            .controlSize(.large)

            Spacer()
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Business Info Step
private struct BusinessInfoStep: View {
    @Binding var formData: OnboardingFormData
    let onContinue: () -> Void
    let onBack: () -> Void

    private var isValid: Bool {
        !formData.bedrijfsnaam.trimmingCharacters(in: .whitespaces).isEmpty &&
        !formData.eigenaar.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            stepHeader(
                icon: "building.2.fill",
                title: "Bedrijfsgegevens",
                subtitle: "Basisinformatie over je onderneming"
            )

            Form {
                Section {
                    TextField("Bedrijfsnaam", text: $formData.bedrijfsnaam)
                        .textFieldStyle(.roundedBorder)

                    TextField("Naam eigenaar", text: $formData.eigenaar)
                        .textFieldStyle(.roundedBorder)

                    TextField("KvK-nummer (optioneel)", text: $formData.kvkNummer)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            navigationButtons(
                onBack: onBack,
                onContinue: onContinue,
                continueEnabled: isValid
            )
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Contact Step
private struct ContactStep: View {
    @Binding var formData: OnboardingFormData
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            stepHeader(
                icon: "envelope.fill",
                title: "Contactgegevens",
                subtitle: "Deze verschijnen op je facturen"
            )

            VStack(spacing: Spacing.md) {
                // Adres
                HStack {
                    Text("Adres")
                        .frame(width: 120, alignment: .leading)
                        .foregroundStyle(.secondary)
                    TextField("Straat en huisnummer", text: $formData.adres)
                        .textFieldStyle(.roundedBorder)
                }

                // Postcode en Plaats
                HStack {
                    Text("Postcode")
                        .frame(width: 120, alignment: .leading)
                        .foregroundStyle(.secondary)
                    TextField("1234 AB", text: $formData.postcode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("Plaats")
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.md)
                    TextField("Plaatsnaam", text: $formData.plaats)
                        .textFieldStyle(.roundedBorder)
                }

                // E-mailadres
                HStack {
                    Text("E-mailadres")
                        .frame(width: 120, alignment: .leading)
                        .foregroundStyle(.secondary)
                    TextField("email@voorbeeld.nl", text: $formData.email)
                        .textFieldStyle(.roundedBorder)
                }

                // Telefoonnummer
                HStack {
                    Text("Telefoonnummer")
                        .frame(width: 120, alignment: .leading)
                        .foregroundStyle(.secondary)
                    TextField("+31 6 12345678", text: $formData.telefoon)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, Spacing.md)

            Spacer()

            navigationButtons(
                onBack: onBack,
                onContinue: onContinue,
                continueEnabled: true
            )
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Tax Settings Step
private struct TaxSettingsStep: View {
    @Binding var formData: OnboardingFormData
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            stepHeader(
                icon: "percent",
                title: "BTW-instellingen",
                subtitle: "Hoe ben je geregistreerd bij de Belastingdienst?"
            )

            Form {
                Section {
                    Toggle("BTW-plichtig", isOn: $formData.btwPlichtig)

                    if formData.btwPlichtig {
                        Picker("Standaard BTW-tarief", selection: $formData.btwTarief) {
                            ForEach(BTWTarief.allCases, id: \.self) { tarief in
                                Text(tarief.displayName).tag(tarief)
                            }
                        }

                        TextField("BTW-nummer", text: $formData.btwNummer)
                            .textFieldStyle(.roundedBorder)
                    }
                } footer: {
                    if formData.btwPlichtig {
                        Text("Je BTW-nummer vind je op je KvK-uittreksel of in MijnBelastingdienst.")
                    } else {
                        Text("Vrijgesteld van BTW? Dit geldt voor o.a. medische beroepen (art. 11) of de Kleineondernemersregeling (KOR).")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            navigationButtons(
                onBack: onBack,
                onContinue: onContinue,
                continueEnabled: true
            )
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Rates Step
private struct RatesStep: View {
    @Binding var formData: OnboardingFormData
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var uurtariefText = "75"
    @State private var kmTariefText = "0,23"
    @State private var betalingstermijnText = "14"

    var body: some View {
        VStack(spacing: Spacing.lg) {
            stepHeader(
                icon: "eurosign.circle.fill",
                title: "Standaardtarieven",
                subtitle: "Je kunt dit later per klant aanpassen"
            )

            VStack(spacing: Spacing.md) {
                // Uurtarief
                HStack {
                    Text("Uurtarief")
                        .frame(width: 160, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("€")
                        .foregroundStyle(.secondary)
                    TextField("75", text: $uurtariefText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: uurtariefText) { _, newValue in
                            if let value = Decimal(string: newValue.replacingOccurrences(of: ",", with: ".")) {
                                formData.uurtarief = value
                            }
                        }
                }

                // Kilometervergoeding
                HStack {
                    Text("Kilometervergoeding")
                        .frame(width: 160, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("€")
                        .foregroundStyle(.secondary)
                    TextField("0,23", text: $kmTariefText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: kmTariefText) { _, newValue in
                            if let value = Decimal(string: newValue.replacingOccurrences(of: ",", with: ".")) {
                                formData.kmTarief = value
                            }
                        }
                }

                // Betalingstermijn
                HStack {
                    Text("Betalingstermijn")
                        .frame(width: 160, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("14", text: $betalingstermijnText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: betalingstermijnText) { _, newValue in
                            if let value = Int(newValue) {
                                formData.betalingstermijn = max(7, min(60, value))
                            }
                        }
                    Text("dagen")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, Spacing.md)

            Text("De standaard kilometervergoeding is €0,23 per km (belastingvrij).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.lg)

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button("Start met Uurwerker") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.uurwerkerBlue)
                .controlSize(.large)

                Button("Terug") {
                    onBack()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
        .onAppear {
            // Initialize text fields with properly formatted values
            uurtariefText = String(format: "%.0f", Double(truncating: formData.uurtarief as NSNumber))
            kmTariefText = String(format: "%.2f", Double(truncating: formData.kmTarief as NSNumber)).replacingOccurrences(of: ".", with: ",")
            betalingstermijnText = "\(formData.betalingstermijn)"
        }
    }
}

// MARK: - Helper Views
private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: Spacing.sm) {
        Image(systemName: icon)
            .font(.system(size: 36))
            .foregroundStyle(Color.uurwerkerBlue)

        Text(title)
            .font(.uurwerkerTitle2)

        Text(subtitle)
            .font(.uurwerkerBody)
            .foregroundStyle(.secondary)
    }
}

private func navigationButtons(onBack: @escaping () -> Void, onContinue: @escaping () -> Void, continueEnabled: Bool) -> some View {
    HStack {
        Button("Terug") {
            onBack()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)

        Spacer()

        Button("Volgende") {
            onContinue()
        }
        .buttonStyle(.borderedProminent)
        .tint(.uurwerkerBlue)
        .disabled(!continueEnabled)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(isPresented: .constant(true))
        .modelContainer(for: BusinessSettings.self, inMemory: true)
}
