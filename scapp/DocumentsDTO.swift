import Foundation

// Схемы сервера: app/schemas/documents.py.

struct DocumentStudentsListResponseDTO: Codable {
    let items: [DocumentStudentDTO]
}

/// DocumentStudentResponse.
struct DocumentStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int?
    let class_id: Int?
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let birth_date: String?
    let gender: String?
    let class_name: String?
    let student_name: String?

    /// Полное ФИО для профиля документов: «Фамилия Имя Отчество».
    var fullName: String {
        [last_name, first_name, middle_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var displayName: String {
        if let name = student_name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        let full = fullName
        return full.isEmpty ? "Ученик" : full
    }

    var displayTitle: String {
        if let className = class_name?.trimmingCharacters(in: .whitespacesAndNewlines), !className.isEmpty {
            return "\(displayName) · \(className)"
        }

        return displayName
    }
}

struct DocumentProfilesListResponseDTO: Codable {
    let items: [DocumentProfileDTO]
}

/// DocumentProfileResponse.
struct DocumentProfileDTO: Codable, Identifiable, Hashable {
    let id: Int
    let parent_user_id: Int?
    let student_id: Int

    let parent_full_name: String?
    let parent_birth_date: String?
    let parent_passport_series: String?
    let parent_passport_number: String?
    let parent_passport_issued_by: String?
    let parent_passport_issued_at: String?
    let parent_passport_department_code: String?
    let parent_registration_address: String?
    let parent_living_address: String?
    let parent_phone: String?
    let parent_email: String?

    let student_full_name: String?
    let student_birth_date: String?
    let student_gender: String?
    let student_birth_certificate: String?
    let student_registration_address: String?
    let student_living_address: String?

    let organization_name: String?
    let organization_director: String?
    let organization_address: String?
    let organization_inn: String?
    let organization_ogrn: String?

    let created_at: String?
    let updated_at: String?

    let db_student_name: String?
    let db_parent_name: String?
    let class_name: String?

    var displayStudentName: String {
        DocumentText.firstNonEmpty(student_full_name, db_student_name) ?? "Ученик"
    }

    var displayParentName: String {
        DocumentText.firstNonEmpty(parent_full_name, db_parent_name) ?? ""
    }

    /// Заполнены данные, которые сервер подставляет в договор и согласие.
    var isCompleted: Bool {
        DocumentText.firstNonEmpty(parent_full_name) != nil
        && DocumentText.firstNonEmpty(student_full_name) != nil
        && DocumentText.firstNonEmpty(student_birth_date) != nil
        && DocumentText.firstNonEmpty(parent_passport_series) != nil
        && DocumentText.firstNonEmpty(parent_passport_number) != nil
        && DocumentText.firstNonEmpty(parent_passport_issued_by) != nil
        && DocumentText.firstNonEmpty(parent_registration_address) != nil
    }
}

/// Поля формы профиля (DocumentProfileSaveRequest). Даты вводятся как ДД.ММ.ГГГГ.
struct DocumentProfileFormData: Hashable {
    var studentID: Int = 0
    var parentUserID: Int?

    var studentFullName = ""
    var studentBirthDate = ""
    var studentGender = "unknown"
    var studentBirthCertificate = ""
    var studentRegistrationAddress = ""
    var studentLivingAddress = ""

    var parentFullName = ""
    var parentBirthDate = ""
    var parentPassportSeries = ""
    var parentPassportNumber = ""
    var parentPassportIssuedBy = ""
    var parentPassportIssuedAt = ""
    var parentPassportDepartmentCode = ""
    var parentRegistrationAddress = ""
    var parentLivingAddress = ""
    var parentPhone = ""
    var parentEmail = ""

    var organizationName = ""
    var organizationDirector = ""
    var organizationAddress = ""
    var organizationInn = ""
    var organizationOgrn = ""

    init() {}

    init(profile: DocumentProfileDTO) {
        studentID = profile.student_id
        parentUserID = profile.parent_user_id

        studentFullName = profile.student_full_name ?? ""
        studentBirthDate = DocumentDate.display(profile.student_birth_date)
        studentGender = DocumentGender.normalized(profile.student_gender)
        studentBirthCertificate = profile.student_birth_certificate ?? ""
        studentRegistrationAddress = profile.student_registration_address ?? ""
        studentLivingAddress = profile.student_living_address ?? ""

        parentFullName = profile.parent_full_name ?? ""
        parentBirthDate = DocumentDate.display(profile.parent_birth_date)
        parentPassportSeries = profile.parent_passport_series ?? ""
        parentPassportNumber = profile.parent_passport_number ?? ""
        parentPassportIssuedBy = profile.parent_passport_issued_by ?? ""
        parentPassportIssuedAt = DocumentDate.display(profile.parent_passport_issued_at)
        parentPassportDepartmentCode = profile.parent_passport_department_code ?? ""
        parentRegistrationAddress = profile.parent_registration_address ?? ""
        parentLivingAddress = profile.parent_living_address ?? ""
        parentPhone = profile.parent_phone ?? ""
        parentEmail = profile.parent_email ?? ""

        organizationName = profile.organization_name ?? ""
        organizationDirector = profile.organization_director ?? ""
        organizationAddress = profile.organization_address ?? ""
        organizationInn = profile.organization_inn ?? ""
        organizationOgrn = profile.organization_ogrn ?? ""
    }

    init(student: DocumentStudentDTO?) {
        studentID = student?.id ?? 0
        studentFullName = student?.fullName ?? ""
        studentBirthDate = DocumentDate.display(student?.birth_date)
        studentGender = DocumentGender.normalized(student?.gender)
    }

    /// Подставляет родителя ученика, если он один. Иначе сбрасывает выбор:
    /// родитель прежнего ученика к новому не подходит.
    mutating func applyParent(for studentID: Int, parents: [AdminParentDTO]) {
        let studentParents = parents.filter { parent in
            parent.students.contains { $0.id == studentID }
        }

        guard studentParents.count == 1, let parent = studentParents.first else {
            parentUserID = nil
            return
        }

        parentUserID = parent.user_id

        if parentFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parentFullName = parent.full_name
        }
    }

    /// Текст ошибки для пользователя или nil, если форму можно отправлять.
    func validationError() -> String? {
        if studentID == 0 {
            return "Выберите ученика"
        }

        if studentFullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Введите ФИО ученика (не короче 2 символов)"
        }

        if parentFullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Введите ФИО родителя (не короче 2 символов)"
        }

        let dates = [
            ("Дата рождения ученика", studentBirthDate),
            ("Дата рождения родителя", parentBirthDate),
            ("Дата выдачи паспорта", parentPassportIssuedAt)
        ]

        for (title, value) in dates {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if !clean.isEmpty && DocumentDate.iso(clean) == nil {
                return "\(title): укажите дату в формате ДД.ММ.ГГГГ"
            }
        }

        return nil
    }

    /// Тело DocumentProfileSaveRequest. Сервер сохраняет профиль целиком
    /// (INSERT … ON DUPLICATE KEY UPDATE), поэтому отправляются все поля.
    var requestBody: [String: Any] {
        var body: [String: Any] = [
            "student_id": studentID,
            "parent_full_name": parentFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "parent_birth_date": DocumentDate.iso(parentBirthDate) as Any,
            "parent_passport_series": DocumentText.clean(parentPassportSeries) as Any,
            "parent_passport_number": DocumentText.clean(parentPassportNumber) as Any,
            "parent_passport_issued_by": DocumentText.clean(parentPassportIssuedBy) as Any,
            "parent_passport_issued_at": DocumentDate.iso(parentPassportIssuedAt) as Any,
            "parent_passport_department_code": DocumentText.clean(parentPassportDepartmentCode) as Any,
            "parent_registration_address": DocumentText.clean(parentRegistrationAddress) as Any,
            "parent_living_address": DocumentText.clean(parentLivingAddress) as Any,
            "parent_phone": DocumentText.clean(parentPhone) as Any,
            "parent_email": DocumentText.clean(parentEmail) as Any,
            "student_full_name": studentFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "student_birth_date": DocumentDate.iso(studentBirthDate) as Any,
            "student_gender": DocumentGender.normalized(studentGender),
            "student_birth_certificate": DocumentText.clean(studentBirthCertificate) as Any,
            "student_registration_address": DocumentText.clean(studentRegistrationAddress) as Any,
            "student_living_address": DocumentText.clean(studentLivingAddress) as Any,
            "organization_director": DocumentText.clean(organizationDirector) as Any,
            "organization_address": DocumentText.clean(organizationAddress) as Any,
            "organization_inn": DocumentText.clean(organizationInn) as Any,
            "organization_ogrn": DocumentText.clean(organizationOgrn) as Any
        ]

        // Без parent_user_id сервер записывает родителем того, кто сохраняет профиль.
        if let parentUserID {
            body["parent_user_id"] = parentUserID
        }

        // organization_name на сервере не может быть null: если поле пустое,
        // не отправляем его, и сервер подставит название по умолчанию.
        if let organizationName = DocumentText.clean(organizationName) {
            body["organization_name"] = organizationName
        }

        return body
    }
}

