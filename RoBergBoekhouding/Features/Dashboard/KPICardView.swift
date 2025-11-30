import SwiftUI

struct KPICardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Compact KPI Card
struct KPICardCompactView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Progress KPI Card
struct KPIProgressCardView: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percentage)%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(progress >= 1 ? .green : color)
            }

            ProgressView(value: progress)
                .tint(progress >= 1 ? .green : color)

            HStack {
                Text("\(Int(current)) \(unit)")
                    .font(.caption)
                Spacer()
                Text("van \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Stat Row
struct StatRowView: View {
    let label: String
    let value: String
    let color: Color?

    init(label: String, value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color ?? .primary)
        }
        .font(.subheadline)
    }
}

// MARK: - Previews
#Preview("KPI Cards") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            KPICardView(
                title: "Omzet YTD",
                value: "€ 98.450,00",
                subtitle: "+12% vs 2024",
                icon: "eurosign.circle.fill",
                color: .green
            )

            KPICardView(
                title: "Uren YTD",
                value: "1.456",
                subtitle: "van 1.225 uur",
                icon: "clock.fill",
                color: .blue
            )
        }

        KPIProgressCardView(
            title: "Zelfstandigenaftrek",
            current: 1456,
            target: 1225,
            unit: "uur",
            color: .blue
        )

        KPICardCompactView(
            title: "Kilometers",
            value: "12.890 km",
            icon: "car.fill",
            color: .orange
        )
    }
    .padding()
    .frame(width: 500)
}
