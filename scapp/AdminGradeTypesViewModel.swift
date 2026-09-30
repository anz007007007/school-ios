import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminGradeTypesViewModel: ObservableObject {
    @Published var items: [AdminGradeTypeDTO] = []
    @Published var searchText = ""
    @Published var selectedFilter: GradeTypeFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum GradeTypeFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"

        var id: String {
            rawValue
        }
    }

    var filteredItems: [AdminGradeTypeDTO] {
        var result = items

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
            result = result.filter { item in
                item.code.localizedCaseInsensitiveContains(query)
                || item.name.localizedCaseInsensitiveContains(query)
                || (item.description ?? "").localizedCaseInsensitiveContains(query)
                || (item.weight ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.sort_order ?? Int.max, $0.name) < ($1.sort_order ?? Int.max, $1.name)
        }
    }

    func loadItems(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/dictionaries/grade-types",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminGradeTypesResponseDTO.self, from: data)
            items = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить типы оценок: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createItem(
        api: SchoolAPI,
        formData: AdminGradeTypeFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "code": formData.code,
                "name": formData.name,
                "description": formData.description,
                "weight": formData.weight,
                "is_active": formData.isActive,
                "sort_order": formData.sortOrder
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/dictionaries/grade-types",
                method: "POST",
                body: body
            )

            successMessage = "Тип оценки создан"
            await loadItems(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать тип оценки: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateItem(
        api: SchoolAPI,
        code: String,
        formData: AdminGradeTypeFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "name": formData.name,
                "description": formData.description,
                "weight": formData.weight,
                "is_active": formData.isActive,
                "sort_order": formData.sortOrder,
                "clear_description": formData.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/dictionaries/grade-types/\(code)",
                method: "PATCH",
                body: body
            )

            successMessage = "Тип оценки обновлён"
            await loadItems(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить тип оценки: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deactivateItem(
        api: SchoolAPI,
        code: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/dictionaries/grade-types/\(code)",
                method: "DELETE"
            )

            successMessage = "Тип оценки отключён"
            await loadItems(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отключить тип оценки: \(error.localizedDescription)"
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
            throw AdminGradeTypesError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminGradeTypesError.badURL
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
            throw AdminGradeTypesError.badResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminGradeTypesError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminGradeTypesError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            }

            return "Ошибка сервера: \(statusCode). \(text)"
        }
    }
}