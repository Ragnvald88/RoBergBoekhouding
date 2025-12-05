import SwiftUI

// MARK: - About View
/// App information view for App Store compliance and user information
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            // Header with app icon
            headerSection

            Divider()

            // Scrollable content
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    versionSection
                    linksSection
                    creditsSection
                    legalSection
                }
                .padding(Spacing.lg)
            }

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 480, height: 600)
        .background(Color.cardBackground)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // App Icon placeholder - replace with actual icon
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color.uurwerkerBlue, Color.uurwerkerBlue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.uurwerkerBlue.opacity(0.3), radius: 10, y: 5)

            VStack(spacing: Spacing.xxs) {
                Text("Uurwerker")
                    .font(.uurwerkerTitle)
                    .fontWeight(.bold)

                Text("Precisie voor ondernemers")
                    .font(.uurwerkerSubheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Color.elevatedBackground)
    }

    // MARK: - Version Section
    private var versionSection: some View {
        UurwerkerCard {
            VStack(spacing: Spacing.sm) {
                InfoRow("Versie", value: appVersion)
                Divider()
                InfoRow("Build", value: buildNumber)
                Divider()
                InfoRow("Platform", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
            }
        }
    }

    // MARK: - Links Section
    private var linksSection: some View {
        UurwerkerCard {
            VStack(spacing: Spacing.sm) {
                SectionHeader("Links", icon: "link")

                Divider()

                LinkButton(
                    title: "Website",
                    subtitle: "uurwerker.nl",
                    icon: "globe",
                    url: "https://uurwerker.nl"
                )

                Divider()

                LinkButton(
                    title: "Privacybeleid",
                    subtitle: "Hoe wij met je gegevens omgaan",
                    icon: "hand.raised.fill",
                    url: "https://uurwerker.nl/privacy"
                )

                Divider()

                LinkButton(
                    title: "Ondersteuning",
                    subtitle: "Hulp en veelgestelde vragen",
                    icon: "questionmark.circle.fill",
                    url: "https://uurwerker.nl/support"
                )

                Divider()

                LinkButton(
                    title: "Feedback",
                    subtitle: "Stuur ons je suggesties",
                    icon: "envelope.fill",
                    url: "mailto:support@uurwerker.nl"
                )
            }
        }
    }

    // MARK: - Credits Section
    private var creditsSection: some View {
        UurwerkerCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Over Uurwerker", icon: "info.circle")

                Divider()

                Text("""
                    Uurwerker is ontwikkeld voor Nederlandse ZZP'ers en kleine ondernemers die op zoek zijn naar een simpele, krachtige en privacy-vriendelijke boekhoudoplossing.

                    Alle gegevens blijven lokaal op je Mac. Geen abonnementen, geen cloud, geen gedoe.
                    """)
                    .font(.uurwerkerBody)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        UurwerkerCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Juridisch", icon: "doc.text")

                Divider()

                Text("© 2024-2025 Uurwerker. Alle rechten voorbehouden.")
                    .font(.uurwerkerCaption)
                    .foregroundStyle(.secondary)

                Text("Gemaakt met ❤️ in Nederland")
                    .font(.uurwerkerCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        HStack {
            Button("Sluiten") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Link Button
private struct LinkButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let url: String

    var body: some View {
        Button(action: openURL) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.uurwerkerBlue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.uurwerkerBody)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.uurwerkerCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Opent in browser")
    }

    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview
#Preview {
    AboutView()
}
