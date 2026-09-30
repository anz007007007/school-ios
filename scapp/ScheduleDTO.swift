import Foundation

struct ScheduleStudentsResponseDTO: Codable {
    let students: [ScheduleStudentDTO]
}

struct ScheduleStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int?
    let class_id: Int?
    let student_name: String
    let class_name: String?
}

struct ScheduleListResponseDTO: Codable {
    let items: [ScheduleLessonDTO]
}

struct ScheduleLessonDTO: Codable, Identifiable, Hashable {
    let id: Int
    let class_id: Int
    let subject_id: Int
    let teacher_id: Int?
    let weekday: Int
    let lesson_number: Int
    let starts_at: String
    let ends_at: String
    let room: String?
    let note: String?
    let class_name: String
    let subject_name: String
    let teacher_name: String?
    let student_id: Int?
    let student_name: String?

    var rowID: String {
        [
            "\(id)",
            "\(student_id ?? 0)",
            "\(class_id)",
            "\(subject_id)",
            "\(weekday)",
            "\(lesson_number)",
            starts_at,
            ends_at,
            student_name ?? ""
        ]
        .joined(separator: "-")
    }
}