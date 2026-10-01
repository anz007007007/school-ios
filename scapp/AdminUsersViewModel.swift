import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published var users: [AdminUserDTO] = []
    @Published var searchText = ""
    @Published var selectedFilter: AdminUsersFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum AdminUsersFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"

        var id: String {
            rawValue
        }
    }

    var filteredUsers: [AdminUserDTO] {
        var result = users

        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.is_active }
        case .inactive:
            result = result.filter { !$0.is_active }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { user in
                user.login.localizedCaseInsensitiveContains(query)
                || user.full_name.localizedCaseInsensitiveContains(query)
                || user.role_name.localizedCaseInsensitiveContains(query)
                || user.role_code.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    func loadUsers(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminUsersResponseDTO.self, from: data)
            users = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить пользователей: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createUser(
        api: SchoolAPI,
        login: String,
        password: String,
        fullName: String,
        roleCode: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "login": login,
                "password": password,
                "full_name": fullName,
                "role_code": roleCode
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users",
                method: "POST",
                body: body
            )

            successMessage = "Пользователь создан"
            await loadUsers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать пользователя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateUser(
        api: SchoolAPI,
        userID: Int,
        fullName: String,
        originalRoleCode: String,
        roleCode: String,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "full_name": fullName,
                "is_active": isActive
            ]

            let profileRoleCodes: Set<String> = ["teacher", "parent", "student"]

            // role_code отправляем только при реальной смене роли и только для ролей
            // общего раздела: роли учителя, родителя и ученика сервер отклоняет (400),
            // а повторная отправка роли admin менеджером тоже вызывает отказ.
            if roleCode != originalRoleCode,
               !profileRoleCodes.contains(roleCode),
               !profileRoleCodes.contains(originalRoleCode) {
                body["role_code"] = roleCode
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users/\(userID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Пользователь обновлён"
            await loadUsers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить пользователя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func resetPassword(
        api: SchoolAPI,
        userID: Int,
        newPassword: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "password": newPassword
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users/\(userID)/reset-password",
                method: "POST",
                body: body
            )

            successMessage = "Пароль сброшен"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сбросить пароль: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deactivateUser(
        api: SchoolAPI,
        userID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users/\(userID)",
                method: "DELETE"
            )

            successMessage = "Пользователь отключён"
            await loadUsers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отключить пользователя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AdminUsersError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminUsersError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminUsersError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminUsersError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminUsersError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminUsersError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Выйдите и войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            return APIRequestError.readableServerError(statusCode: statusCode, text: text)
        }
    }
}