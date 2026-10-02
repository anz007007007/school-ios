import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var login = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var rememberLogin = true

    // Согласие пользователь даёт сам: заранее отмеченная галочка не считается согласием (152-ФЗ).
    @State private var personalDataAccepted = false
    @State private var termsAccepted = false

    @Environment(\.openURL) private var openURL

    @State private var localErrorMessage: String?
    @State private var isBiometricAvailable = false
    @State private var biometricTitle = "Биометрия"
    @State private var lockRemainingSeconds = 0

    private let security = LoginSecurityService.shared
    private let personalDataURL = URL(string: "https://sc.it-status.ru/web/legal/personal-data")!
    private let termsURL = URL(string: "https://sc.it-status.ru/web/legal/terms")!

    private var isLocked: Bool {
        security.isLocked
    }

    private var displayedErrorMessage: String? {
        localErrorMessage ?? appState.errorMessage
    }

    private var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
        && !appState.isLoading
        && !isLocked
        && personalDataAccepted
        && termsAccepted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 40)

                    headerView

                    VStack(spacing: 18) {
                        formView
                        legalConsentView

                        if let displayedErrorMessage {
                            Text(displayedErrorMessage)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if isLocked {
                            lockView
                        }

                        loginButton

                        if isBiometricAvailable && rememberLogin {
                            biometricButton
                        }
                    }
                    .appCard()

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .onAppear {
                setup()
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 14) {
            AppLogoView(size: 92)

            Text("Солнечный круг")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(AppTheme.primary)
                .multilineTextAlignment(.center)
                .shadow(color: AppTheme.accent.opacity(0.55), radius: 0, x: 0, y: 2)

            Text("Вход в приложение")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var formView: some View {
        VStack(spacing: 14) {
            TextField("Логин", text: $login)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .appField()
                .disabled(appState.isLoading || isLocked)

            HStack(spacing: 8) {
                Group {
                    if isPasswordVisible {
                        TextField("Пароль", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Пароль", text: $password)
                            .textContentType(.password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Скрыть пароль" : "Показать пароль")
            }
            .appField()
            .disabled(appState.isLoading || isLocked)

            Toggle("Запомнить вход", isOn: $rememberLogin)
                .fontWeight(.semibold)
                .tint(AppTheme.primaryDark)
                .foregroundStyle(AppTheme.text)
                .disabled(appState.isLoading || isLocked)
                .onChange(of: rememberLogin) { _ in
                    security.rememberLogin = rememberLogin

                    if !rememberLogin {
                        security.clearSavedCredentials()
                    }
                }
        }
    }

    private var legalConsentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $personalDataAccepted) {
                HStack(spacing: 4) {
                    Text("Я согласен на обработку")

                    Button {
                        openURL(personalDataURL)
                    } label: {
                        Text("персональных данных")
                            .underline()
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.sidebar)
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkboxLike)
            .tint(AppTheme.primaryDark)

            Toggle(isOn: $termsAccepted) {
                HStack(spacing: 4) {
                    Text("Я принимаю")

                    Button {
                        openURL(termsURL)
                    } label: {
                        Text("условия пользования приложением")
                            .underline()
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.sidebar)
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkboxLike)
            .tint(AppTheme.primaryDark)

            Text("Отметки нужны по закону о персональных данных: с вашим согласием приложение может показывать оценки, расписание и сообщения.")
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockView: some View {
        Label(
            "Слишком много попыток. Повторите через \(lockRemainingSeconds) сек.",
            systemImage: "lock.fill"
        )
        .font(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(AppTheme.warning)
        .multilineTextAlignment(.center)
    }

    private var loginButton: some View {
        Button {
            Task {
                await loginWithPassword()
            }
        } label: {
            HStack {
                if appState.isLoading {
                    ProgressView()
                        .tint(Color(red: 0.29, green: 0.153, blue: 0.0))
                }

                Text(appState.isLoading ? "Вход..." : "Войти")
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }

    private var biometricButton: some View {
        Button {
            Task {
                await loginWithBiometrics()
            }
        } label: {
            Label("Войти через \(biometricTitle)", systemImage: "faceid")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppSecondaryButtonStyle())
        .disabled(appState.isLoading || isLocked || !personalDataAccepted || !termsAccepted)
        .opacity((personalDataAccepted && termsAccepted) ? 1 : 0.55)
    }

    private func setup() {
        login = security.savedLogin
        rememberLogin = security.rememberLogin
        biometricTitle = security.biometricTypeTitle()
        isBiometricAvailable = security.canUseBiometrics()

        updateLockTimer()

        if rememberLogin {
            do {
                if let credentials = try security.loadCredentials() {
                    login = credentials.login
                }
            } catch {
                localErrorMessage = error.localizedDescription
            }
        }
    }

    private func updateLockTimer() {
        lockRemainingSeconds = security.lockRemainingSeconds

        guard isLocked else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            updateLockTimer()
        }
    }

    private func loginWithPassword() async {
        localErrorMessage = nil

        guard personalDataAccepted && termsAccepted else {
            localErrorMessage = "Для входа необходимо принять согласие на обработку персональных данных и условия пользования приложением."
            return
        }

        guard !security.isLocked else {
            updateLockTimer()
            return
        }

        let cleanLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)

        await appState.login(
            login: cleanLogin,
            password: password,
            personalDataAgreement: personalDataAccepted,
            termsAgreement: termsAccepted
        )

        if appState.isAuthenticated {
            security.resetFailedAttempts()

            if rememberLogin {
                do {
                    try security.saveCredentials(
                        LoginSecurityService.Credentials(
                            login: cleanLogin,
                            password: password
                        )
                    )
                } catch {
                    localErrorMessage = error.localizedDescription
                }
            } else {
                security.clearSavedCredentials()
            }
        } else if appState.lastLoginRejected {
            // В счётчик блокировки — только отказ сервера, не сетевая ошибка.
            security.registerFailedAttempt()
            updateLockTimer()
        }
    }

    private func loginWithBiometrics() async {
        localErrorMessage = nil

        guard personalDataAccepted && termsAccepted else {
            localErrorMessage = "Для входа необходимо принять согласие на обработку персональных данных и условия пользования приложением."
            return
        }

        guard !security.isLocked else {
            updateLockTimer()
            return
        }

        do {
            guard let credentials = try security.loadCredentials() else {
                localErrorMessage = "Сначала войдите с паролем и включите «Запомнить вход»."
                return
            }

            try await security.authenticateWithBiometrics(
                reason: "Войти в школьное приложение"
            )

            login = credentials.login
            password = credentials.password

            await appState.login(
                login: credentials.login,
                password: credentials.password,
                personalDataAgreement: personalDataAccepted,
                termsAgreement: termsAccepted
            )

            if appState.isAuthenticated {
                security.resetFailedAttempts()
            } else if appState.lastLoginRejected {
                security.registerFailedAttempt()
                updateLockTimer()
            }
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }
}

private struct CheckboxLikeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? AppTheme.primaryDark : AppTheme.muted)

                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == CheckboxLikeToggleStyle {
    static var checkboxLike: CheckboxLikeToggleStyle {
        CheckboxLikeToggleStyle()
    }
}