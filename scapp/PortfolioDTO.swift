import Foundation

typealias PortfolioTheme = String
typealias PortfolioBlockType = String

enum PortfolioThemes {
    static let sunny = "sunny"
    static let classic = "classic"
    static let creative = "creative"
    static let olympic = "olympic"

    static let all: [String] = [
        sunny,
        classic,
        creative,
        olympic
    ]

    static func title(_ code: String) -> String {
        switch code {
        case sunny:
            return "Солнечная"
        case classic:
            return "Классическая"
        case creative:
            return "Креативная"
        case olympic:
            return "Олимпиадная"
        default:
            return code
        }
    }
}

enum PortfolioBlockTypes {
    static let achievement = "achievement"
    static let project = "project"
    static let skill = "skill"
    static let gallery = "gallery"
    static let timeline = "timeline"
    static let reflection = "reflection"

    static let all: [String] = [
        achievement,
        project,
        skill,
        gallery,
        timeline,
        reflection
    ]

    static func title(_ type: String) -> String {
        switch type {
        case achievement:
            return "Карта достижений"
        case project:
            return "Проекты"
        case skill:
            return "Skill-паспорт"
        case gallery:
            return "Галерея работ"
        case timeline:
            return "Лента времени"
        case reflection:
            return "Мета-рефлексия"
        default:
            return type
        }
    }

    static func icon(_ type: String) -> String {
        switch type {
        case achievement:
            return "trophy.fill"
        case project:
            return "folder.fill"
        case skill:
            return "star.circle.fill"
        case gallery:
            return "photo.on.rectangle.angled"
        case timeline:
            return "clock.arrow.circlepath"
        case reflection:
            return "quote.bubble.fill"
        default:
            return "square.grid.2x2.fill"
        }
    }
}

struct PortfolioStudentsResponseDTO: Decodable {
    let items: [PortfolioStudentDTO]
}

struct PortfolioFallbackStudentsResponseDTO: Decodable {
    let items: [PortfolioFallbackStudentDTO]
}

struct PortfolioFallbackStudentDTO: Decodable {
    let id: Int
    let user_id: Int?
    let class_id: Int?
    let student_name: String?
    let full_name: String?
    let name: String?
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let class_name: String?

    var asPortfolioStudent: PortfolioStudentDTO {
        let composedName = [
            last_name,
            first_name,
            middle_name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        return PortfolioStudentDTO(
            id: id,
            user_id: user_id,
            class_id: class_id,
            student_name: student_name
                ?? full_name
                ?? name
                ?? (composedName.isEmpty ? "Ученик \(id)" : composedName),
            class_name: class_name
        )
    }
}

struct PortfolioStudentDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let user_id: Int?
    let class_id: Int?
    let student_name: String
    let class_name: String?
}

struct PortfolioDTO: Identifiable, Codable {
    let id: Int?
    let student_id: Int
    let student_name: String
    let class_name: String?

    var title: String?
    var tagline: String?
    var summary: String?
    var avatar_url: String?

    let public_url: String?
    let public_token: String?
    var theme_code: PortfolioTheme
    var is_public: Bool

    let can_edit: Bool
    let can_review: Bool

    let rating: PortfolioRatingDTO?
    var blocks: [PortfolioBlockDTO]
    var badges: [PortfolioBadgeDTO]
    let reviews: [PortfolioTeacherReviewDTO]
}

struct PortfolioRatingDTO: Codable {
    let average_grade: Double?
    let previous_average_grade: Double?
    let average_delta: Double?

    let school_rank: Int?
    let previous_school_rank: Int?
    let school_rank_delta: Int?
    let school_total: Int

    let class_rank: Int?
    let previous_class_rank: Int?
    let class_rank_delta: Int?
    let class_total: Int

    let grades_count: Int
    let previous_grades_count: Int

    let trend: String
}

struct PortfolioBlockDTO: Identifiable, Codable, Hashable {
    var id: Int
    var block_type: PortfolioBlockType

    var title: String
    var category: String?
    var period_label: String?
    var event_date: String?

    var description: String?

    var image_url: String?
    var file_url: String?
    var file_name: String?
    var file_type: String?

    var level_value: Int?
    var sort_order: Int

    var created_by_user_id: Int?
    var created_at: String?
    var updated_at: String?

    static func empty(type: String, sortOrder: Int) -> PortfolioBlockDTO {
        PortfolioBlockDTO(
            id: Int(Date().timeIntervalSince1970 * 1000),
            block_type: type,
            title: "",
            category: nil,
            period_label: nil,
            event_date: nil,
            description: nil,
            image_url: nil,
            file_url: nil,
            file_name: nil,
            file_type: nil,
            level_value: nil,
            sort_order: sortOrder,
            created_by_user_id: nil,
            created_at: nil,
            updated_at: nil
        )
    }
}

struct PortfolioBadgeDTO: Identifiable, Codable, Hashable {
    var id: Int
    var title: String
    var badge_type: String
    var description: String?
    var icon: String?
    var sort_order: Int

    static func empty(sortOrder: Int) -> PortfolioBadgeDTO {
        PortfolioBadgeDTO(
            id: Int(Date().timeIntervalSince1970 * 1000),
            title: "Новый бейдж",
            badge_type: "custom",
            description: nil,
            icon: "star.fill",
            sort_order: sortOrder
        )
    }
}

struct PortfolioTeacherReviewDTO: Identifiable, Codable, Hashable {
    let id: Int
    let teacher_user_id: Int
    let teacher_name: String
    let title: String
    let body: String
    let is_visible: Bool
    let created_at: String
}

struct PortfolioSaveResponseDTO: Decodable {
    let status: String
    let portfolio_id: Int
}

struct PortfolioReviewCreateResponseDTO: Decodable {
    let status: String
}

struct PortfolioUploadResponseDTO: Decodable {
    let url: String
    let file_name: String
    let file_type: String
}

struct PortfolioSaveRequestDTO: Encodable {
    let student_id: Int
    let title: String?
    let tagline: String?
    let summary: String?
    let avatar_url: String?
    let theme_code: PortfolioTheme
    let is_public: Bool
    let blocks: [PortfolioBlockDTO]
    let badges: [PortfolioBadgeDTO]
}

struct PortfolioReviewCreateRequestDTO: Encodable {
    let portfolio_id: Int
    let title: String
    let body: String
}