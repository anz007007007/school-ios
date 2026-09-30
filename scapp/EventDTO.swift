import Foundation

struct EventsTimelineResponseDTO: Codable {
    let items: [EventTimelineDTO]
}

struct EventTimelineDTO: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let event_type: String
    let starts_at: String
    let description: String?
    let class_ids: [Int]?
    let student_ids: [Int]?
    let participants_count: Int
    let confirmed_count: Int
    let declined_count: Int
}

struct EventFiltersDTO: Codable, Hashable {
    let classes: [EventClassFilterDTO]
    let students: [EventStudentFilterDTO]
}

struct EventClassFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct EventStudentFilterDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_name: String
    let class_id: Int?
}

struct EventOverviewDTO: Codable, Hashable {
    let total: Int
    let upcoming: Int
    let past: Int
    let waiting_response: Int
}

struct EventFormData: Hashable {
    let title: String
    let eventType: String
    let startsAt: Date
    let description: String
    let classIDs: [Int]
    let studentIDs: [Int]
}

struct EventParticipantsListResponseDTO: Codable {
    let items: [EventParticipantDTO]
}

struct EventParticipantDTO: Codable, Identifiable, Hashable {
    let id: Int
    let event_id: Int
    let student_id: Int
    let participation_status: String
    let student_name: String
}

struct EventParticipantsFormData: Hashable {
    let studentIDs: [Int]
}