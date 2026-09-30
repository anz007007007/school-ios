import Foundation

struct DiaryGradesResponseDTO: Codable {
    let items: [DiaryGradeDTO]
}

struct DiaryGradeTypesResponseDTO: Codable {
    let items: [DiaryGradeTypeDTO]
}

struct DiaryGradeTypeDTO: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let description: String?
    let weight: String?
    let is_active: Bool?
    let sort_order: Int?

    var id: String {
        code
    }

    var displayName: String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? code : clean
    }
}

struct DiaryGradeDTO: Codable, Identifiable, Hashable {
    let id: Int
    let grade_value: String
    let grade_type: String
    let grade_date: String
    let comment: String?
    let student_id: Int
    let student_name: String
    let subject_id: Int
    let subject_name: String
    let class_id: Int
    let class_name: String

    let teacher_id: Int?
    let teacher_name: String?
    let teacher_full_name: String?
    let created_by_user_id: Int?
    let created_by_name: String?
    let created_by_full_name: String?
    let grade_weight: String?
    let weight: String?
    let period_name: String?
    let term_name: String?
    let lesson_topic: String?
    let homework_title: String?
    let created_at: String?
    let updated_at: String?

    var commentText: String? {
        let clean = (comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    var teacherDisplayName: String? {
        [
            teacher_name,
            teacher_full_name,
            created_by_name,
            created_by_full_name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    var gradeWeightText: String? {
        [
            grade_weight,
            weight
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    var periodDisplayName: String? {
        [
            period_name,
            term_name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    var lessonTopicText: String? {
        let clean = (lesson_topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    var homeworkTitleText: String? {
        let clean = (homework_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    var createdAtText: String? {
        let clean = (created_at ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    var updatedAtText: String? {
        let clean = (updated_at ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}