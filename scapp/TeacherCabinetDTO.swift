import Foundation

struct TeacherClassDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case class_name
        case title
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .class_name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? "Класс \(id)"
    }
}

struct TeacherSubjectDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subject_name
        case title
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .subject_name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? "Предмет \(id)"
    }
}

struct TeacherGradeTypeDTO: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let description: String?
    let weight: String?
    let sort_order: Int?

    var id: String {
        code
    }

    static let fallback = TeacherGradeTypeDTO(
        code: "regular",
        name: "Текущая",
        description: "Обычная текущая оценка",
        weight: "1.00",
        sort_order: 10
    )

    enum CodingKeys: String, CodingKey {
        case code
        case name
        case title
        case description
        case weight
        case sort_order
    }

    init(
        code: String,
        name: String,
        description: String?,
        weight: String?,
        sort_order: Int?
    ) {
        self.code = code
        self.name = name
        self.description = description
        self.weight = weight
        self.sort_order = sort_order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? code
        description = try container.decodeIfPresent(String.self, forKey: .description)

        if let stringWeight = try container.decodeIfPresent(String.self, forKey: .weight) {
            weight = stringWeight
        } else if let doubleWeight = try container.decodeIfPresent(Double.self, forKey: .weight) {
            weight = String(format: "%.2f", doubleWeight)
        } else if let intWeight = try container.decodeIfPresent(Int.self, forKey: .weight) {
            weight = "\(intWeight).00"
        } else {
            weight = nil
        }

        sort_order = try container.decodeFlexibleInt(forKey: .sort_order)
    }
}

struct TeacherStudentDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let full_name: String
    let class_id: Int?
    let class_name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case student_id
        case user_id
        case full_name
        case student_name
        case name
        case first_name
        case last_name
        case middle_name
        case class_id
        case class_name
    }

    init(id: Int, full_name: String, class_id: Int?, class_name: String?) {
        self.id = id
        self.full_name = full_name
        self.class_id = class_id
        self.class_name = class_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id)
            ?? container.decodeFlexibleInt(forKey: .student_id)
            ?? container.decodeFlexibleInt(forKey: .user_id)
            ?? 0

        let firstName = try container.decodeIfPresent(String.self, forKey: .first_name) ?? ""
        let lastName = try container.decodeIfPresent(String.self, forKey: .last_name) ?? ""
        let middleName = try container.decodeIfPresent(String.self, forKey: .middle_name) ?? ""

        let composedName = [lastName, firstName, middleName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
            ?? container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? (composedName.isEmpty ? "Ученик \(id)" : composedName)

        class_id = try container.decodeFlexibleInt(forKey: .class_id)
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name)
    }
}

struct TeacherGradeDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let student_name: String
    let subject_id: Int
    let subject_name: String
    let class_id: Int
    let class_name: String
    let grade_value: String
    let grade_type: String?
    let grade_date: String
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case student_id
        case student_name
        case full_name
        case first_name
        case last_name
        case middle_name
        case subject_id
        case subject_name
        case class_id
        case class_name
        case grade_value
        case value
        case grade
        case grade_type
        case type
        case grade_date
        case date
        case comment
    }

    init(
        id: Int,
        student_id: Int,
        student_name: String,
        subject_id: Int,
        subject_name: String,
        class_id: Int,
        class_name: String,
        grade_value: String,
        grade_type: String?,
        grade_date: String,
        comment: String?
    ) {
        self.id = id
        self.student_id = student_id
        self.student_name = student_name
        self.subject_id = subject_id
        self.subject_name = subject_name
        self.class_id = class_id
        self.class_name = class_name
        self.grade_value = grade_value
        self.grade_type = grade_type
        self.grade_date = grade_date
        self.comment = comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        student_id = try container.decodeFlexibleInt(forKey: .student_id) ?? 0

        let firstName = try container.decodeIfPresent(String.self, forKey: .first_name) ?? ""
        let lastName = try container.decodeIfPresent(String.self, forKey: .last_name) ?? ""
        let middleName = try container.decodeIfPresent(String.self, forKey: .middle_name) ?? ""

        let composedName = [lastName, firstName, middleName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        student_name = try container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .full_name)
            ?? (composedName.isEmpty ? "Ученик \(student_id)" : composedName)

        subject_id = try container.decodeFlexibleInt(forKey: .subject_id) ?? 0
        subject_name = try container.decodeIfPresent(String.self, forKey: .subject_name) ?? "Предмет"

        class_id = try container.decodeFlexibleInt(forKey: .class_id) ?? 0
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name) ?? "Класс"

        grade_value = try container.decodeIfPresent(String.self, forKey: .grade_value)
            ?? container.decodeIfPresent(String.self, forKey: .value)
            ?? container.decodeIfPresent(String.self, forKey: .grade)
            ?? ""

        grade_type = try container.decodeIfPresent(String.self, forKey: .grade_type)
            ?? container.decodeIfPresent(String.self, forKey: .type)

        grade_date = try container.decodeIfPresent(String.self, forKey: .grade_date)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? ""

        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }
}

