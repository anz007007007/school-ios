import Foundation
import LocalAuthentication
import Security

final class LoginSecurityService {
    static let shared = LoginSecurityService()

    private init() {}

    private let service = "scapp.login.credentials"
    private let account = "lastLogin"

    private let savedLoginKey = "login.savedLogin"
    private let rememberLoginKey = "login.rememberLogin"
    private let failedAttemptsKey = "login.failedAttempts"
    private let lockUntilKey = "login.lockUntil"
    private let sessionActiveKey = "login.sessionActive"

    private let maxAttempts = 5
    private let lockDuration: TimeInterval = 60

    struct Credentials: Hashable {
        let login: String
        let password: String
    }

    // MARK: - Saved login

    var savedLogin: String {
        get {
            UserDefaults.standard.string(forKey: savedLoginKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: savedLoginKey)
        }
    }

    var rememberLogin: Bool {
        get {
            UserDefaults.standard.bool(forKey: rememberLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: rememberLoginKey)
        }
    }

    /// Пользователь вошёл и не нажимал «Выйти». Автовход при запуске выполняется
    /// только тогда: сохранённые данные остаются для входа по биометрии, но после
    /// выхода приложение не должно само войти снова. Нет значения (старые установки) — true.
    var isSessionActive: Bool {
        get {
            UserDefaults.standard.object(forKey: sessionActiveKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sessionActiveKey)
        }
    }

    // MARK: - Brute force protection

    var failedAttempts: Int {
        get {
            UserDefaults.standard.integer(forKey: failedAttemptsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: failedAttemptsKey)
        }
    }

    var lockUntil: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: lockUntilKey)

            guard timestamp > 0 else {
                return nil
            }

            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: lockUntilKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lockUntilKey)
            }
        }
    }

    var isLocked: Bool {
        guard let lockUntil else {
            return false
        }

        if Date() >= lockUntil {
            clearLock()
            return false
        }

        return true
    }

    var lockRemainingSeconds: Int {
        guard let lockUntil else {
            return 0
        }

        return max(Int(lockUntil.timeIntervalSince(Date()).rounded(.up)), 0)
    }

    func registerFailedAttempt() {
        failedAttempts += 1

        if failedAttempts >= maxAttempts {
            lockUntil = Date().addingTimeInterval(lockDuration)
        }
    }

    func resetFailedAttempts() {
        failedAttempts = 0
        lockUntil = nil
    }

    func clearLock() {
        failedAttempts = 0
        lockUntil = nil
    }

    // MARK: - Keychain

    func saveCredentials(_ credentials: Credentials) throws {
        savedLogin = credentials.login
        rememberLogin = true

        let payload = "\(credentials.login)\n\(credentials.password)"

        guard let data = payload.data(using: .utf8) else {
            throw LoginSecurityError.encodingFailed
        }

        deleteCredentials()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw LoginSecurityError.keychainError(status)
        }
    }

    func loadCredentials() throws -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw LoginSecurityError.keychainError(status)
        }

        guard let data = result as? Data,
              let payload = String(data: data, encoding: .utf8) else {
            throw LoginSecurityError.decodingFailed
        }

        let parts = payload.components(separatedBy: "\n")

        guard parts.count >= 2 else {
            throw LoginSecurityError.decodingFailed
        }

        return Credentials(
            login: parts[0],
            password: parts.dropFirst().joined(separator: "\n")
        )
    }

    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    func clearSavedCredentials() {
        savedLogin = ""
        rememberLogin = false
        deleteCredentials()
    }

    // MARK: - Biometrics

    func biometricTypeTitle() -> String {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Биометрия"
        }

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Биометрия"
        }
    }

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    func authenticateWithBiometrics(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"

        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw LoginSecurityError.biometryUnavailable
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        guard success else {
            throw LoginSecurityError.biometryFailed
        }
    }
}

enum LoginSecurityError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case keychainError(OSStatus)
    case biometryUnavailable
    case biometryFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Не удалось сохранить данные входа."
        case .decodingFailed:
            return "Не удалось прочитать сохранённые данные входа."
        case .keychainError(let status):
            return "Ошибка хранилища паролей: \(status)"
        case .biometryUnavailable:
            return "Биометрия недоступна на этом устройстве."
        case .biometryFailed:
            return "Не удалось пройти биометрическую проверку."
        }
    }
}