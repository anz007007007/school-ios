import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else if appState.isRestoringSession || !appState.didTryRestoreSession {
                ProgressView("Восстанавливаем вход...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
            } else if let startupErrorMessage = appState.startupErrorMessage {
                StartupErrorView(
                    message: startupErrorMessage,
                    onRetry: {
                        Task {
                            await appState.retrySessionRestore()
                        }
                    },
                    onLogout: {
                        appState.cancelSessionRestore()
                    }
                )
            } else {
                LoginView()
            }
        }
        .task {
            await appState.restoreSessionIfPossible()
        }
    }
}

/// Автовход при запуске не удался из-за сети или сервера. Данные входа сохранены:
/// можно повторить или выйти к форме входа.
private struct StartupErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.warning)

            Text("Не удалось войти")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.heading)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Text("Повторить")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            Button("Выйти", role: .destructive, action: onLogout)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}
