import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("PUSH APP DELEGATE: didFinishLaunching")

        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("PUSH LAUNCH FROM REMOTE NOTIFICATION:", remoteNotification)
            PushNotificationService.storePendingNotificationTapPayload(remoteNotification)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                AuthSessionEvents.notifyPushNotificationTapStored()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        #if DEBUG
        print("PUSH APNS ENVIRONMENT: sandbox")
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
        print("PUSH APNS ENVIRONMENT: production")
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif

        print("PUSH APNS TOKEN FROM APP DELEGATE:", token)

        Task { @MainActor in
            PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("PUSH APNS REGISTER FAILED:", error.localizedDescription)

        Task { @MainActor in
            PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        print("PUSH FIREBASE DELEGATE FCM TOKEN:", fcmToken ?? "nil")

        Task { @MainActor in
            PushNotificationService.shared.didReceiveFCMTokenFromDelegate(fcmToken)
        }
    }
}