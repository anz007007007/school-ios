import SwiftUI

@main
struct scappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @ObservedObject private var pushService = PushNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(pushService)
                .preferredColorScheme(.light)
                .onAppear {
                    pushService.configure()

                    if appState.isAuthenticated {
                        Task {
                            await pushService.ensurePushRegistration(api: appState.api)
                        }
                    }
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active, appState.isAuthenticated {
                        Task {
                            await pushService.ensurePushRegistration(api: appState.api)
                        }
                    }
                }
                .onChange(of: appState.isAuthenticated) {
                    if appState.isAuthenticated {
                        Task {
                            await pushService.ensurePushRegistration(api: appState.api)
                        }
                    }
                }
        }
    }
}