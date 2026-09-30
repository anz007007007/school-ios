import Foundation

struct AdminTeachersResponseDTO: Codable {
    let items: [AdminTeacherDTO]
}

struct AdminTeacherDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int
    let login: String
    let full_name: String
    let is_active: Bool
    let assignments_list: [AdminTeacherAssignmentDTO]

    var assignmentsText: String {
        if assignments_list.isEmpty {
            return "Нет назначений"
        }

        return assignments_list.map { $0.label }.joined(separator: ", ")
    }
}

struct AdminTeacherAssignmentDTO: Codable, Identifiable, Hashable {
    let class_id: Int
    let class_name: String
    let label: String

    var id: String {
        "\(class_id)-\(label)"
    }
}
