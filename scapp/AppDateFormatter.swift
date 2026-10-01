import Foundation

/// Shared display formatting for dates coming from the API (various raw string shapes)
/// into the app-wide `dd.MM.yyyy` / `dd.MM.yyyy HH:mm` presentation. Does not affect the
/// formats used to send dates back to the API.
enum AppDateFormatter {
    static func parse(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        if let date = isoFormatterWithFractionalSeconds.date(from: trimmed) {
            return date
        }

        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        for formatter in fallbackFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    /// `dd.MM.yyyy`. Returns "—" for nil/empty input, the original string if parsing fails.
    static func date(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "—"
        }

        guard let date = parse(value) else {
            return value
        }

        return dateOnlyFormatter.string(from: date)
    }

    static func date(_ value: Date?) -> String {
        guard let value else {
            return "—"
        }

        return dateOnlyFormatter.string(from: value)
    }

    /// `dd.MM.yyyy HH:mm` when the source string carries a time component, `dd.MM.yyyy` otherwise.
    static func dateTime(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "—"
        }

        guard let date = parse(value) else {
            return value
        }

        guard hasTimeComponent(value) else {
            return dateOnlyFormatter.string(from: date)
        }

        return dateTimeFormatter.string(from: date)
    }

    static func dateTime(_ value: Date?) -> String {
        guard let value else {
            return "—"
        }

        return dateTimeFormatter.string(from: value)
    }

    /// `01.09.2026 — 31.10.2026`
    static func range(_ from: String?, _ to: String?) -> String {
        "\(date(from)) — \(date(to))"
    }

    /// `yyyy-MM` billing period codes → `MM.yyyy`.
    static func monthYear(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "—"
        }

        guard let date = monthYearInputFormatter.date(from: value) else {
            return value
        }

        return monthYearOutputFormatter.string(from: date)
    }

    private static func hasTimeComponent(_ value: String) -> Bool {
        value.contains(":")
    }

    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackFormatters: [DateFormatter] = {
        let formats = [
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let monthYearInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let monthYearOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
