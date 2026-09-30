import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminTermsViewModel: ObservableObject {
    @Published var terms: [AdminTermDTO] = []
    @Published var searchText = ""
    @Published var selectedFilter: TermFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum TermFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"

        var id: String {
            rawValue
        }
    }

    var filteredTerms: [AdminTermDTO] {
        var result = terms

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
            result = result.filter { term in
                term.name.localizedCaseInsensitiveContains(query)
                || term.academic_year.localizedCaseInsensitiveContains(query)
                || term.term_type.localizedCaseInsensitiveContains(query)
                || term.starts_at.localizedCaseInsensitiveContains(query)
                || term.ends_at.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.academic_year == $1.academic_year {
                return $0.starts_at < $1.starts_at
            }

            return $0.academic_year > $1.academic_year
        }
    }

    func loadTerms(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/terms",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminTermsResponseDTO.self, from: data)
            terms = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить периоды: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createTerm(
        api: SchoolAPI,
        name: String,
        academicYear: String,
        termType: String,
        startsAt: String,
        endsAt: String,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "name": name,
                "academic_year": academicYear,
                "term_type": termType,
                "starts_at": startsAt,
                "ends_at": endsAt,
                "is_active": isActive
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/terms",
                method: "POST",
                body: body
            )

            successMessage = "Период создан"
            await loadTerms(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать период: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateTerm(
        api: SchoolAPI,
        termID: Int,
        name: String,
        academicYear: String,
        termType: String,
        startsAt: String,
        endsAt: String,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "name": name,
                "academic_year": academicYear,
                "term_type": termType,
                "starts_at": startsAt,
                "ends_at": endsAt,
                "is_active": isActive
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/terms/\(termID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Период обновлён"
            await loadTerms(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить период: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteTerm(
        api: SchoolAPI,
        termID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/terms/\(termID)",
                method: "DELETE"
            )

            successMessage = "Период удалён"
            await loadTerms(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить период: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func termTypeTitle(_ value: String) -> String {
        switch value {
        case "quarter":
            return "Четверть"
        case "trimester":
            return "Триместр"
        case "semester":
            return "Семестр"
        case "year":
            return "Год"
        default:
            return value
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AdminTermsError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminTermsError.badURL
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
            throw AdminTermsError.badResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminTermsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminTermsError: LocalizedError {
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