struct DocumentProfileSaveResponseDTO: Codable {
    let status: String?
    let profile_id: Int?
}

/// GenerateDocumentRequest: document_type = contract | personal_data_consent.
struct DocumentGenerateFormData: Hashable {
    let profileID: Int
    let documentType: String
}

struct GeneratedDocumentCreateResponseDTO: Codable {
    let status: String?
    let document_id: Int?
}

struct GeneratedDocumentsListResponseDTO: Codable {
    let items: [GeneratedDocumentDTO]
}

/// GeneratedDocumentResponse.
struct GeneratedDocumentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let profile_id: Int
    let document_type: String
    let title: String
    let generated_at: String?
    let student_id: Int?
    let parent_user_id: Int?
    let student_full_name: String?
    let parent_full_name: String?
}

struct PublicDocumentsListResponseDTO: Codable {
    let items: [PublicDocumentDTO]
}

/// PublicDocumentResponse.
struct PublicDocumentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_id: Int?
    let title: String
    let description: String?
    let document_type: String?
    let file_url: String?
    let target_role_code: String?
    let class_id: Int?
    let is_public: Bool?
    let created_at: String?
    let updated_at: String?
    let class_name: String?
    let author_name: String?

    var isPublic: Bool {
        is_public ?? false
    }
}

struct PublicDocumentFormData: Hashable {
    let title: String
    let description: String
    let fileURL: String
    let isPublic: Bool

