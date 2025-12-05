import SwiftUI

// MARK: - Uurwerker Typography
extension Font {
    // MARK: - Display Fonts
    /// Large title - main screen headers
    static let uurwerkerLargeTitle = Font.system(size: 34, weight: .bold, design: .default)

    /// Title - section headers
    static let uurwerkerTitle = Font.system(size: 28, weight: .semibold, design: .default)

    /// Title 2 - subsection headers
    static let uurwerkerTitle2 = Font.system(size: 22, weight: .semibold, design: .default)

    /// Title 3 - card headers
    static let uurwerkerTitle3 = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - Body Fonts
    /// Headline - emphasized body text
    static let uurwerkerHeadline = Font.system(size: 17, weight: .semibold, design: .default)

    /// Body - primary content
    static let uurwerkerBody = Font.system(size: 14, weight: .regular, design: .default)

    /// Callout - secondary content
    static let uurwerkerCallout = Font.system(size: 13, weight: .regular, design: .default)

    /// Subheadline - tertiary content
    static let uurwerkerSubheadline = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: - Utility Fonts
    /// Caption - labels, timestamps
    static let uurwerkerCaption = Font.system(size: 11, weight: .regular, design: .default)

    /// Caption 2 - smallest text
    static let uurwerkerCaption2 = Font.system(size: 10, weight: .regular, design: .default)

    /// Monospaced - numbers, codes, invoice numbers
    static let uurwerkerMono = Font.system(size: 14, weight: .medium, design: .monospaced)

    /// Monospaced small - table numbers
    static let uurwerkerMonoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
}
