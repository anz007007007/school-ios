import Foundation

struct TextbooksListResponseDTO: Decodable {
    let items: [TextbookDTO]
}

struct TextbookDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let material_type: String
    let class_id: Int?
    let class_name: String?
    let subject_id: Int?
    let subject_name: String?
    let sort_order: Int?
    let is_active: Bool
    let file_url: String?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case material_type
        case class_id
        case class_name
        case subject_id
        case subject_name
        case sort_order
        case is_active
        case file_url
        case created_at
        case updated_at
    }

    var typeTitle: String {
        switch material_type {
        case "textbook":
            return "Учебник"
        case "literature":
            return "Литература"
        case "workbook":
            return "Рабочая тетрадь"
        case "methodical":
            return "Методичка"
        case "presentation":
            return "Презентация"
        default:
            return "Материал"
        }
    }

    var fullFileURL: URL? {
        guard let file_url,
              !file_url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if file_url.lowercased().hasPrefix("http://") || file_url.lowercased().hasPrefix("https://") {
            return URL(string: file_url)
        }

        return URL(string: "https://sc.it-status.ru\(file_url)")
    }

    var subtitle: String {
        let parts = [
            class_name,
            subject_name,
            typeTitle
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.isEmpty ? typeTitle : parts.joined(separator: " · ")
    }

    var normalizedSearchText: String {
        [
            title,
            description ?? "",
            typeTitle,
            class_name ?? "",
            subject_name ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }
}

struct TextbookFiltersResponseDTO: Decodable {
    let classes: [TextbookClassFilterDTO]
    let subjects: [TextbookSubjectFilterDTO]
    let material_types: [TextbookMaterialTypeFilterDTO]?

    enum CodingKeys: String, CodingKey {
        case classes
        case subjects
        case material_types
        case materialTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        classes = try container.decodeIfPresent([TextbookClassFilterDTO].self, forKey: .classes) ?? []
        subjects = try container.decodeIfPresent([TextbookSubjectFilterDTO].self, forKey: .subjects) ?? []
        material_types = try container.decodeIfPresent([TextbookMaterialTypeFilterDTO].self, forKey: .material_types)
            ?? container.decodeIfPresent([TextbookMaterialTypeFilterDTO].self, forKey: .materialTypes)
    }
}

struct TextbookClassFilterDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case class_name
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .class_name)
            ?? "Класс \(id)"
    }
}

struct TextbookSubjectFilterDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case subject_name
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .subject_name)
            ?? "Предмет \(id)"
    }
}

struct TextbookMaterialTypeFilterDTO: Decodable, Identifiable, Hashable {
    let code: String
    let name: String

    var id: String {
        code
    }

    enum CodingKeys: String, CodingKey {
        case code
        case value
        case name
        case title
        case label
    }

    init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decodeIfPresent(String.self, forKey: .code)
            ?? container.decodeIfPresent(String.self, forKey: .value)
            ?? ""

        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? code
    }
}

struct TextbookFormData: Hashable {
    var title: String
    var description: String
    var materialType: String
    var classID: Int
    var subjectID: Int
    var sortOrder: Int
    var isActive: Bool
    var fileURL: URL?
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