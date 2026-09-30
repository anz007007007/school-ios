import Foundation

struct DiaryFiltersResponseDTO: Decodable, Hashable {
    let students: [DiaryFilterStudentDTO]
    let subjects: [DiaryFilterSubjectDTO]
    let grade_types: [DiaryFilterGradeTypeDTO]
    let current_term: DiaryAcademicTermDTO?
    let current_year: DiaryAcademicTermDTO?

    enum CodingKeys: String, CodingKey {
        case students
        case subjects
        case grade_types
        case current_term
        case current_year
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        students = try container.decodeIfPresent([DiaryFilterStudentDTO].self, forKey: .students) ?? []
        subjects = try container.decodeIfPresent([DiaryFilterSubjectDTO].self, forKey: .subjects) ?? []
        grade_types = try container.decodeIfPresent([DiaryFilterGradeTypeDTO].self, forKey: .grade_types) ?? []
        current_term = try container.decodeIfPresent(DiaryAcademicTermDTO.self, forKey: .current_term)
        current_year = try container.decodeIfPresent(DiaryAcademicTermDTO.self, forKey: .current_year)
    }
}

struct DiaryAcademicTermDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let academic_year: String
    let term_type: String
    let term_number: Int?
    let starts_at: String
    let ends_at: String

    var dateRange: (start: Date, end: Date)? {
        guard let start = Self.dateFormatter.date(from: starts_at),
              let end = Self.dateFormatter.date(from: ends_at) else {
            return nil
        }

        return (start, end)
    }

    var displayRangeText: String {
        "\(starts_at) — \(ends_at)"
    }

    var isQuarter: Bool {
        term_type == "quarter"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

struct DiaryFilterStudentDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case student_name
        case full_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .full_name)
    }
}

struct DiaryFilterSubjectDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subject_name
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .subject_name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
    }
}

struct DiaryFilterGradeTypeDTO: Decodable, Identifiable, Hashable {
    let code: String
    let name: String?

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decodeIfPresent(String.self, forKey: .code)
            ?? container.decodeIfPresent(String.self, forKey: .value)
            ?? ""

        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}