    /// PublicDocumentCreateRequest.
    var createBody: [String: Any] {
        var body: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "is_public": isPublic
        ]

        if let description = DocumentText.clean(description) {
            body["description"] = description
        }

        if let fileURL = DocumentText.clean(fileURL) {
            body["file_url"] = fileURL
        }

        return body
    }

    /// PublicDocumentUpdateRequest: null — «не менять», поэтому очистка поля
    /// передаётся флагами clear_description / clear_file_url.
    func updateBody(original: PublicDocumentDTO?) -> [String: Any] {
        var body: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "is_public": isPublic
        ]

        if let description = DocumentText.clean(description) {
            body["description"] = description
        } else if DocumentText.firstNonEmpty(original?.description) != nil {
            body["clear_description"] = true
        }

        if let fileURL = DocumentText.clean(fileURL) {
            body["file_url"] = fileURL
        } else if DocumentText.firstNonEmpty(original?.file_url) != nil {
            body["clear_file_url"] = true
        }

        return body
    }
}

struct DocumentStatusResponseDTO: Codable {
    let status: String?
}

struct PublicDocumentIDStatusResponseDTO: Codable {
    let status: String?
    let document_id: Int?
}

// MARK: - Справочники и форматирование

enum DocumentTypes {
    /// Сервер генерирует только эти типы (GenerateDocumentRequest).
    static let generationTypes: [(code: String, title: String)] = [
        ("contract", "Договор"),
        ("personal_data_consent", "Согласие на обработку персональных данных")
    ]

    /// Русское название типа; технические коды не показываются как есть.
    static func title(_ code: String?) -> String {
        switch code {
        case "contract":
            return "Договор"
        case "personal_data_consent":
            return "Согласие на обработку ПД"
        default:
            return "Документ"
        }
    }

    static func roleTitle(_ code: String?) -> String? {
        switch code {
        case nil, "":
            return nil
        case "admin":
            return "Администраторы"
        case "manager":
            return "Менеджеры"
        case "teacher":
            return "Учителя"
        case "parent":
            return "Родители"
        case "student":
            return "Ученики"
        case "cook":
            return "Повара"
        default:
            return "Другая роль"
        }
    }
}

enum DocumentGender {
    static let options: [(code: String, title: String)] = [
        ("unknown", "Не указан"),
        ("male", "Мужской"),
        ("female", "Женский")
    ]

    static func normalized(_ value: String?) -> String {
        guard let value, options.contains(where: { $0.code == value }) else {
            return "unknown"
        }

        return value
    }

    static func title(_ value: String?) -> String {
        options.first { $0.code == value }?.title ?? "Не указан"
    }
}

enum DocumentDate {
    /// «05.03.2015» или «2015-03-05» → «2015-03-05»; пустая строка и неверная дата → nil.
    static func iso(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            return nil
        }

        let year: Int
        let month: Int
        let day: Int

        let isoParts = clean.prefix(10).split(separator: "-")
        let dotParts = clean.split(separator: ".")

        if isoParts.count == 3, isoParts[0].count == 4,
           let y = Int(isoParts[0]), let m = Int(isoParts[1]), let d = Int(isoParts[2]) {
            year = y
            month = m
            day = d
        } else if dotParts.count == 3, dotParts[2].count == 4,
                  (1...2).contains(dotParts[0].count), (1...2).contains(dotParts[1].count),
                  let d = Int(dotParts[0]), let m = Int(dotParts[1]), let y = Int(dotParts[2]) {
            year = y
            month = m
            day = d
        } else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard components.isValidDate(in: calendar) else {
            return nil
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// «2015-03-05» (или с временем) → «05.03.2015».
    static func display(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return ""
        }

        let parts = value.prefix(10).split(separator: "-")

        guard parts.count == 3, parts[0].count == 4 else {
            return value
        }

        return "\(parts[2]).\(parts[1]).\(parts[0])"
    }
}

enum DocumentText {
    static func clean(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty {
                return clean
            }
        }

        return nil
    }
}
