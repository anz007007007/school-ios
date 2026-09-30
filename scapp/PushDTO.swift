import Foundation

// MARK: - Notification Settings
struct NotificationSettingsListResponseDTO: Codable {
    let items: [NotificationSettingDTO]
}

struct NotificationSettingDTO: Codable, Identifiable, Hashable {
    var id: String { section_code }

    let section_code: String
    let section_name: String
    var in_app_enabled: Bool
    var push_enabled: Bool
    var email_enabled: Bool
    var sms_enabled: Bool
    let sort_order: Int?
}

struct NotificationSettingUpdateRequestDTO: Codable {
    let section_code: String
    let in_app_enabled: Bool
    let push_enabled: Bool
    let email_enabled: Bool
    let sms_enabled: Bool
}

// MARK: - Push Devices
struct PushDevicesListResponseDTO: Codable {
    let items: [PushDeviceDTO]
}

struct PushDeviceDTO: Codable, Identifiable, Hashable {
    let id: Int
    let platform: String?
    let device_token: String?
    let device_uid: String?
    let environment: String?
    let apns_environment: String?
    let is_active: Bool
    let created_at: String?
    let updated_at: String?
    let last_seen_at: String?

    var title: String {
        switch platform?.lowercased() {
        case "ios":
            return "iPhone / iPad"
        case "android":
            return "Android"
        case .some(let value):
            return value
        case .none:
            return "Устройство"
        }
    }

    var subtitle: String {
        let values = [
            environmentTitle,
            lastSeenTitle
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        if values.isEmpty {
            return is_active ? "Активно" : "Отключено"
        }

        return values.joined(separator: " · ")
    }

    var tokenPreview: String {
        guard let device_token, !device_token.isEmpty else {
            return "token отсутствует"
        }

        if device_token.count <= 16 {
            return device_token
        }

        return "\(device_token.prefix(8))…\(device_token.suffix(6))"
    }

    private var environmentTitle: String? {
        let value = apns_environment ?? environment

        switch value?.lowercased() {
        case "sandbox":
            return "Тестовая среда"
        case "production":
            return "Production"
        case .some(let value):
            return value
        case .none:
            return nil
        }
    }

    private var lastSeenTitle: String? {
        guard let value = last_seen_at ?? updated_at ?? created_at else {
            return nil
        }

        return "Активность: \(value)"
    }
}

struct PushDeviceRegisterResponseDTO: Codable {
    let status: String
    let push_device_id: Int?
}

// MARK: - Notifications
struct NotificationsListResponseDTO: Codable {
    let items: [AppNotificationDTO]
    let unread_count: Int
}

struct AppNotificationDTO: Codable, Identifiable, Hashable {
    let id: Int
    let user_id: Int
    let title: String
    let body: String
    let notification_type: String
    let section_code: String?
    let is_read: Bool
    let payload_json: [String: PushNotificationPayloadValue]?
    let created_at: String
    let read_at: String?
}

enum PushNotificationPayloadValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: PushNotificationPayloadValue])
    case array([PushNotificationPayloadValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: PushNotificationPayloadValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([PushNotificationPayloadValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .bool(let value):
            return value ? "true" : "false"
        case .dictionary(let value):
            return value.map { "\($0.key):\($0.value.stringValue)" }.joined(separator: " ")
        case .array(let value):
            return value.map(\.stringValue).joined(separator: " ")
        case .null:
            return ""
        }
    }
}