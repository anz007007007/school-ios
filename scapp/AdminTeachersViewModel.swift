import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminTeachersViewModel: ObservableObject {
    @Published var teachers: [AdminTeacherDTO] = []
    @Published var classes: [AdminClassDTO] = []
    @Published var searchText = ""
    @Published var selectedFilter: TeacherFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum TeacherFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"

        var id: String {
            rawValue
        }
    }

    var filteredTeachers: [AdminTeacherDTO] {
        var result = teachers

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
            result = result.filter { teacher in
                teacher.login.localizedCaseInsensitiveContains(query)
                || teacher.full_name.localizedCaseInsensitiveContains(query)
                || teacher.assignmentsText.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    func loadTeachers(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/teachers",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminTeachersResponseDTO.self, from: data)
            teachers = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить учителей: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadClasses(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminClassesResponseDTO.self, from: data)
            classes = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить классы: \(error.localizedDescription)"
        }
    }

    func createTeacher(
        api: SchoolAPI,
        login: String,
        password: String,
        fullName: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "login": login,
                "password": password,
                "full_name": fullName
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/teachers",
                method: "POST",
                body: body
            )

            successMessage = "Учитель создан"
            await loadTeachers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать учителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateTeacher(
        api: SchoolAPI,
        teacherID: Int,
        fullName: String,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "full_name": fullName,
                "is_active": isActive
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/teachers/\(teacherID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Учитель обновлён"
            await loadTeachers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить учителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func attachClass(
        api: SchoolAPI,
        teacherID: Int,
        classID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "teacher_id": teacherID,
                "class_id": classID
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/teacher-classes",
                method: "POST",
                body: body
            )

            successMessage = "Класс привязан к учителю"
            await loadTeachers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось привязать класс: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func detachClass(
        api: SchoolAPI,
        teacherID: Int,
        classID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/teacher-classes",
                method: "DELETE",
                queryItems: [
                    URLQueryItem(name: "teacher_id", value: "\(teacherID)"),
                    URLQueryItem(name: "class_id", value: "\(classID)")
                ]
            )

            successMessage = "Класс отвязан от учителя"
            await loadTeachers(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отвязать класс: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AdminTeachersError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw AdminTeachersError.badURL
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
            throw AdminTeachersError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminTeachersError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminTeachersError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminTeachersError: LocalizedError {
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
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}
