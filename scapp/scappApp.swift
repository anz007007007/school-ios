import SwiftUI

@main
struct scappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @ObservedObject private var pushService = PushNotificationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(pushService)
                .preferredColorScheme(.light)
                .onAppear {
                    // Регистрация устройства на сервере — только через
                    // AppState.registerPushNotificationsIfNeeded (после входа и при
                    // возврате в приложение в MainTabView): он учитывает флаг push
                    // из mobile-config и не регистрирует устройство без входа.
                    pushService.configure()
                }
        }
    }
}
