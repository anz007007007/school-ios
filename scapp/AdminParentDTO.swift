import Foundation

struct AdminParentsResponseDTO: Codable {
    let items: [AdminParentDTO]
}

struct AdminParentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int
    let relation_type: String
    let login: String
    let full_name: String
    let is_active: Bool
    let students: [AdminParentStudentShortDTO]

    var studentsText: String {
        if students.isEmpty {
            return "Дети не привязаны"
        }

        return students.map { $0.name }.joined(separator: ", ")
    }
}

struct AdminParentStudentShortDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct AdminParentMessageTeachersResponseDTO: Codable {
    let items: [AdminParentMessageTeacherDTO]
}

struct AdminParentMessageTeacherDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int
    let full_name: String
    let position: String?
    let is_allowed: Bool

    var teacher_id: Int {
        id
    }

    var displaySubtitle: String {
        let cleanPosition = position?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if cleanPosition.isEmpty {
            return "ID учителя: \(id), ID пользователя: \(user_id)"
        }

        return "\(cleanPosition) · ID учителя: \(id), ID пользователя: \(user_id)"
    }
}