import Foundation

struct AdminScheduleResponseDTO: Codable {
    let items: [AdminScheduleLessonDTO]
}

struct AdminScheduleLessonDTO: Codable, Identifiable, Hashable {
    let id: Int
    let class_id: Int
    let subject_id: Int
    let teacher_id: Int?
    let weekday: Int
    let lesson_number: Int
    let starts_at: String
    let ends_at: String
    let class_name: String
    let subject_name: String
    let teacher_name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case class_id
        case subject_id
        case teacher_id
        case weekday
        case lesson_number
        case starts_at
        case ends_at
        case class_name
        case subject_name
        case teacher_name
    }

    init(
        id: Int,
        class_id: Int,
        subject_id: Int,
        teacher_id: Int?,
        weekday: Int,
        lesson_number: Int,
        starts_at: String,
        ends_at: String,
        class_name: String,
        subject_name: String,
        teacher_name: String?
    ) {
        self.id = id
        self.class_id = class_id
        self.subject_id = subject_id
        self.teacher_id = teacher_id
        self.weekday = weekday
        self.lesson_number = lesson_number
        self.starts_at = starts_at
        self.ends_at = ends_at
        self.class_name = class_name
        self.subject_name = subject_name
        self.teacher_name = teacher_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        class_id = try container.decodeFlexibleInt(forKey: .class_id) ?? 0
        subject_id = try container.decodeFlexibleInt(forKey: .subject_id) ?? 0
        teacher_id = try container.decodeFlexibleInt(forKey: .teacher_id)
        weekday = try container.decodeFlexibleInt(forKey: .weekday) ?? 1
        lesson_number = try container.decodeFlexibleInt(forKey: .lesson_number) ?? 1
        starts_at = try container.decodeIfPresent(String.self, forKey: .starts_at) ?? ""
        ends_at = try container.decodeIfPresent(String.self, forKey: .ends_at) ?? ""
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name) ?? "Класс"
        subject_name = try container.decodeIfPresent(String.self, forKey: .subject_name) ?? "Предмет"
        teacher_name = try container.decodeIfPresent(String.self, forKey: .teacher_name)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }

        return nil
    }
}