struct TeacherHomeworkDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let class_id: Int
    let class_name: String
    let subject_id: Int
    let subject_name: String
    let teacher_id: Int?
    let teacher_name: String?
    let title: String
    let description: String
    let due_date: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case class_id
        case class_name
        case subject_id
        case subject_name
        case teacher_id
        case teacher_name
        case title
        case description
        case due_date
        case created_at
    }

    init(
        id: Int,
        class_id: Int,
        class_name: String,
        subject_id: Int,
        subject_name: String,
        teacher_id: Int?,
        teacher_name: String?,
        title: String,
        description: String,
        due_date: String,
        created_at: String?
    ) {
        self.id = id
        self.class_id = class_id
        self.class_name = class_name
        self.subject_id = subject_id
        self.subject_name = subject_name
        self.teacher_id = teacher_id
        self.teacher_name = teacher_name
        self.title = title
        self.description = description
        self.due_date = due_date
        self.created_at = created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        class_id = try container.decodeFlexibleInt(forKey: .class_id) ?? 0
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name) ?? "Класс"
        subject_id = try container.decodeFlexibleInt(forKey: .subject_id) ?? 0
        subject_name = try container.decodeIfPresent(String.self, forKey: .subject_name) ?? "Предмет"
        teacher_id = try container.decodeFlexibleInt(forKey: .teacher_id)
        teacher_name = try container.decodeIfPresent(String.self, forKey: .teacher_name)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        due_date = try container.decodeIfPresent(String.self, forKey: .due_date) ?? ""
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
    }
}

struct TeacherAttendanceDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let lesson_id: Int?
    let student_id: Int
    let student_name: String
    let class_id: Int
    let class_name: String
    let attendance_date: String
    let status: String
    let comment: String?

    var date: String {
        attendance_date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case lesson_id
        case student_id
        case student_name
        case full_name
        case first_name
        case last_name
        case middle_name
        case class_id
        case class_name
        case attendance_date
        case date
        case status
        case comment
    }

    init(
        id: Int,
        lesson_id: Int?,
        student_id: Int,
        student_name: String,
        class_id: Int,
        class_name: String,
        attendance_date: String,
        status: String,
        comment: String?
    ) {
        self.id = id
        self.lesson_id = lesson_id
        self.student_id = student_id
        self.student_name = student_name
        self.class_id = class_id
        self.class_name = class_name
        self.attendance_date = attendance_date
        self.status = status
        self.comment = comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        lesson_id = try container.decodeFlexibleInt(forKey: .lesson_id)
        student_id = try container.decodeFlexibleInt(forKey: .student_id) ?? 0

        let firstName = try container.decodeIfPresent(String.self, forKey: .first_name) ?? ""
        let lastName = try container.decodeIfPresent(String.self, forKey: .last_name) ?? ""
        let middleName = try container.decodeIfPresent(String.self, forKey: .middle_name) ?? ""

        let composedName = [lastName, firstName, middleName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        student_name = try container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .full_name)
            ?? (composedName.isEmpty ? "Ученик \(student_id)" : composedName)

        class_id = try container.decodeFlexibleInt(forKey: .class_id) ?? 0
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name) ?? "Класс"
        attendance_date = try container.decodeIfPresent(String.self, forKey: .attendance_date)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "present"
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }
}

