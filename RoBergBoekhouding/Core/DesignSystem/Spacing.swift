import SwiftUI

// MARK: - Uurwerker Spacing System
enum Spacing {
    /// 4pt - Minimal spacing between related elements
    static let xxs: CGFloat = 4

    /// 8pt - Tight spacing within components
    static let xs: CGFloat = 8

    /// 12pt - Default spacing between elements
    static let sm: CGFloat = 12

    /// 16pt - Standard component padding
    static let md: CGFloat = 16

    /// 24pt - Section spacing
    static let lg: CGFloat = 24

    /// 32pt - Large section spacing
    static let xl: CGFloat = 32

    /// 48pt - Page-level spacing
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
enum CornerRadius {
    /// 4pt - Small elements (tags, badges)
    static let small: CGFloat = 4

    /// 8pt - Medium elements (buttons, inputs)
    static let medium: CGFloat = 8

    /// 12pt - Cards and containers
    static let large: CGFloat = 12

    /// 16pt - Modal sheets
    static let xlarge: CGFloat = 16
}

// MARK: - Shadow Styles
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// Subtle shadow for cards
    static let card = ShadowStyle(
        color: .black.opacity(0.05),
        radius: 5,
        x: 0,
        y: 2
    )

    /// Medium shadow for elevated elements
    static let elevated = ShadowStyle(
        color: .black.opacity(0.1),
        radius: 10,
        x: 0,
        y: 4
    )

    /// Strong shadow for modals
    static let modal = ShadowStyle(
        color: .black.opacity(0.15),
        radius: 20,
        x: 0,
        y: 8
    )
}

// MARK: - View Extension for Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: ShadowStyle.card.color,
            radius: ShadowStyle.card.radius,
            x: ShadowStyle.card.x,
            y: ShadowStyle.card.y
        )
    }

    func elevatedShadow() -> some View {
        self.shadow(
            color: ShadowStyle.elevated.color,
            radius: ShadowStyle.elevated.radius,
            x: ShadowStyle.elevated.x,
            y: ShadowStyle.elevated.y
        )
    }
}
