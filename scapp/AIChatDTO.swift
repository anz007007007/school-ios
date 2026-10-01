import Foundation

struct AIChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum Status: String, Codable {
        case sending
        case sent
        case error
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date
    var status: Status

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = Date(),
        status: Status = .sent
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
    }
}

struct AITeacherCommandPreviewRequestDTO: Encodable {
    let message: String
}

struct AITeacherCommandApplyRequestDTO: Encodable {
    let commands: [AITeacherCommandDTO]
}

struct AITeacherCommandPreviewResponseDTO: Decodable {
    let status: String
    let message: String?
    let provider: String?
    let model: String?
    let commands: [AITeacherCommandDTO]
    let raw: AITeacherCommandRawPreviewDTO?

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case provider
        case model
        case commands
        case raw
    }

    init(
        status: String,
        message: String?,
        provider: String?,
        model: String?,
        commands: [AITeacherCommandDTO],
        raw: AITeacherCommandRawPreviewDTO? = nil
    ) {
        self.status = status
        self.message = message
        self.provider = provider
        self.model = model
        self.commands = commands
        self.raw = raw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = container.decodeFlexibleStringIfPresent(forKey: .status) ?? "error"
        message = container.decodeFlexibleStringIfPresent(forKey: .message)
        provider = container.decodeFlexibleStringIfPresent(forKey: .provider)
        model = container.decodeFlexibleStringIfPresent(forKey: .model)

        let directCommands = (try? container.decodeIfPresent([AITeacherCommandDTO].self, forKey: .commands)) ?? []
        raw = try? container.decodeIfPresent(AITeacherCommandRawPreviewDTO.self, forKey: .raw)

        if directCommands.isEmpty, let rawCommands = raw?.commands, !rawCommands.isEmpty {
            commands = rawCommands
        } else {
            commands = directCommands
        }
    }
}

struct AITeacherCommandRawPreviewDTO: Decodable {
    let status: String?
    let message: String?
    let commands: [AITeacherCommandDTO]?

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case commands
    }

    init(
        status: String? = nil,
        message: String? = nil,
        commands: [AITeacherCommandDTO]? = nil
    ) {
        self.status = status
        self.message = message
        self.commands = commands
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = container.decodeFlexibleStringIfPresent(forKey: .status)
        message = container.decodeFlexibleStringIfPresent(forKey: .message)
        commands = try? container.decodeIfPresent([AITeacherCommandDTO].self, forKey: .commands)
    }
}

struct AITeacherCommandApplyResponseDTO: Decodable {
    let status: String
    let results: [AITeacherCommandApplyResultDTO]
}

struct AITeacherCommandApplyResultDTO: Decodable, Identifiable {
    let type: String
    let status: String
    let message: String?
    let object_id: Int?

    var id: String {
        "\(type)-\(status)-\(object_id ?? 0)-\(message ?? "")"
    }

    var typeTitle: String {
        switch type {
        case "create_grade":
            return "Оценка"
        case "create_homework":
            return "Домашнее задание"
        default:
            return type
        }
    }

    var statusTitle: String {
        switch status {
        case "created":
            return "Создано"
        case "skipped":
            return "Пропущено"
        case "error":
            return "Ошибка"
        default:
            return status
        }
    }
}

struct AITeacherCommandDTO: Codable, Identifiable, Equatable {
    var id = UUID()

    var type: String

    var student_id: Int?
    var student_name: String?
    var available_students: [AITeacherCommandOptionDTO]?

    var class_id: Int?
    var class_name: String?
    var available_classes: [AITeacherCommandOptionDTO]?

    var subject_id: Int?
    var subject_name: String?
    var available_subjects: [AITeacherCommandOptionDTO]?

    var grade_value: String?
    var available_grade_values: [AITeacherCommandStringOptionDTO]?

    var grade_type: String?
    var available_grade_types: [AITeacherCommandStringOptionDTO]?

    var grade_date: String?
    var comment: String?

    var homework_title: String?
    var homework_description: String?
    var due_date: String?

    var status: String
    var message: String?

