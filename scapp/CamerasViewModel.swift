import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class CamerasViewModel: ObservableObject {
    @Published var cameras: [CameraDTO] = []
    @Published var mediamtxConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false

    /// Камеры подключены, но живого видео ни у одной пока нет (медиа-сервер не поднят на проде) —
    /// показываем один общий баннер вместо списка.
    var shouldShowComingSoonBanner: Bool {
        !cameras.isEmpty && cameras.allSatisfy { !$0.stream_available }
    }

    func loadCameras(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                CamerasListResponseDTO.self,
                api: api,
                path: "/api/v1/cameras",
                method: "GET",
                logPrefix: "CAMERAS"
            )

            cameras = response.items
            mediamtxConfigured = response.mediamtx_configured
            hasLoaded = true
        } catch {
            errorMessage = "Не удалось загрузить камеры: \(error.localizedDescription)"
        }

        isLoading = false
    }

    enum StreamCheckResult {
        case available(URL)
        case unavailable(String)
    }

    /// Проверяет доступность потока простым GET к stream.m3u8 прежде, чем отдавать URL плееру:
    /// AVPlayer сам по себе просто «крутится», не показывая понятную ошибку 503/404.
    static func checkStreamAvailability(api: SchoolAPI, cameraID: Int) async -> StreamCheckResult {
        let path = "/api/v1/cameras/\(cameraID)/stream.m3u8"

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            return .unavailable("Некорректный адрес запроса.")
        }

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: path,
                method: "GET",
                logPrefix: "CAMERA STREAM CHECK"
            )

            return .available(url)
        } catch let error as APIRequestError {
            switch error {
            case .serverError(let statusCode, _):
                if statusCode == 404 {
                    return .unavailable("Нет доступа к этой камере.")
                }

                // 503 (медиа-сервер не отвечает) и прочие серверные ошибки — одна и та же
                // понятная формулировка, без технических подробностей.
                return .unavailable("Видео временно недоступно.")

            case .noToken:
                return .unavailable("Сессия истекла. Войдите снова.")

            default:
                return .unavailable("Видео временно недоступно.")
            }
        } catch {
            return .unavailable("Видео временно недоступно.")
        }
    }
}
