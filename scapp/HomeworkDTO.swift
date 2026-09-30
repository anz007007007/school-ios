import Foundation

struct HomeworkListResponseDTO: Codable {
    let items: [HomeworkDTO]
}

struct HomeworkDTO: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let due_date: String
    let class_id: Int
    let subject_id: Int
    let class_name: String
    let subject_name: String
    let teacher_name: String?
    let due_status: String?
    let days_left: Int?
    let student_id: Int?
    let is_completed: Bool?
    let completed_at: String?
    let completed_by_user_id: Int?
    let completion_status: String?

    var isCompleted: Bool {
        is_completed == true || completion_status == "completed"
    }
}

struct HomeworkOverviewDTO: Codable, Hashable {
    let today: Int
    let tomorrow: Int
    let week: Int
    let overdue: Int
    let total: Int
}

struct HomeworkFiltersDTO: Codable, Hashable {
    let students: [HomeworkStudentFilterDTO]
    let subjects: [HomeworkSubjectFilterDTO]
}

struct HomeworkStudentFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_name: String
}

struct HomeworkSubjectFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct HomeworkFormData {
    var classID: Int = 0
    var subjectID: Int = 0
    var title: String = ""
    var description: String = ""
    var dueDate: String = "2026-05-22"
}
