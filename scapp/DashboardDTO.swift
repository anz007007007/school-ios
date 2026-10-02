import Foundation

struct DashboardResponseDTO: Decodable, Hashable {
    let role_code: String?
    let title: String?
    let subtitle: String?
    let cards: [DashboardCardDTO]
    let quick_actions: [DashboardQuickActionDTO]
    let items: [DashboardItemDTO]
    let birthdays: [DashboardBirthdayDTO]

    enum CodingKeys: String, CodingKey {
        case role_code
        case title
        case subtitle
        case cards
        case quick_actions
        case items
        case birthdays
    }

    init(
        role_code: String?,
        title: String?,
        subtitle: String?,
        cards: [DashboardCardDTO],
        quick_actions: [DashboardQuickActionDTO],
        items: [DashboardItemDTO],
        birthdays: [DashboardBirthdayDTO] = []
    ) {
        self.role_code = role_code
        self.title = title
        self.subtitle = subtitle
        self.cards = cards
        self.quick_actions = quick_actions
        self.items = items
        self.birthdays = birthdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        role_code = try container.decodeIfPresent(String.self, forKey: .role_code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        cards = try container.decodeIfPresent([DashboardCardDTO].self, forKey: .cards) ?? []
        quick_actions = try container.decodeIfPresent([DashboardQuickActionDTO].self, forKey: .quick_actions) ?? []
        items = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .items) ?? []
        birthdays = try container.decodeIfPresent([DashboardBirthdayDTO].self, forKey: .birthdays) ?? []
    }
}

struct DashboardBirthdayDTO: Decodable, Identifiable, Hashable {
    let student_id: Int
    let student_name: String
    let birth_date: String
    let birthday_date: String
    let days_offset: Int
    let status: String
    let class_id: Int?
    let class_name: String?
    let age: Int?

    var id: String {
        "\(student_id)-\(birthday_date)"
    }

    var displayName: String {
        let cleanName = student_name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? "Ученик \(student_id)" : cleanName
    }

    var displayClassName: String {
        let cleanClass = class_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanClass.isEmpty ? "Класс не указан" : cleanClass
    }

    var ageText: String? {
        guard let age else {
            return nil
        }

        return "исполняется \(age)"
    }

    var timingText: String {
        switch status {
        case "today":
            if let ageText {
                return "Сегодня, \(ageText)"
            }

            return "Сегодня"

        case "upcoming":
            if days_offset == 1 {
                return "Завтра"
            }

            return "Через \(days_offset) \(dayWord(abs(days_offset)))"

        case "past":
            let days = abs(days_offset)

            if days == 1 {
                return "Вчера"
            }

            return "\(days) \(dayWord(days)) назад"

        default:
            if days_offset == 0 {
                return "Сегодня"
            }

            if days_offset > 0 {
                return "Через \(days_offset) \(dayWord(days_offset))"
            }

            let days = abs(days_offset)
            return "\(days) \(dayWord(days)) назад"
        }
    }

    var statusTitle: String {
        switch status {
        case "today":
            return "Сегодня"
        case "upcoming":
            return "Скоро"
        case "past":
            return "Недавно были"
        default:
            return "Дни рождения"
        }
    }

    private func dayWord(_ value: Int) -> String {
        let mod10 = value % 10
        let mod100 = value % 100

        if mod10 == 1 && mod100 != 11 {
            return "день"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "дня"
        }

        return "дней"
    }
}

struct FamilyDashboardResponseDTO: Decodable, Hashable {
    let role_code: String?
    let title: String?
    let subtitle: String?
    let students: [DashboardStudentDTO]
    let cards: [DashboardCardDTO]
    let quick_actions: [DashboardQuickActionDTO]
    let timeline: [DashboardItemDTO]
    let alerts: [DashboardItemDTO]
    let today: [DashboardItemDTO]
    let week: [DashboardItemDTO]
    let items: [DashboardItemDTO]

    enum CodingKeys: String, CodingKey {
        case role_code
        case title
        case subtitle
        case students
        case cards
        case quick_actions
        case timeline
        case alerts
        case today
        case week
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        role_code = try container.decodeIfPresent(String.self, forKey: .role_code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        students = try container.decodeIfPresent([DashboardStudentDTO].self, forKey: .students) ?? []
        cards = try container.decodeIfPresent([DashboardCardDTO].self, forKey: .cards) ?? []
        quick_actions = try container.decodeIfPresent([DashboardQuickActionDTO].self, forKey: .quick_actions) ?? []
        timeline = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .timeline) ?? []
        alerts = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .alerts) ?? []
        today = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .today) ?? []
        week = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .week) ?? []
        items = try container.decodeIfPresent([DashboardItemDTO].self, forKey: .items) ?? []
    }
}

