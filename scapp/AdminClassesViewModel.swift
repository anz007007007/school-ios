import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminClassesViewModel: ObservableObject {
    @Published var classes: [AdminClassDTO] = []
    @Published var teachers: [AdminTeacherDTO] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var filteredClasses: [AdminClassDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return classes
        }

        return classes.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
            || item.education_level.localizedCaseInsensitiveContains(query)
            || item.academic_year.localizedCaseInsensitiveContains(query)
            || item.curatorText.localizedCaseInsensitiveContains(query)
        }
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let classesTask: Void = loadClasses(api: api, showLoading: false)
        async let teachersTask: Void = loadTeachers(api: api)

        _ = await (classesTask, teachersTask)

        isLoading = false
    }

    func loadClasses(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil
        successMessage = nil

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

        if showLoading {
            isLoading = false
        }
    }

    func loadTeachers(api: SchoolAPI) async {
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
    }

    func createClass(
        api: SchoolAPI,
        name: String,
        educationLevel: String,
        academicYear: String,
        curatorTeacherID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "name": name,
                "education_level": educationLevel,
                "academic_year": academicYear
            ]

            if curatorTeacherID != 0 {
                body["curator_teacher_id"] = curatorTeacherID
            } else {
                body["curator_teacher_id"] = NSNull()
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes",
                method: "POST",
                body: body
            )

            successMessage = "Класс создан"
            await loadClasses(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать класс: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateClass(
        api: SchoolAPI,
        classID: Int,
        name: String,
        educationLevel: String,
        academicYear: String,
        curatorTeacherID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "name": name,
                "education_level": educationLevel,
                "academic_year": academicYear
            ]

            if curatorTeacherID != 0 {
                body["curator_teacher_id"] = curatorTeacherID
            } else {
                body["curator_teacher_id"] = NSNull()
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes/\(classID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Класс обновлён"
            await loadClasses(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить класс: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteClass(
        api: SchoolAPI,
        classID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes/\(classID)",
                method: "DELETE"
            )

            successMessage = "Класс удалён"
            await loadClasses(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить класс: \(error.localizedDescription)"
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
            throw AdminClassesError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminClassesError.badURL
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
            throw AdminClassesError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminClassesError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminClassesError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminClassesError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Сессия истекла. Войдите снова."
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