import Foundation

extension Notification.Name {
    static let authSessionExpired = Notification.Name("authSessionExpired")
    static let pushNotificationTapStored = Notification.Name("pushNotificationTapStored")
}

enum AuthSessionEvents {
    static func notifySessionExpired() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
        }
    }

    static func notifyPushNotificationTapStored() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .pushNotificationTapStored, object: nil)
        }
    }
}