struct DashboardCardDTO: Decodable, Identifiable, Hashable {
    let label: String
    let value: DashboardFlexibleValue

    var id: String {
        "\(label)-\(value.displayText)"
    }
}

struct DashboardItemDTO: Decodable, Identifiable, Hashable {
    let title: String

    var id: String {
        title
    }
}

struct DashboardQuickActionDTO: Decodable, Identifiable, Hashable {
    let label: String?
    let url: String?

    var id: String {
        "\(label ?? "")-\(url ?? "")"
    }
}

struct DashboardStudentDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let student_name: String?
    let full_name: String?
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let class_name: String?

    var displayName: String {
        if let student_name, !student_name.isEmpty {
            return student_name
        }

        if let full_name, !full_name.isEmpty {
            return full_name
        }

        let parts = [
            last_name,
            first_name,
            middle_name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        if parts.isEmpty {
            return "Ученик \(id)"
        }

        return parts.joined(separator: " ")
    }

    var displaySubtitle: String {
        class_name ?? "Класс не указан"
    }
}

enum DashboardFlexibleValue: Decodable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case unknown

    var displayText: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return "\(value)"
        case .double(let value):
            if value.rounded() == value {
                return "\(Int(value))"
            }

            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "Да" : "Нет"
        case .unknown:
            return "—"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        self = .unknown
    }
}

struct MobileConfigResponseDTO: Decodable, Hashable {
    let api_version: String?
    let user: MobileConfigUserDTO?
    let features: MobileConfigFeaturesDTO?
    /// Код калитки для вошедших; nil — не задан.
    let gate_code: String?
    /// Сборка ниже минимальной — предложить обновиться.
    let update_required: Bool?
    let store_url: String?
}

struct MobileConfigUserDTO: Decodable, Hashable {
    let id: Int?
    let role_code: String?
    let role_name: String?
}

struct MobileConfigFeaturesDTO: Decodable, Hashable {
    let diary: Bool?
    let homework: Bool?
    let events: Bool?
    let clubs: Bool?
    let finance: Bool?
    let messages: Bool?
    let analytics: Bool?
    let push_notifications: Bool?
}

struct AnalyticsResponseDTO: Decodable, Hashable {
    let students: Int?
    let active_students: Int?
    let teachers: Int?
    let classes: Int?
    let active_users: Int?
    let finance_total_debt: String?
    let unpaid_invoices: Int?
    let overdue_invoices: Int?
}

struct DashboardStudentsListResponseDTO: Decodable {
    let items: [DashboardStudentDTO]
}

struct DashboardGradesListResponseDTO: Decodable {
    let items: [DashboardGradeDTO]
}

struct DashboardGradeDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let grade_value: String
    let grade_type: String
    let grade_date: String
    let student_id: Int
    let student_name: String
    let subject_id: Int
    let subject_name: String
    let class_id: Int
    let class_name: String

    var numericValue: Double? {
        Double(grade_value.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Новые модели для бэкенда

enum FlexibleDecimalString: Decodable, Hashable {
    case string(String)
    case double(Double)
    case int(Int)

    var displayText: String {
        switch self {
        case .string(let value):
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "—" : clean
        case .double(let value):
            return String(format: "%.2f", value)
        case .int(let value):
            return "\(value)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        self = .string("")
    }
}

struct GradeCalculatedPeriodResponseDTO: Decodable, Hashable {
    let student_id: Int?
    let subject_id: Int?
    let period_type: String?
    let period_id: Int?
    let period_name: String?
    let grades_count: Int?
    let average_grade: FlexibleDecimalString?
    let calculated_grade: String?
    let comment: String?

    var calculatedGradeText: String {
        let clean = (calculated_grade ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "—" : clean
    }

    var averageGradeText: String {
        average_grade?.displayText ?? "—"
    }
}

struct DashboardSubjectAverageDTO: Identifiable, Hashable {
    let subjectID: Int
    let subjectName: String
    let gradesCount: Int
    let todayGradesText: String
    let average: Double?
    let calculatedQuarterGrade: GradeCalculatedPeriodResponseDTO?
    let calculatedYearGrade: GradeCalculatedPeriodResponseDTO?

    var id: Int {
        subjectID
    }

    var averageText: String {
        guard let average else {
            return "—"
        }

        return String(format: "%.2f", average)
    }

    var calculatedQuarterGradeText: String {
        calculatedQuarterGrade?.calculatedGradeText ?? "—"
    }

    var calculatedYearGradeText: String {
        calculatedYearGrade?.calculatedGradeText ?? "—"
    }
}