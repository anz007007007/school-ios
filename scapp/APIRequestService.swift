import Foundation
import SchoolAPIClient

@MainActor
final class APIRequestService {
    static let shared = APIRequestService()

    private init() {}

    private let scheme = "https"
    private let host = "sc.it-status.ru"

    func request(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        logPrefix: String = "API"
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.noToken
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIRequestError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            #if DEBUG
            print("\(logPrefix) REQUEST:", method, url.absoluteString)
            print("\(logPrefix) BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("\(logPrefix) REQUEST:", method, url.absoluteString)
            #endif
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIRequestError.badResponse
            }

            let responseText = String(data: data, encoding: .utf8) ?? ""

            #if DEBUG
            print("\(logPrefix) RESPONSE STATUS:", httpResponse.statusCode)
            print("\(logPrefix) RESPONSE BODY:", responseText)
            #endif

            if httpResponse.statusCode == 401 {
                AuthSessionEvents.notifySessionExpired(requestToken: token)
                throw APIRequestError.serverError(
                    statusCode: httpResponse.statusCode,
                    text: responseText
                )
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIRequestError.serverError(
                    statusCode: httpResponse.statusCode,
                    text: responseText
                )
            }

            return data
        } catch let error as APIRequestError {
            throw error
        } catch {
            throw APIRequestError.networkError(error.localizedDescription)
        }
    }

    func decode<T: Decodable>(
        _ type: T.Type,
        api: SchoolAPI,
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        logPrefix: String = "API",
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await request(
            api: api,
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            logPrefix: logPrefix
        )

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIRequestError.decodingError(error.localizedDescription)
        }
    }
}

enum APIRequestError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case networkError(String)
    case decodingError(String)
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Сессия истекла. Войдите снова."

        case .badURL:
            return "Некорректный адрес запроса."

        case .badResponse:
            return "Некорректный ответ сервера."

        case .networkError(let message):
            return "Ошибка сети: \(message)"

        case .decodingError(let message):
            return "Не удалось прочитать ответ сервера: \(message)"

        case .serverError(let statusCode, let text):
            return Self.readableServerError(statusCode: statusCode, text: text)
        }
    }

    /// Понятный русский текст по коду ответа и `detail` FastAPI (без «HTTP 4xx» и сырого JSON).
    static func readableServerError(statusCode: Int, text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if statusCode == 401 {
            return "Сессия истекла. Войдите снова."
        }

        if statusCode == 403 {
            return readableDetail(from: cleanText)
                ?? "У вас нет прав на это действие."
        }

        if statusCode == 404 {
            return readableDetail(from: cleanText)
                ?? "Данные не найдены."
        }

        if statusCode == 422 {
            return readableValidationError(from: cleanText)
                ?? readableDetail(from: cleanText)
                ?? "Проверьте заполнение полей."
        }

        if statusCode >= 500 {
            return "Ошибка сервера. Попробуйте позже."
        }

        if let detail = readableDetail(from: cleanText) {
            return detail
        }

        switch statusCode {
        case 400:
            return "Сервер отклонил запрос. Проверьте введённые данные."
        case 409:
            return "Такая запись уже существует."
        default:
            return "Ошибка сервера (код \(statusCode))."
        }
    }

    private static func readableDetail(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] else {
            return nil
        }

        if let string = detail as? String {
            return translateServerMessage(string)
        }

        return nil
    }

    private static func readableValidationError(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let details = json["detail"] as? [[String: Any]] else {
            return nil
        }

        let messages = details.compactMap { item -> String? in
            let message = item["msg"] as? String
            let location = item["loc"] as? [Any]

            if let field = location?.last as? String {
                return readableFieldError(field: field, message: message)
            }

            return message
        }

        guard !messages.isEmpty else {
            return nil
        }

        return messages.joined(separator: "\n")
    }

    private static func readableFieldError(field: String, message: String?) -> String {
        let fieldTitle = fieldTitle(field)

        if message?.lowercased().contains("field required") == true {
            return "Заполните поле: \(fieldTitle)"
        }

        return "\(fieldTitle): \(message ?? "некорректное значение")"
    }

    private static func fieldTitle(_ field: String) -> String {
        switch field {
        case "class_id":
            return "класс"
        case "student_id":
            return "ученик"
        case "subject_id":
            return "предмет"
        case "teacher_id":
            return "учитель"
        case "old_password":
            return "текущий пароль"
        case "new_password":
            return "новый пароль"
        case "password":
            return "пароль"
        case "login":
            return "логин"
        case "title":
            return "название"
        case "body":
            return "текст"
        case "description":
            return "описание"
        case "date_from":
            return "дата начала"
        case "date_to":
            return "дата окончания"
        case "due_date":
            return "срок выполнения"
        case "grade_value":
            return "оценка"
        case "grade_type":
            return "тип оценки"
        default:
            return field
                .replacingOccurrences(of: "_", with: " ")
        }
    }

    private static func translateServerMessage(_ message: String) -> String {
        if let known = APIServerMessageTranslations.known[message.trimmingCharacters(in: .whitespacesAndNewlines)] {
            return known
        }

        let lowercased = message.lowercased()

        if lowercased.contains("student already has credentials") {
            return "У ребёнка уже есть учётная запись. Старый пароль посмотреть нельзя."
        }

        if lowercased.contains("only parent can create student credentials") {
            return "Создать учётные данные ребёнка может только родитель."
        }

        if lowercased.contains("message not found") {
            return "Сообщение не найдено или недоступно."
        }

        if lowercased.contains("not authenticated") {
            return "Войдите в приложение снова."
        }

        if lowercased.contains("permission") || lowercased.contains("forbidden") {
            return "У вас нет прав на это действие."
        }

        return message
    }
}

extension URLRequest {
    /// Тип клиента и техническая информация: по ней веб-аналитика показывает, кто с какой
    /// версией и устройства заходит, а mobile-config отвечает, нужно ли обновиться.
    mutating func applyMobileClientHeaders() {
        for (name, value) in MobileClientInfo.headers {
            setValue(value, forHTTPHeaderField: name)
        }
    }
}

enum MobileClientInfo {
    static let headers: [String: String] = {
        let info = Bundle.main.infoDictionary ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion

        return [
            "x-client-type": "mobile",
            "x-platform": "ios",
            "x-app-version": info["CFBundleShortVersionString"] as? String ?? "",
            "x-app-build": info["CFBundleVersion"] as? String ?? "",
            "x-os-version": "iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "x-device-model": deviceModel
        ]
    }()

    /// Код модели вида «iPhone17,1» (в симуляторе — модель, которую он изображает).
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}