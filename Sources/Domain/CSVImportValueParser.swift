import Foundation

public enum CSVImportValueParser {
    public static func normalizedHeaderName(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    public static func date(from rawValue: String) -> Date? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            return nil
        }

        if let timestampSeparator = trimmedValue.firstIndex(of: "T") {
            let datePortion = String(trimmedValue[..<timestampSeparator])
            if let date = parseDate(datePortion) {
                return date
            }
        }

        return parseDate(trimmedValue)
    }

    public static func decimal(from rawValue: String) -> Decimal? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            return nil
        }

        let usesParenthesesForNegative = trimmedValue.hasPrefix("(") && trimmedValue.hasSuffix(")")
        var sanitizedValue = trimmedValue

        if usesParenthesesForNegative {
            sanitizedValue.removeFirst()
            sanitizedValue.removeLast()
        }

        sanitizedValue = sanitizedValue.unicodeScalars
            .filter { allowedDecimalCharacters.contains($0) }
            .map(String.init)
            .joined()

        guard sanitizedValue.isEmpty == false else {
            return nil
        }

        if usesParenthesesForNegative, sanitizedValue.hasPrefix("-") == false {
            sanitizedValue = "-" + sanitizedValue
        }

        return Decimal(string: sanitizedValue, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func parseDate(_ value: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static let allowedDecimalCharacters = CharacterSet(charactersIn: "0123456789-+.")

    private static let dateFormatters: [DateFormatter] = [
        makeDateFormatter("yyyy-MM-dd"),
        makeDateFormatter("MM/dd/yyyy"),
        makeDateFormatter("M/d/yyyy"),
        makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss"),
        makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSS"),
    ]

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}
