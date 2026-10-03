import Foundation

/// Ответ GET /api/v1/cameras (backend/app/routers/cameras.py, list_cameras):
/// camera.read может любая штатная роль, сервер сам фильтрует видимые камеры
/// (по подразделению + персональным исключениям camera_user_overrides).
struct CamerasListResponseDTO: Decodable {
    let items: [CameraDTO]
    /// Поднят ли вообще медиа-сервер (MediaMTX) на проде. Пока его не поставили —
    /// у каждой камеры stream_available будет false (это ожидаемое состояние, не ошибка).
    let mediamtx_configured: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case mediamtx_configured
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([CameraDTO].self, forKey: .items) ?? []
        mediamtx_configured = try container.decodeIfPresent(Bool.self, forKey: .mediamtx_configured) ?? false
    }
}

struct CameraDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let channel: Int
    let is_active: Bool
    /// Подразделения ([] — вся школа).
    let division_ids: [Int]
    /// Доступен ли в принципе поток с этой камеры (зеркалит mediamtx_configured на момент ответа).
    let stream_available: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case channel
        case is_active
        case division_ids
        case stream_available
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Камера"
        channel = try container.decodeIfPresent(Int.self, forKey: .channel) ?? 0
        is_active = try container.decodeIfPresent(Bool.self, forKey: .is_active) ?? true
        division_ids = try container.decodeIfPresent([Int].self, forKey: .division_ids) ?? []
        stream_available = try container.decodeIfPresent(Bool.self, forKey: .stream_available) ?? false
    }
}
