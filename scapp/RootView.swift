import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else if appState.isLoading && !appState.didTryRestoreSession {
                ProgressView("Восстанавливаем вход...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
            } else {
                LoginView()
            }
        }
        .task {
            await appState.restoreSessionIfPossible()
        }
    }
}