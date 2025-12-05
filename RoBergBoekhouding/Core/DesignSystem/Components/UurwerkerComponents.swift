import SwiftUI

// MARK: - Uurwerker Card
/// Standard card container with consistent styling
struct UurwerkerCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(Spacing.md)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .cardShadow()
    }
}

// MARK: - Empty State View
/// Consistent empty state display across the app
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.uurwerkerTitle3)
                .foregroundStyle(.primary)

            Text(description)
                .font(.uurwerkerBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.uurwerkerBlue)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section Header
/// Consistent section header with optional action
struct SectionHeader: View {
    let title: String
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        _ title: String,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.uurwerkerHeadline)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.uurwerkerCaption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.uurwerkerBlue)
            }
        }
    }
}

// MARK: - Status Badge
/// Colored badge for displaying status
struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String?

    init(_ text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(.uurwerkerCaption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Currency Display
/// Formatted currency display with consistent styling
struct CurrencyDisplay: View {
    let amount: Decimal
    let style: DisplayStyle

    enum DisplayStyle {
        case normal
        case prominent
        case subtle
    }

    var body: some View {
        Text(amount.asCurrency)
            .font(font)
            .foregroundStyle(foregroundColor)
            .fontDesign(.monospaced)
            .accessibilityLabel("\(amount.asCurrency) euro")
    }

    private var font: Font {
        switch style {
        case .normal: return .uurwerkerBody
        case .prominent: return .uurwerkerHeadline
        case .subtle: return .uurwerkerCaption
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .normal, .prominent: return .primary
        case .subtle: return .secondary
        }
    }
}

// MARK: - Loading Button
/// Button with loading state
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                }
                Text(title)
            }
        }
        .disabled(isLoading)
        .buttonStyle(.borderedProminent)
        .tint(.uurwerkerBlue)
    }
}

// MARK: - Info Row
/// Key-value display row
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String?

    init(_ label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            Text(label)
                .font(.uurwerkerSubheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.uurwerkerBody)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Quick Action Button
/// Large tappable action button for dashboard
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(title)
                    .font(.uurwerkerCaption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Divider with Label
struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.quaternary)

            Text(label)
                .font(.uurwerkerCaption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Spacing.xs)

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - Preview
#Preview("Components") {
    VStack(spacing: 20) {
        UurwerkerCard {
            VStack(alignment: .leading) {
                SectionHeader("Recente activiteit", icon: "clock", actionTitle: "Bekijk alles") {}
                Divider()
                InfoRow("Klant", value: "Test BV", icon: "building.2")
                InfoRow("Bedrag", value: "€ 1.234,50", icon: "eurosign")
            }
        }

        HStack {
            StatusBadge("Betaald", color: Color.uurwerkerSuccess, icon: "checkmark")
            StatusBadge("Verzonden", color: Color.uurwerkerInfo)
            StatusBadge("Te laat", color: Color.uurwerkerError, icon: "exclamationmark.triangle")
        }

        EmptyStateView(
            icon: "doc.text",
            title: "Geen facturen",
            description: "Begin met het maken van je eerste factuur",
            actionTitle: "Nieuwe factuur"
        ) {}

        HStack {
            QuickActionButton(title: "Nieuwe uren", icon: "clock.badge.plus", color: .blue) {}
            QuickActionButton(title: "Factuur", icon: "doc.badge.plus", color: .green) {}
            QuickActionButton(title: "Uitgave", icon: "creditcard.fill", color: .orange) {}
        }
    }
    .padding()
    .frame(width: 600)
}