struct TeacherTermDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let academic_year: String?
    let term_type: String?
    let term_number: Int?
    let starts_at: String?
    let ends_at: String?
    let is_active: Bool?

    var starts_on: String? {
        starts_at
    }

    var ends_on: String? {
        ends_at
    }

    var dateRangeTitle: String {
        "\(starts_at ?? "дата начала не указана") — \(ends_at ?? "дата окончания не указана")"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case academic_year
        case term_type
        case term_number
        case starts_at
        case ends_at
        case starts_on
        case ends_on
        case start_date
        case end_date
        case is_active
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Период \(id)"
        academic_year = try container.decodeIfPresent(String.self, forKey: .academic_year)
        term_type = try container.decodeIfPresent(String.self, forKey: .term_type)
        term_number = try container.decodeFlexibleInt(forKey: .term_number)

        starts_at = try container.decodeIfPresent(String.self, forKey: .starts_at)
            ?? container.decodeIfPresent(String.self, forKey: .starts_on)
            ?? container.decodeIfPresent(String.self, forKey: .start_date)

        ends_at = try container.decodeIfPresent(String.self, forKey: .ends_at)
            ?? container.decodeIfPresent(String.self, forKey: .ends_on)
            ?? container.decodeIfPresent(String.self, forKey: .end_date)

        is_active = try container.decodeIfPresent(Bool.self, forKey: .is_active)
    }
}

struct TeacherScheduleLessonDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let class_id: Int?
    let class_name: String?
    let subject_id: Int?
    let subject_name: String?
    let weekday: Int?
    let lesson_number: Int?
    let starts_at: String?
    let ends_at: String?
    let room: String?

    var displayTitle: String {
        let subject = subject_name ?? "Урок"
        let number = lesson_number.map { "\($0) урок" } ?? "Урок"
        let time: String

        if let starts_at, let ends_at, !starts_at.isEmpty, !ends_at.isEmpty {
            time = "\(starts_at)–\(ends_at)"
        } else if let starts_at, !starts_at.isEmpty {
            time = starts_at
        } else {
            time = ""
        }

        if time.isEmpty {
            return "\(number) · \(subject)"
        }

        return "\(number) · \(time) · \(subject)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case class_id
        case class_name
        case subject_id
        case subject_name
        case weekday
        case lesson_number
        case starts_at
        case ends_at
        case room
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        class_id = try container.decodeFlexibleInt(forKey: .class_id)
        class_name = try container.decodeIfPresent(String.self, forKey: .class_name)
        subject_id = try container.decodeFlexibleInt(forKey: .subject_id)
        subject_name = try container.decodeIfPresent(String.self, forKey: .subject_name)
        weekday = try container.decodeFlexibleInt(forKey: .weekday)
        lesson_number = try container.decodeFlexibleInt(forKey: .lesson_number)
        starts_at = try container.decodeIfPresent(String.self, forKey: .starts_at)
        ends_at = try container.decodeIfPresent(String.self, forKey: .ends_at)
        room = try container.decodeIfPresent(String.self, forKey: .room)
    }
}

struct TeacherAccessResponseDTO: Decodable, Hashable {
    let can_view: Bool?
    let can_manage: Bool?

    let can_view_classes: Bool?
    let can_view_subjects: Bool?
    let can_view_students: Bool?
    let can_manage_grades: Bool?
    let can_manage_homework: Bool?
    let can_manage_attendance: Bool?
    let can_manage_final_grades: Bool?

    var resolvedCanView: Bool {
        can_view
            ?? can_view_classes
            ?? can_view_subjects
            ?? can_view_students
            ?? true
    }

    var resolvedCanManage: Bool {
        can_manage
            ?? can_manage_grades
            ?? can_manage_homework
            ?? can_manage_attendance
            ?? can_manage_final_grades
            ?? false
    }

