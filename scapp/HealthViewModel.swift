import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var cards: [HealthCardDTO] = []
    @Published var students: [HealthStudentFilterDTO] = []
    @Published var overview: HealthOverviewResponseDTO?

    @Published var selectedStudentID: Int = 0
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var filteredCards: [HealthCardDTO] {
        var result = cards

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { card in
                card.student_name.localizedCaseInsensitiveContains(query)
                || (card.class_name ?? "").localizedCaseInsensitiveContains(query)
                || (card.blood_type ?? "").localizedCaseInsensitiveContains(query)
                || (card.health_group ?? "").localizedCaseInsensitiveContains(query)
                || (card.physical_activity_group ?? "").localizedCaseInsensitiveContains(query)
                || (card.allergies ?? "").localizedCaseInsensitiveContains(query)
                || (card.chronic_diseases ?? "").localizedCaseInsensitiveContains(query)
                || (card.contraindications ?? "").localizedCaseInsensitiveContains(query)
                || (card.food_recommendations ?? "").localizedCaseInsensitiveContains(query)
                || (card.health_recommendations ?? "").localizedCaseInsensitiveContains(query)
                || (card.medication_notes ?? "").localizedCaseInsensitiveContains(query)
                || (card.daily_regimen ?? "").localizedCaseInsensitiveContains(query)
                || (card.emergency_contact ?? "").localizedCaseInsensitiveContains(query)
                || (card.doctor_contacts ?? "").localizedCaseInsensitiveContains(query)
                || (card.risk_level ?? "").localizedCaseInsensitiveContains(query)
                || (card.physical_restrictions ?? "").localizedCaseInsensitiveContains(query)
                || (card.effectiveVaccinationNotes ?? "").localizedCaseInsensitiveContains(query)
                || (card.effectiveNotes ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted { $0.student_name < $1.student_name }
    }

    var allergiesCount: Int {
        overview?.allergies_count ?? cards.filter { $0.hasAllergies }.count
    }

    var chronicDiseasesCount: Int {
        overview?.chronic_diseases_count ?? cards.filter { $0.hasChronicDiseases }.count
    }

    var importantCount: Int {
        cards.filter { $0.hasImportantNotes }.count
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let overviewTask: Void = loadOverview(api: api)
        async let cardsTask: Void = loadCards(api: api, showLoading: false)

        _ = await (filtersTask, overviewTask, cardsTask)

        isLoading = false
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/health/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(HealthFiltersResponseDTO.self, from: data)
            students = decoded.students
        } catch {
            errorMessage = "Не удалось загрузить фильтры здоровья: \(error.localizedDescription)"
        }

        isLoadingFilters = false
    }

    func loadOverview(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/health/overview",
                method: "GET"
            )

            overview = try JSONDecoder().decode(HealthOverviewResponseDTO.self, from: data)
        } catch {
            // Не блокируем экран, если обзор не загрузился.
        }
    }

    func loadCards(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/health/cards",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(HealthCardsListResponseDTO.self, from: data)
            cards = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить медкарты: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        await loadCards(api: api)
    }

    func loadCard(
        api: SchoolAPI,
        studentID: Int
    ) async -> HealthCardDTO? {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/health/cards/\(studentID)",
                method: "GET"
            )

            return try JSONDecoder().decode(HealthCardDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить медкарту: \(error.localizedDescription)"
            return nil
        }
    }

    func saveCard(
        api: SchoolAPI,
        formData: HealthCardFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "student_id": formData.studentID,

                "blood_type": cleanOptional(formData.bloodType) as Any,
                "health_group": cleanOptional(formData.healthGroup) as Any,
                "physical_activity_group": cleanOptional(formData.physicalActivityGroup) as Any,

                "allergies": cleanOptional(formData.allergies) as Any,
                "contraindications": cleanOptional(formData.contraindications) as Any,
                "chronic_diseases": cleanOptional(formData.chronicDiseases) as Any,

                "food_recommendations": cleanOptional(formData.foodRecommendations) as Any,
                "health_recommendations": cleanOptional(formData.healthRecommendations) as Any,
                "medication_notes": cleanOptional(formData.medicationNotes) as Any,
                "daily_regimen": cleanOptional(formData.dailyRegimen) as Any,

                "emergency_contact": cleanOptional(formData.emergencyContact) as Any,
                "doctor_contacts": cleanOptional(formData.doctorContacts) as Any,

                "risk_level": cleanOptional(formData.riskLevel) as Any,
                "physical_restrictions": cleanOptional(formData.physicalRestrictions) as Any,
                "vaccination_notes": cleanOptional(formData.vaccinationNotes) as Any,
                "last_checkup_at": cleanOptional(formData.lastCheckupAt) as Any,
                "notes": cleanOptional(formData.notes) as Any
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/health/cards/\(formData.studentID)",
                method: "PUT",
                body: body
            )

            successMessage = "Медкарта сохранена"

            await loadCards(api: api, showLoading: false)
            await loadOverview(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить медкарту: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func studentName(for id: Int) -> String {
        students.first { $0.id == id }?.student_name ?? "Ученик \(id)"
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw HealthError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw HealthError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("HEALTH REQUEST:", method, url.absoluteString)
            print("HEALTH BODY:", body)
        } else {
            print("HEALTH REQUEST:", method, url.absoluteString)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HealthError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("HEALTH RESPONSE STATUS:", httpResponse.statusCode)
        print("HEALTH RESPONSE BODY:", responseText)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HealthError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

enum HealthError: LocalizedError {
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

            if let readable = Self.readableDetail(from: text) {
                return readable
            }

            return "Ошибка сервера: \(statusCode). \(text)"
        }
    }

    private static func readableDetail(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] as? String else {
            return nil
        }

        switch detail {
        case "Student is not attached to this parent":
            return "Этот ученик не привязан к вашему профилю."
        case "Permission denied":
            return "Нет прав на просмотр или редактирование медкарты."
        default:
            return detail
        }
    }
}