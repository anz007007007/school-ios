import Foundation

/// Вид учебного периода. Сервер (`diary.py` `_get_current_term`) отдаёт текущим периодом
/// четверть, триместр или полугодие (`term_type` quarter | trimester | semester).
enum AcademicTermKind: String, Hashable {
    case quarter
    case trimester
    case semester

    /// «Четверть», «Триместр», «Полугодие».
    var title: String {
        switch self {
        case .quarter: return "Четверть"
        case .trimester: return "Триместр"
        case .semester: return "Полугодие"
        }
    }

    /// Короткая подпись для переключателя периода.
    var shortTitle: String {
        switch self {
        case .quarter: return "Четв."
        case .trimester: return "Трим."
        case .semester: return "Полуг."
        }
    }

    /// «Текущая четверть», «Текущий триместр», «Текущее полугодие».
    var currentTitle: String {
        switch self {
        case .quarter: return "Текущая четверть"
        case .trimester: return "Текущий триместр"
        case .semester: return "Текущее полугодие"
        }
    }

    /// «за текущую четверть», «за текущий триместр», «за текущее полугодие».
    var forCurrentTitle: String {
        switch self {
        case .quarter: return "за текущую четверть"
        case .trimester: return "за текущий триместр"
        case .semester: return "за текущее полугодие"
        }
    }

    /// nil — период не четверть/триместр/полугодие (например, учебный год).
    static func from(termType: String?, name: String?) -> AcademicTermKind? {
        let type = (termType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch type {
        case "quarter", "четверть":
            return .quarter
        case "trimester", "триместр":
            return .trimester
        case "semester", "полугодие", "семестр":
            return .semester
        case "":
            break
        default:
            return nil
        }

        if lowerName.contains("четвер") || lowerName.contains("quarter") {
            return .quarter
        }

        if lowerName.contains("триместр") || lowerName.contains("trimester") {
            return .trimester
        }

        if lowerName.contains("полугод") || lowerName.contains("семестр") || lowerName.contains("semester") {
            return .semester
        }

        return nil
    }
}

enum AcademicPeriods {
    /// Учебный год, в который попадает `today`: 1 сентября — 31 августа.
    static func schoolYearRange(today: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let startYear = month >= 9 ? year : year - 1

        let start = calendar.date(from: DateComponents(year: startYear, month: 9, day: 1)) ?? today
        let end = calendar.date(from: DateComponents(year: startYear + 1, month: 8, day: 31)) ?? today

        return (start, end)
    }
}
