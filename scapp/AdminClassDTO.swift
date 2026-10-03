import Foundation

struct AdminClassesResponseDTO: Codable {
    let items: [AdminClassDTO]
}

struct AdminClassDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let education_level: String
    let academic_year: String
    let students_count: Int

    let curator_teacher_id: Int?
    let curator_user_id: Int?
    let curator_name: String?

    /// Подразделение (новые серверы; старые поле не присылают).
    var division_id: Int? = nil
    var division_name: String? = nil

    var curatorText: String {
        let cleanName = curator_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if cleanName.isEmpty {
            return "Куратор не назначен"
        }

        return cleanName
    }
}