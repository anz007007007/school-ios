import Foundation

extension Notification.Name {
    static let authSessionExpired = Notification.Name("authSessionExpired")
    static let pushNotificationTapStored = Notification.Name("pushNotificationTapStored")
}

enum AuthSessionEvents {
    /// Ключ userInfo с токеном, с которым ушёл запрос, получивший 401.
    static let requestTokenKey = "requestToken"

    /// Сообщает о 401. Передавайте `requestToken` — токен, с которым ушёл запрос:
    /// тогда запоздавший ответ на запрос прошлой сессии не разлогинит текущую.
    /// Без него AppState сначала перепроверит сессию через /auth/me.
    static func notifySessionExpired(requestToken: String? = nil) {
        let userInfo: [String: Any]? = requestToken.map { [requestTokenKey: $0] }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .authSessionExpired, object: nil, userInfo: userInfo)
        }
    }

    static func notifyPushNotificationTapStored() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .pushNotificationTapStored, object: nil)
        }
    }
}
