import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminSubjectsViewModel: ObservableObject {
    @Published var subjects: [AdminSubjectDTO] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var filteredSubjects: [AdminSubjectDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return subjects
        }

        return subjects.filter { subject in
            subject.name.localizedCaseInsensitiveContains(query)
        }
    }

    func loadSubjects(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/subjects",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminSubjectsResponseDTO.self, from: data)
            subjects = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить предметы: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createSubject(
        api: SchoolAPI,
        name: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "name": name
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/subjects",
                method: "POST",
                body: body
            )

            successMessage = "Предмет создан"
            await loadSubjects(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать предмет: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateSubject(
        api: SchoolAPI,
        subjectID: Int,
        name: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "name": name
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/subjects/\(subjectID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Предмет обновлён"
            await loadSubjects(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить предмет: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteSubject(
        api: SchoolAPI,
        subjectID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/subjects/\(subjectID)",
                method: "DELETE"
            )

            successMessage = "Предмет удалён"
            await loadSubjects(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить предмет: \(error.localizedDescription)"
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
            throw AdminSubjectsError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminSubjectsError.badURL
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
            throw AdminSubjectsError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminSubjectsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminSubjectsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminSubjectsError: LocalizedError {
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
