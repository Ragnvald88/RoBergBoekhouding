import SwiftUI

// MARK: - Uurwerker Color Palette
extension Color {
    // MARK: - Brand Colors
    /// Primary brand blue - used for main actions and navigation
    static let uurwerkerBlue = Color(red: 0.102, green: 0.212, blue: 0.365) // #1a365d

    /// Accent gold - used for highlights and premium features
    static let uurwerkerGold = Color(red: 0.839, green: 0.620, blue: 0.180) // #d69e2e

    // MARK: - Semantic Colors
    /// Success state - payments received, goals achieved
    static let uurwerkerSuccess = Color(red: 0.220, green: 0.631, blue: 0.412) // #38a169

    /// Warning state - overdue soon, approaching limits
    static let uurwerkerWarning = Color(red: 0.867, green: 0.420, blue: 0.125) // #dd6b20

    /// Error state - overdue, validation errors
    static let uurwerkerError = Color(red: 0.898, green: 0.243, blue: 0.243) // #e53e3e

    /// Info state - tips, neutral information
    static let uurwerkerInfo = Color(red: 0.192, green: 0.510, blue: 0.788) // #3182ce

    // MARK: - Invoice Status Colors
    static let statusConcept = Color.secondary
    static let statusVerzonden = Color.uurwerkerInfo
    static let statusBetaald = Color.uurwerkerSuccess
    static let statusHerinnering = Color.uurwerkerWarning
    static let statusOninbaar = Color.uurwerkerError

    // MARK: - Backgrounds
    static let cardBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let elevatedBackground = Color(nsColor: .underPageBackgroundColor)
}

// MARK: - Color from Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