    var resolvedCanManageGrades: Bool {
        can_manage_grades ?? can_manage ?? false
    }

    var resolvedCanManageHomework: Bool {
        can_manage_homework ?? can_manage ?? false
    }

    var resolvedCanManageAttendance: Bool {
        can_manage_attendance ?? can_manage ?? false
    }

    var resolvedCanManageFinalGrades: Bool {
            can_manage_final_grades
            ?? can_manage_grades
            ?? can_manage
            ?? false
        }
}

// MARK: - Gradebook DTOs

struct TeacherGradebookAttendanceDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let attendance_date: String
    let status: String
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case student_id
        case attendance_date
        case date
        case status
        case comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        student_id = try container.decodeFlexibleInt(forKey: .student_id) ?? 0
        attendance_date = try container.decodeIfPresent(String.self, forKey: .attendance_date)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }
}

struct TeacherFinalGradeDTO: Decodable, Hashable {
    let student_id: Int?
    let calculated_grade: String?
    let manual_grade: String?
    let final_grade: String?
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case student_id
        case calculated_grade
        case manual_grade
        case final_grade
        case comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        student_id = try container.decodeFlexibleInt(forKey: .student_id)
        calculated_grade = try Self.decodeFlexibleString(container, key: .calculated_grade)
        manual_grade = try Self.decodeFlexibleString(container, key: .manual_grade)
        final_grade = try Self.decodeFlexibleString(container, key: .final_grade)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }

    var displayGrade: String {
        final_grade?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? final_grade ?? "—"
            : "—"
    }

    var manualGradeForForm: String {
        manual_grade?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? manual_grade ?? ""
            : ""
    }

    private static func decodeFlexibleString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> String? {
        if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try container.decodeIfPresent(Int.self, forKey: key) {
            return "\(intValue)"
        }

        if let doubleValue = try container.decodeIfPresent(Double.self, forKey: key) {
            let rounded = doubleValue.rounded()

            if abs(doubleValue - rounded) < 0.0001 {
                return "\(Int(rounded))"
            }

            return String(format: "%.2f", doubleValue)
        }

        return nil
    }
}

struct TeacherFinalGradeSaveResponseDTO: Decodable, Hashable {
    let status: String?
    let calculated_grade: Double?
    let final_grade: String?
}