    enum CodingKeys: String, CodingKey {
        case type
        case student_id
        case student_name
        case available_students
        case class_id
        case class_name
        case available_classes
        case subject_id
        case subject_name
        case available_subjects
        case grade_value
        case available_grade_values
        case grade_type
        case available_grade_types
        case grade_date
        case comment
        case homework_title
        case homework_description
        case due_date
        case status
        case message
    }

    init(
        type: String,
        student_id: Int? = nil,
        student_name: String? = nil,
        available_students: [AITeacherCommandOptionDTO]? = nil,
        class_id: Int? = nil,
        class_name: String? = nil,
        available_classes: [AITeacherCommandOptionDTO]? = nil,
        subject_id: Int? = nil,
        subject_name: String? = nil,
        available_subjects: [AITeacherCommandOptionDTO]? = nil,
        grade_value: String? = nil,
        available_grade_values: [AITeacherCommandStringOptionDTO]? = nil,
        grade_type: String? = nil,
        available_grade_types: [AITeacherCommandStringOptionDTO]? = nil,
        grade_date: String? = nil,
        comment: String? = nil,
        homework_title: String? = nil,
        homework_description: String? = nil,
        due_date: String? = nil,
        status: String,
        message: String? = nil
    ) {
        self.type = type
        self.student_id = student_id
        self.student_name = student_name
        self.available_students = available_students
        self.class_id = class_id
        self.class_name = class_name
        self.available_classes = available_classes
        self.subject_id = subject_id
        self.subject_name = subject_name
        self.available_subjects = available_subjects
        self.grade_value = grade_value
        self.available_grade_values = available_grade_values
        self.grade_type = grade_type
        self.available_grade_types = available_grade_types
        self.grade_date = grade_date
        self.comment = comment
        self.homework_title = homework_title
        self.homework_description = homework_description
        self.due_date = due_date
        self.status = status
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = container.decodeFlexibleStringIfPresent(forKey: .type) ?? ""
        student_id = container.decodeFlexibleIntIfPresent(forKey: .student_id)
        student_name = container.decodeFlexibleStringIfPresent(forKey: .student_name)
        available_students = try? container.decodeIfPresent([AITeacherCommandOptionDTO].self, forKey: .available_students)

        class_id = container.decodeFlexibleIntIfPresent(forKey: .class_id)
        class_name = container.decodeFlexibleStringIfPresent(forKey: .class_name)
        available_classes = try? container.decodeIfPresent([AITeacherCommandOptionDTO].self, forKey: .available_classes)

        subject_id = container.decodeFlexibleIntIfPresent(forKey: .subject_id)
        subject_name = container.decodeFlexibleStringIfPresent(forKey: .subject_name)
        available_subjects = try? container.decodeIfPresent([AITeacherCommandOptionDTO].self, forKey: .available_subjects)

        grade_value = container.decodeFlexibleStringIfPresent(forKey: .grade_value)
        available_grade_values = try? container.decodeIfPresent([AITeacherCommandStringOptionDTO].self, forKey: .available_grade_values)

        grade_type = container.decodeFlexibleStringIfPresent(forKey: .grade_type)
        available_grade_types = try? container.decodeIfPresent([AITeacherCommandStringOptionDTO].self, forKey: .available_grade_types)

        grade_date = container.decodeFlexibleStringIfPresent(forKey: .grade_date)
        comment = container.decodeFlexibleStringIfPresent(forKey: .comment)

        homework_title = container.decodeFlexibleStringIfPresent(forKey: .homework_title)
        homework_description = container.decodeFlexibleStringIfPresent(forKey: .homework_description)
        due_date = container.decodeFlexibleStringIfPresent(forKey: .due_date)

        status = container.decodeFlexibleStringIfPresent(forKey: .status) ?? "need_clarification"
        message = container.decodeFlexibleStringIfPresent(forKey: .message)
    }

    var typeTitle: String {
        switch type {
        case "create_grade":
            return "Оценка"
        case "create_homework":
            return "Домашнее задание"
        default:
            return type.isEmpty ? "Команда" : type
        }
    }

    var isReady: Bool {
        status == "ready"
    }

    var isSupported: Bool {
        type == "create_grade" || type == "create_homework"
    }

    var gradeTypeTitle: String {
        switch grade_type {
        case "regular":
            return "Обычная"
        case "control":
            return "Контрольная"
        case "homework":
            return "Домашняя работа"
        case "test":
            return "Тест"
        case "exam":
            return "Экзамен"
        case .some(let value):
            return value
        case .none:
            return "—"
        }
    }

