import Foundation

struct EventsTimelineResponseDTO: Codable {
    let items: [EventTimelineDTO]
}

struct EventTimelineDTO: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let event_type: String
    let starts_at: String
    let ends_at: String?
    let description: String?
    /// Сервер хранит один класс: для события на несколько классов здесь null.
    let class_id: Int?
    let student_id: Int?
    let class_name: String?
    let student_name: String?
    let participants_count: Int
    let confirmed_count: Int
    let declined_count: Int
    let maybe_count: Int?
    let participant_classes_names: String?
    /// Подразделения события ([] — вся школа); старые серверы поле не присылают.
    var division_ids: [Int]? = nil

    /// Классы для формы: один класс приходит в class_id, для нескольких — только названия классов участников.
    func formClassIDs(classes: [EventClassFilterDTO]) -> [Int] {
        if let class_id {
            return [class_id]
        }

        if student_id != nil {
            return []
        }

        let names = Set(
            (participant_classes_names ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        return classes
            .filter { names.contains($0.name.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .map { $0.id }
    }

    /// Ученики, добавленные вручную: основной ученик и участники не из классов события.
    /// Участников из выбранных классов сервер ведёт сам.
    func formStudentIDs(
        participants: [EventParticipantDTO]?,
        classes: [EventClassFilterDTO]
    ) -> [Int] {
        let eventClassIDs = Set(formClassIDs(classes: classes))
        var result: [Int] = []

        if let student_id {
            result.append(student_id)
        }

        for participant in participants ?? [] {
            let fromEventClass = participant.class_id.map { eventClassIDs.contains($0) } ?? false

            if !fromEventClass && !result.contains(participant.student_id) {
                result.append(participant.student_id)
            }
        }

        return result
    }
}

struct EventIdStatusResponseDTO: Codable {
    let status: String?
    let event_id: Int?
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
    /// «Для кого»: nil — не менять, [] — вся школа.
    var divisionIDs: [Int]? = nil
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
    let class_id: Int?
    let class_name: String?
}

struct EventParticipantsFormData: Hashable {
    let studentIDs: [Int]
}