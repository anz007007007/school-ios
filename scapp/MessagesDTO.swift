import Foundation

struct MessagesListResponseDTO: Codable {
    let items: [MessageDTO]
}

struct MessageDTO: Codable, Identifiable, Hashable {
    let id: Int
    let parent_message_id: Int?
    let subject: String
    let body: String
    let is_read: Bool
    let is_important: Bool
    let created_at: String
    let read_at: String?
    let sender_user_id: Int
    let recipient_user_id: Int
    let sender_name: String
    let recipient_name: String
    let sender_role_code: String?
    let recipient_role_code: String?

    func isIncoming(for userID: Int?) -> Bool {
        guard let userID else {
            return false
        }

        return recipient_user_id == userID
    }
}

struct MessageContactsListResponseDTO: Codable {
    let items: [MessageContactDTO]
}

struct MessageContactDTO: Codable, Identifiable, Hashable {
    let id: Int
    let full_name: String
    let role_code: String
    let role_name: String
    let context_label: String?
    let phone: String?

    init(
        id: Int,
        full_name: String,
        role_code: String,
        role_name: String,
        context_label: String?,
        phone: String? = nil
    ) {
        self.id = id
        self.full_name = full_name
        self.role_code = role_code
        self.role_name = role_name
        self.context_label = context_label
        self.phone = phone
    }

    var name: String {
        full_name
    }

    var displayTitle: String {
        let cleanName = full_name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = role_name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContext = context_label?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedRole = cleanRole.lowercased()
        let normalizedContext = cleanContext?.lowercased()

        if let cleanContext,
           !cleanContext.isEmpty,
           normalizedContext != normalizedRole,
           !cleanName.localizedCaseInsensitiveContains(cleanContext),
           !cleanRole.localizedCaseInsensitiveContains(cleanContext) {
            return "\(cleanName) · \(cleanRole) · \(cleanContext)"
        }

        return "\(cleanName) · \(cleanRole)"
    }

    var normalizedSearchText: String {
        [
            full_name,
            role_name,
            context_label ?? "",
            phone ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }
}

struct MessageClassesListResponseDTO: Codable {
    let items: [MessageClassDTO]
}

struct MessageClassDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let academic_year: String?
    let education_level: String?
}

struct MessageCreateFormData: Hashable {
    let recipientUserID: Int
    let subject: String
    let body: String
    let isImportant: Bool
}

struct MessageBulkFormData: Hashable {
    let recipientUserIDs: [Int]
    let subject: String
    let body: String
    let isImportant: Bool
}

struct MessageCreateRequestDTO: Codable {
    let recipient_user_id: Int
    let subject: String
    let body: String
    let is_important: Bool?
}

struct MessageBulkCreateRequestDTO: Codable {
    let recipient_user_ids: [Int]?
    let subject: String
    let body: String
    let is_important: Bool?
}

struct MessageIDStatusResponseDTO: Codable {
    let id: Int?
    let status: String?
    let message: String?
}

struct MessageStateUpdateRequestDTO: Codable {
    let state: String
}

struct BulkMessageStatusResponseDTO: Codable {
    let status: String?
    let sent_count: Int?
    let message: String?
}

struct UnreadMessagesCountDTO: Codable, Hashable {
    let unread_count: Int
}

struct AnnouncementsListResponseDTO: Codable {
    let items: [AnnouncementDTO]
}

struct AnnouncementDTO: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let body: String
    let target_audience: String
    let target_role_code: String?
    let class_id: Int?
    let is_important: Bool
    let is_read: Bool?
    let published_at: String?
    let expires_at: String?
    let created_at: String
    let class_name: String?
    let author_name: String
    /// Подразделения ([] — вся школа); старые серверы поле не присылают.
    var division_ids: [Int]? = nil
}

struct AnnouncementFormData: Hashable {
    let title: String
    let body: String
    let targetAudience: String
    let isImportant: Bool
    /// «Для кого»: nil — не отправлять, [] — вся школа.
    var divisionIDs: [Int]? = nil
}

struct AnnouncementCreateRequestDTO: Codable {
    let title: String
    let body: String
    let target_audience: String?
    let is_important: Bool?
}

struct AnnouncementIDStatusResponseDTO: Codable {
    let id: Int?
    let announcement_id: Int?
    let status: String?
    let message: String?
}