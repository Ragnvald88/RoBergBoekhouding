import Foundation

// MARK: - Dutch Number Formatter
struct DutchNumberFormatter {
    /// Dutch locale for formatting
    static let locale = Locale(identifier: "nl_NL")

    /// Currency formatter (e.g., "€ 630,00")
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Decimal formatter (e.g., "9,00")
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Integer formatter (e.g., "1.234")
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// Percentage formatter (e.g., "80%")
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.multiplier = 1
        return formatter
    }()

    // MARK: - Formatting Methods

    /// Format as currency: "€ 630,00"
    static func formatCurrency(_ value: Decimal) -> String {
        currency.string(from: value as NSDecimalNumber) ?? "€ 0,00"
    }

    /// Format as decimal: "9,00"
    static func formatDecimal(_ value: Decimal) -> String {
        decimal.string(from: value as NSDecimalNumber) ?? "0,00"
    }

    /// Format as integer with thousands separator: "1.234"
    static func formatInteger(_ value: Int) -> String {
        integer.string(from: NSNumber(value: value)) ?? "0"
    }

    /// Format as percentage: "80%"
    static func formatPercentage(_ value: Decimal) -> String {
        percentage.string(from: value as NSDecimalNumber) ?? "0%"
    }

    // MARK: - Parsing Methods

    /// Parse Dutch currency string to Decimal: "€ 630,00" -> 630.00
    static func parseCurrency(_ string: String) -> Decimal? {
        var cleanString = string
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Handle Dutch decimal separator
        cleanString = cleanString.replacingOccurrences(of: ".", with: "")
        cleanString = cleanString.replacingOccurrences(of: ",", with: ".")

        return Decimal(string: cleanString)
    }

    /// Parse Dutch decimal string to Decimal: "9,00" -> 9.0
    static func parseDecimal(_ string: String) -> Decimal? {
        let cleanString = string
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        return Decimal(string: cleanString)
    }

    /// Parse integer from string: "108" -> 108
    static func parseInteger(_ string: String) -> Int? {
        let cleanString = string
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Int(cleanString)
    }
}

// MARK: - Dutch Date Formatter
struct DutchDateFormatter {
    /// Dutch locale
    static let locale = Locale(identifier: "nl_NL")

    /// Date formatter for display: "29 november 2025"
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// Date formatter for lists: "29-11-2025"
    static let standard: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    /// Date formatter for invoice lines: "29-11"
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd-MM"
        return formatter
    }()

    /// Date formatter for month/year: "november 2025"
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Date formatter for CSV import: "DD/MM/YYYY"
    static let csvImport: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    // MARK: - Formatting Methods

    /// Format date as "29 november 2025"
    static func formatFull(_ date: Date) -> String {
        full.string(from: date)
    }

    /// Format date as "29-11-2025"
    static func formatStandard(_ date: Date) -> String {
        standard.string(from: date)
    }

    /// Format date as "29-11"
    static func formatShort(_ date: Date) -> String {
        short.string(from: date)
    }

    /// Format date as "november 2025"
    static func formatMonthYear(_ date: Date) -> String {
        monthYear.string(from: date)
    }

    // MARK: - Parsing Methods

    /// Parse date from CSV format: "08/05/2023" -> Date
    static func parseCSVDate(_ string: String) -> Date? {
        csvImport.date(from: string.trimmingCharacters(in: .whitespaces))
    }

    /// Parse date from standard format: "08-05-2023" -> Date
    static func parseStandardDate(_ string: String) -> Date? {
        standard.date(from: string.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Decimal Extensions
extension Decimal {
    /// Format as Dutch currency
    var asCurrency: String {
        DutchNumberFormatter.formatCurrency(self)
    }

    /// Format as Dutch decimal
    var asDecimal: String {
        DutchNumberFormatter.formatDecimal(self)
    }

    /// Format as percentage
    var asPercentage: String {
        DutchNumberFormatter.formatPercentage(self)
    }
}

// MARK: - Int Extensions
extension Int {
    /// Format as Dutch integer with thousands separator
    var formatted: String {
        DutchNumberFormatter.formatInteger(self)
    }
}

// MARK: - Date Extensions
extension Date {
    /// Format as full Dutch date
    var fullDutch: String {
        DutchDateFormatter.formatFull(self)
    }

    /// Format as standard Dutch date
    var standardDutch: String {
        DutchDateFormatter.formatStandard(self)
    }

    /// Format as short Dutch date
    var shortDutch: String {
        DutchDateFormatter.formatShort(self)
    }

    /// Format as month/year
    var monthYearDutch: String {
        DutchDateFormatter.formatMonthYear(self)
    }

    /// Get year component
    var year: Int {
        Calendar.current.component(.year, from: self)
    }

    /// Get month component
    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    /// Start of the year
    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// End of the year
    var endOfYear: Date {
        var components = DateComponents()
        components.year = 1
        components.day = -1
        return Calendar.current.date(byAdding: components, to: startOfYear) ?? self
    }

    /// Start of the month
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Start of the week (Monday)
    var startOfWeek: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - String Extensions for Parsing
extension String {
    /// Parse as Dutch currency
    var asDutchCurrency: Decimal? {
        DutchNumberFormatter.parseCurrency(self)
    }

    /// Parse as Dutch decimal
    var asDutchDecimal: Decimal? {
        DutchNumberFormatter.parseDecimal(self)
    }

    /// Parse as integer
    var asDutchInteger: Int? {
        DutchNumberFormatter.parseInteger(self)
    }

    /// Parse as CSV date
    var asCSVDate: Date? {
        DutchDateFormatter.parseCSVDate(self)
    }
}
