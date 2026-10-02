import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

/// Токен читает middleware в потоке URLSession, а пишут login/logout на главном —
/// доступ под замком, иначе это гонка данных.
private final class AuthTokenStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var storedToken: String?

    var token: String? {
        get { lock.withLock { storedToken } }
        set { lock.withLock { storedToken = newValue } }
    }
}

private struct AuthMiddleware: ClientMiddleware {
    let tokenStorage: AuthTokenStorage

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request

        if let token = tokenStorage.token {
            request.headerFields[.authorization] = "Bearer \(token)"
        }

        // Как applyMobileClientHeaders() в приложении: сервер по ним отличает мобильный клиент.
        if let clientType = HTTPField.Name("x-client-type"), let platform = HTTPField.Name("x-platform") {
            request.headerFields[clientType] = "mobile"
            request.headerFields[platform] = "ios"
        }

        return try await next(request, body, baseURL)
    }
}

public final class SchoolAPI {
    public private(set) var client: Client

    private let tokenStorage = AuthTokenStorage()

    public var authToken: String? {
        tokenStorage.token
    }

    public init(baseURL: URL) {
        self.client = Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [
                AuthMiddleware(tokenStorage: tokenStorage)
            ]
        )
    }

    // MARK: - System

    public func healthCheck() async throws -> Components.Schemas.HealthCheckResponse {
        let output = try await client.health_check_api_v1_health_get()
        return try output.ok.body.json
    }

    // MARK: - Auth

    public func login(
        login: String,
        password: String,
        personalDataAgreement: Bool = true,
        termsAgreement: Bool = true
    ) async throws -> Components.Schemas.TokenResponse {
        #if DEBUG
        print("LOGIN BODY:", [
            "login": login,
            "password": "***",
            "personal_data_agreement": personalDataAgreement,
            "terms_agreement": termsAgreement
        ])
        #endif

        let request = Components.Schemas.LoginRequest(
            login: login,
            password: password,
            personal_data_agreement: personalDataAgreement,
            terms_agreement: termsAgreement
        )

        let output = try await client.login_api_v1_auth_login_post(
            .init(
                body: .json(request)
            )
        )

        switch output {
        case .ok(let response):
            let token = try response.body.json
            tokenStorage.token = token.access_token
            return token

        case .unprocessableContent:
            throw SchoolAPIError.serverError("Проверьте логин, пароль и согласия.")

        case .undocumented(let statusCode, _):
            if statusCode == 401 {
                throw SchoolAPIError.serverError("Неверный логин или пароль.")
            }

            if statusCode == 400 {
                throw SchoolAPIError.serverError("Проверьте данные для входа и согласия.")
            }

            if statusCode >= 500 {
                throw SchoolAPIError.serverError("Ошибка сервера. Попробуйте позже.")
            }

            throw SchoolAPIError.serverError("Ошибка авторизации: \(statusCode)")
        }
    }

    public func getCurrentUser() async throws -> Components.Schemas.CurrentUserResponse {
        let output = try await client.me_api_v1_auth_me_get()

        switch output {
        case .ok(let response):
            return try response.body.json

        case .unprocessableContent:
            throw SchoolAPIError.serverError("Не удалось загрузить текущего пользователя.")

        case .undocumented(let statusCode, _):
            if statusCode == 401 {
                throw SchoolAPIError.serverError("Сессия истекла. Войдите снова.")
            }

            throw SchoolAPIError.serverError("Ошибка загрузки профиля: \(statusCode)")
        }
    }

    public func logout() {
        tokenStorage.token = nil
    }
}

public enum SchoolAPIError: LocalizedError {
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        }
    }
}
