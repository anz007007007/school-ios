import Foundation

/// Ввод дат в формах админки и финансов: пользователь пишет `дд.мм.гггг`,
/// на сервер уходит ISO `yyyy-MM-dd`.
enum AdminDateInput {
    /// `yyyy-MM-dd` (или дата со временем) → `дд.мм.гггг`; пустая строка, если не разобрать.
    static func display(fromISO value: String?) -> String {
        guard let value, let date = isoFormatter.date(from: String(value.prefix(10))) else {
            return ""
        }

        return displayFormatter.string(from: date)
    }

    static func display(from date: Date) -> String {
        displayFormatter.string(from: date)
    }

    /// `дд.мм.гггг` (допускается и `yyyy-MM-dd`) → `yyyy-MM-dd`; nil, если дата некорректна.
    static func iso(fromDisplay value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            return nil
        }

        if let date = displayFormatter.date(from: clean),
           displayFormatter.string(from: date) == clean {
            return isoFormatter.string(from: date)
        }

        if let date = isoFormatter.date(from: clean),
           isoFormatter.string(from: date) == clean {
            return clean
        }

        return nil
    }

    static func iso(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func date(fromISO value: String) -> Date? {
        isoFormatter.date(from: String(value.prefix(10)))
    }

    /// Текущий учебный год вида `2026-2027` (с сентября — новый).
    static var currentAcademicYear: String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
        let year = components.year ?? 2026
        let startYear = (components.month ?? 9) >= 8 ? year : year - 1
        return "\(startYear)-\(startYear + 1)"
    }

    private static let displayFormatter: DateFormatter = makeFormatter("dd.MM.yyyy")
    private static let isoFormatter: DateFormatter = makeFormatter("yyyy-MM-dd")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