    var formattedGradeDate: String {
        formatDate(grade_date)
    }

    var formattedDueDate: String {
        formatDate(due_date)
    }

    func missingFields() -> [AITeacherCommandMissingField] {
        var result: [AITeacherCommandMissingField] = []

        if type == "create_grade" {
            if student_id == nil {
                result.append(.student)
            }

            if class_id == nil {
                result.append(.class)
            }

            if subject_id == nil {
                result.append(.subject)
            }

            if isBlank(grade_value) {
                result.append(.gradeValue)
            }

            if isBlank(grade_date) {
                result.append(.gradeDate)
            }
        } else if type == "create_homework" {
            if class_id == nil {
                result.append(.class)
            }

            if subject_id == nil {
                result.append(.subject)
            }

            if isBlank(homework_description) {
                result.append(.homeworkDescription)
            }

            if isBlank(due_date) {
                result.append(.dueDate)
            }
        } else {
            result.append(.unsupported)
        }

        return result
    }

    private func isBlank(_ value: String?) -> Bool {
        guard let value else {
            return true
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func formatDate(_ value: String?) -> String {
        AppDateFormatter.date(value)
    }
}

enum AITeacherCommandMissingField: String, CaseIterable, Identifiable {
    case student
    case `class`
    case subject
    case gradeValue
    case gradeDate
    case homeworkDescription
    case dueDate
    case unsupported

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .student:
            return "ученик"
        case .class:
            return "класс"
        case .subject:
            return "предмет"
        case .gradeValue:
            return "оценка"
        case .gradeDate:
            return "дата оценки"
        case .homeworkDescription:
            return "описание домашнего задания"
        case .dueDate:
            return "срок домашнего задания"
        case .unsupported:
            return "тип команды"
        }
    }

    var question: String {
        switch self {
        case .student:
            return "Уточните ученика"
        case .class:
            return "Уточните класс"
        case .subject:
            return "Уточните предмет"
        case .gradeValue:
            return "Уточните оценку"
        case .gradeDate:
            return "Уточните дату оценки"
        case .homeworkDescription:
            return "Уточните домашнее задание"
        case .dueDate:
            return "Уточните срок домашнего задания"
        case .unsupported:
            return "Уточните команду"
        }
    }

    var hint: String {
        switch self {
        case .student:
            return "Например: Иванов Иван или Иванов Иван из 5А"
        case .class:
            return "Например: 5А"
        case .subject:
            return "Например: математика"
        case .gradeValue:
            return "Например: 5"
        case .gradeDate:
            return "Например: сегодня, вчера или 10 сентября"
        case .homeworkDescription:
            return "Например: решить номера 10, 11, 12"
        case .dueDate:
            return "Например: на завтра или до понедельника"
        case .unsupported:
            return "Можно поставить оценку или создать домашнее задание"
        }
    }
}

struct AITeacherCommandOptionDTO: Codable, Equatable, Identifiable {
    let id: Int
    let name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleOptionCodingKeys.self)
        id = container.decodeFlexibleIntIfPresent(forKey: .id) ?? 0
        name = container.decodeFlexibleStringIfPresent(forKey: .name)
            ?? container.decodeFlexibleStringIfPresent(forKey: .title)
            ?? container.decodeFlexibleStringIfPresent(forKey: .label)
            ?? ""
    }
}

struct AITeacherCommandStringOptionDTO: Codable, Equatable, Identifiable {
    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleOptionCodingKeys.self)
        id = container.decodeFlexibleStringIfPresent(forKey: .id)
            ?? container.decodeFlexibleStringIfPresent(forKey: .value)
            ?? container.decodeFlexibleStringIfPresent(forKey: .code)
            ?? ""
        name = container.decodeFlexibleStringIfPresent(forKey: .name)
            ?? container.decodeFlexibleStringIfPresent(forKey: .title)
            ?? container.decodeFlexibleStringIfPresent(forKey: .label)
            ?? id
    }
}

private enum FlexibleOptionCodingKeys: String, CodingKey {
    case id
    case name
    case title
    case label
    case value
    case code
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }

        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }

        return nil
    }
}