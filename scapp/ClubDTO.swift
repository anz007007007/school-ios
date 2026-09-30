import Foundation

struct ClubsListResponseDTO: Codable {
    let items: [ClubDTO]
}

struct ClubDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let weekday: Int
    let start_time: String
    let end_time: String
    let capacity: Int
    let price_amount: String
    let payment_type: String?
    let price_period: String?
    let teacher_name: String
    let teacher_id: Int?
    let teacher_user_id: Int?
    let teacher_phone: String?
    let teacher_mobile_phone: String?
    let teacher_contact_phone: String?
    let status: String
    let enrolled_count: Int
    let waiting_count: Int?
    let free_places: Int?
    let enrolled_names: String?

    var availableSpots: Int {
        if let free_places {
            return max(free_places, 0)
        }

        return max(capacity - enrolled_count, 0)
    }

    var isFull: Bool {
        capacity > 0 && availableSpots <= 0
    }

    var paymentTypeValue: String? {
        payment_type ?? price_period
    }

    var resolvedTeacherPhone: String? {
        let values = [
            teacher_phone,
            teacher_mobile_phone,
            teacher_contact_phone
        ]

        return values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    var resolvedTeacherUserID: Int? {
        teacher_user_id ?? teacher_id
    }

    var enrolledStudentIDs: Set<Int> {
        guard let enrolled_names, !enrolled_names.isEmpty else {
            return []
        }

        let pairs = enrolled_names.split(separator: "|")

        let ids = pairs.compactMap { pair -> Int? in
            let parts = pair.split(separator: ":")

            guard let first = parts.first else {
                return nil
            }

            return Int(first)
        }

        return Set(ids)
    }

    func isStudentAlreadyEnrolled(_ studentID: Int) -> Bool {
        enrolledStudentIDs.contains(studentID)
    }

    func hasAvailableStudentForEnrollment(_ students: [ClubFilterStudentDTO]) -> Bool {
        students.contains { !isStudentAlreadyEnrolled($0.id) }
    }
}

struct ClubsOverviewDTO: Codable, Hashable {
    let total: Int
    let active_count: Int
    let draft_count: Int
    let archived_count: Int
    let full_count: Int
    let enrolled_count: Int
}

struct ClubFiltersDTO: Codable, Hashable {
    let students: [ClubFilterStudentDTO]
    let teachers: [ClubFilterTeacherDTO]
}

struct ClubFilterStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let first_name: String
    let last_name: String
    let status: String
    let student_name: String
}

struct ClubFilterTeacherDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int
    let teacher_name: String
}

struct ClubFormData: Hashable {
    let name: String
    let description: String
    let weekdayIDs: [Int]
    let startTime: String
    let endTime: String
    let capacity: Int
    let priceAmount: String
    let paymentType: String
    let teacherID: Int
    let status: String
}

struct ClubStudentsListResponseDTO: Codable {
    let items: [ClubStudentDTO]
}

struct ClubStudentDTO: Codable, Identifiable, Hashable {
    let club_id: Int
    let student_id: Int
    let enrollment_status: String
    let student_name: String

    var id: Int {
        student_id
    }
}

struct ClubStudentFormData: Hashable {
    let studentID: Int
    let enrollmentStatus: String
}

struct ClubEnrollStatusResponseDTO: Codable, Hashable {
    let status: String?
    let club_id: Int?
    let student_id: Int?
    let message: String?
}