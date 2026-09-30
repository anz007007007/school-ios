import Foundation

struct AdminStudentsResponseDTO: Codable {
    let items: [AdminStudentDTO]
}

struct AdminStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let first_name: String
    let last_name: String
    let gender: String
    let status: String
    let class_id: Int?
    let class_name: String?

    var fullName: String {
        "\(last_name) \(first_name)"
    }

    var classTitle: String {
        if let class_name, !class_name.isEmpty {
            return class_name
        }

        return "Класс не указан"
    }
}