struct TeacherGradebookStudentDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let student_id: Int
    let student_name: String
    let grades: [TeacherGradeDTO]
    let attendance: [TeacherGradebookAttendanceDTO]
    let term_final: TeacherFinalGradeDTO?
    let year_final: TeacherFinalGradeDTO?
    let calculated_average: Double?
    let calculated_recommended_grade: String?

    var finalGradeDisplay: String {
        term_final?.displayGrade ?? "—"
    }

    var yearFinalGradeDisplay: String {
        year_final?.displayGrade ?? "—"
    }

    var recommendedGradeDisplay: String {
        calculated_recommended_grade?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? calculated_recommended_grade ?? "—"
            : "—"
    }

    var averageDisplay: String {
        guard let calculated_average else {
            return "—"
        }

        return String(format: "%.2f", calculated_average)
    }

    var gradesSummary: String {
        let values = grades
            .map { $0.grade_value }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return values.isEmpty ? "Оценок нет" : values.joined(separator: ", ")
    }

    var attendanceSummary: String {
        guard !attendance.isEmpty else {
            return "Посещаемость не заполнена"
        }

        let absentCount = attendance.filter { $0.status == "absent" }.count
        let lateCount = attendance.filter { $0.status == "late" }.count
        let sickCount = attendance.filter { $0.status == "sick" }.count

        var parts: [String] = ["записей: \(attendance.count)"]

        if absentCount > 0 {
            parts.append("пропусков: \(absentCount)")
        }

        if lateCount > 0 {
            parts.append("опозданий: \(lateCount)")
        }

        if sickCount > 0 {
            parts.append("болезнь: \(sickCount)")
        }

        return parts.joined(separator: " · ")
    }

    private struct NestedStudentDTO: Decodable, Hashable {
        let id: Int
        let first_name: String?
        let last_name: String?
        let middle_name: String?

        enum CodingKeys: String, CodingKey {
            case id
            case first_name
            case last_name
            case middle_name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decodeFlexibleInt(forKey: .id) ?? 0
            first_name = try container.decodeIfPresent(String.self, forKey: .first_name)
            last_name = try container.decodeIfPresent(String.self, forKey: .last_name)
            middle_name = try container.decodeIfPresent(String.self, forKey: .middle_name)
        }

        var fullName: String {
            let parts = [
                last_name,
                first_name,
                middle_name
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

            return parts.isEmpty ? "Ученик \(id)" : parts.joined(separator: " ")
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case student_id
        case student_name
        case full_name
        case first_name
        case last_name
        case middle_name
        case name
        case student
        case grades
        case attendance
        case term_final
        case year_final
        case calculated_average
        case calculated_recommended_grade
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let nestedStudent = try container.decodeIfPresent(NestedStudentDTO.self, forKey: .student)
        let decodedStudentID = try container.decodeFlexibleInt(forKey: .student_id)
        let decodedID = try container.decodeFlexibleInt(forKey: .id)

        student_id = decodedStudentID
            ?? decodedID
            ?? nestedStudent?.id
            ?? 0

        id = decodedID ?? student_id

        let firstName = try container.decodeIfPresent(String.self, forKey: .first_name) ?? ""
        let lastName = try container.decodeIfPresent(String.self, forKey: .last_name) ?? ""
        let middleName = try container.decodeIfPresent(String.self, forKey: .middle_name) ?? ""

        let composedName = [lastName, firstName, middleName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        student_name = try container.decodeIfPresent(String.self, forKey: .student_name)
            ?? container.decodeIfPresent(String.self, forKey: .full_name)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? nestedStudent?.fullName
            ?? (composedName.isEmpty ? "Ученик \(student_id)" : composedName)

        grades = try container.decodeIfPresent([TeacherGradeDTO].self, forKey: .grades) ?? []
        attendance = try container.decodeIfPresent([TeacherGradebookAttendanceDTO].self, forKey: .attendance) ?? []
        term_final = try container.decodeIfPresent(TeacherFinalGradeDTO.self, forKey: .term_final)
        year_final = try container.decodeIfPresent(TeacherFinalGradeDTO.self, forKey: .year_final)
        calculated_average = try container.decodeFlexibleDouble(forKey: .calculated_average)
        calculated_recommended_grade = try container.decodeIfPresent(String.self, forKey: .calculated_recommended_grade)
    }
}

// MARK: - Response DTOs

struct TeacherClassesResponseDTO: Decodable {
    let items: [TeacherClassDTO]
}

struct TeacherSubjectsResponseDTO: Decodable {
    let items: [TeacherSubjectDTO]
}

struct TeacherGradeTypesResponseDTO: Decodable {
    let items: [TeacherGradeTypeDTO]
}

struct TeacherStudentsResponseDTO: Decodable {
    let items: [TeacherStudentDTO]
}

struct TeacherGradesResponseDTO: Decodable {
    let items: [TeacherGradeDTO]
}

struct TeacherHomeworkResponseDTO: Decodable {
    let items: [TeacherHomeworkDTO]
}

struct TeacherAttendanceResponseDTO: Decodable {
    let items: [TeacherAttendanceDTO]
}

struct TeacherTermsResponseDTO: Decodable {
    let items: [TeacherTermDTO]
}

struct TeacherScheduleResponseDTO: Decodable {
    let items: [TeacherScheduleLessonDTO]
}

struct TeacherGradebookResponseDTO: Decodable {
    let items: [TeacherGradebookStudentDTO]
}

// MARK: - Extensions

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

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }

        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue.replacingOccurrences(of: ",", with: "."))
        }

        return nil
    }
}

extension JSONDecoder {
    static var teacherCabinetDecoder: JSONDecoder {
        JSONDecoder()
    }
}