import Foundation

struct AdminGradeTypesResponseDTO: Codable {
    let items: [AdminGradeTypeDTO]
}

struct AdminGradeTypeDTO: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let description: String?
    let weight: String?
    let is_active: Bool
    let sort_order: Int?

    var id: String {
        code
    }

    var weightText: String {
        let clean = (weight ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "1.00" : clean
    }

    var descriptionText: String {
        let clean = (description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Описание не указано" : clean
    }
}

struct AdminGradeTypeFormData: Hashable {
    var code: String = ""
    var name: String = ""
    var description: String = ""
    var weight: String = "1.00"
    var isActive: Bool = true
    var sortOrder: Int = 10
}