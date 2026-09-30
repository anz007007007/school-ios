import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var dashboard: AnalyticsDashboardDTO?
    @Published var overview: AnalyticsOverviewDTO?
    @Published var students: AnalyticsStudentsDTO?
    @Published var teachers: AnalyticsTeachersDTO?
    @Published var parents: AnalyticsParentsDTO?
    @Published var engagement: AnalyticsEngagementDTO?
    @Published var finance: AnalyticsFinanceDTO?
    @Published var health: AnalyticsHealthDTO?
    @Published var communications: AnalyticsCommunicationDTO?

    @Published var selectedSection: AnalyticsSection = .overview
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    enum AnalyticsSection: String, CaseIterable, Identifiable {
        case overview = "Обзор"
        case students = "Ученики"
        case teachers = "Учителя"
        case parents = "Родители"
        case engagement = "Активность"
        case finance = "Финансы"
        case health = "Здоровье"
        case communications = "Коммуникации"

        var id: String {
            rawValue
        }

        var systemImage: String {
            switch self {
            case .overview:
                return "chart.pie.fill"
            case .students:
                return "graduationcap.fill"
            case .teachers:
                return "person.text.rectangle.fill"
            case .parents:
                return "figure.2.and.child.holdinghands"
            case .engagement:
                return "sparkline"
            case .finance:
                return "creditcard.fill"
            case .health:
                return "heart.text.square.fill"
            case .communications:
                return "bubble.left.and.bubble.right.fill"
            }
        }
    }

    var overviewMetrics: [AnalyticsMetricDTO] {
        dashboard?.overview?.metrics ?? overview?.metrics ?? []
    }

    var studentsMetrics: [AnalyticsMetricDTO] {
        dashboard?.students?.metrics ?? students?.metrics ?? []
    }

    var teachersSummary: [AnalyticsMetricDTO] {
        dashboard?.teachers?.summary ?? teachers?.summary ?? []
    }

    var parentsMetrics: [AnalyticsMetricDTO] {
        dashboard?.parents?.metrics ?? parents?.metrics ?? []
    }

    var engagementMetrics: [AnalyticsMetricDTO] {
        dashboard?.engagement?.metrics ?? engagement?.metrics ?? []
    }

    var financeMetrics: [AnalyticsMetricDTO] {
        dashboard?.finance?.metrics ?? finance?.metrics ?? []
    }

    var healthMetrics: [AnalyticsMetricDTO] {
        dashboard?.health?.metrics ?? health?.metrics ?? []
    }

    var communicationMetrics: [AnalyticsMetricDTO] {
        dashboard?.communications?.metrics ?? communications?.metrics ?? []
    }

    var filteredStudentPerformance: [AnalyticsStudentPerformanceItemDTO] {
        let items = dashboard?.students?.performance ?? students?.performance ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
            || ($0.class_name ?? "").localizedCaseInsensitiveContains(query)
            || ($0.risk_level ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var filteredTeachers: [AnalyticsTeacherItemDTO] {
        let items = dashboard?.teachers?.items ?? teachers?.items ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredDebtors: [AnalyticsDebtorDTO] {
        let items = dashboard?.finance?.debtors ?? finance?.debtors ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
            || ($0.class_name ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    func loadAll(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/analytics/dashboard",
                method: "GET"
            )

            dashboard = try JSONDecoder().decode(AnalyticsDashboardDTO.self, from: data)
        } catch {
            print("ANALYTICS DASHBOARD LOAD ERROR:", error.localizedDescription)
            await loadSectionsFallback(api: api)
        }

        isLoading = false
    }

    private func loadSectionsFallback(api: SchoolAPI) async {
        async let overviewTask: Void = loadOverview(api: api)
        async let studentsTask: Void = loadStudents(api: api)
        async let teachersTask: Void = loadTeachers(api: api)
        async let parentsTask: Void = loadParents(api: api)
        async let engagementTask: Void = loadEngagement(api: api)
        async let financeTask: Void = loadFinance(api: api)
        async let healthTask: Void = loadHealth(api: api)
        async let communicationsTask: Void = loadCommunications(api: api)

        _ = await (
            overviewTask,
            studentsTask,
            teachersTask,
            parentsTask,
            engagementTask,
            financeTask,
            healthTask,
            communicationsTask
        )

        if overview == nil
            && students == nil
            && teachers == nil
            && parents == nil
            && engagement == nil
            && finance == nil
            && health == nil
            && communications == nil {
            errorMessage = "Не удалось загрузить аналитику."
        }
    }

    func loadSection(api: SchoolAPI) async {
        switch selectedSection {
        case .overview:
            await loadOverview(api: api)
        case .students:
            await loadStudents(api: api)
        case .teachers:
            await loadTeachers(api: api)
        case .parents:
            await loadParents(api: api)
        case .engagement:
            await loadEngagement(api: api)
        case .finance:
            await loadFinance(api: api)
        case .health:
            await loadHealth(api: api)
        case .communications:
            await loadCommunications(api: api)
        }
    }

    private func loadOverview(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/overview", method: "GET")
            overview = try JSONDecoder().decode(AnalyticsOverviewDTO.self, from: data)
        } catch {
            print("ANALYTICS OVERVIEW LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadStudents(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/students", method: "GET")
            students = try JSONDecoder().decode(AnalyticsStudentsDTO.self, from: data)
        } catch {
            print("ANALYTICS STUDENTS LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadTeachers(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/teachers", method: "GET")
            teachers = try JSONDecoder().decode(AnalyticsTeachersDTO.self, from: data)
        } catch {
            print("ANALYTICS TEACHERS LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadParents(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/parents", method: "GET")
            parents = try JSONDecoder().decode(AnalyticsParentsDTO.self, from: data)
        } catch {
            print("ANALYTICS PARENTS LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadEngagement(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/engagement", method: "GET")
            engagement = try JSONDecoder().decode(AnalyticsEngagementDTO.self, from: data)
        } catch {
            print("ANALYTICS ENGAGEMENT LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadFinance(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/finance", method: "GET")
            finance = try JSONDecoder().decode(AnalyticsFinanceDTO.self, from: data)
        } catch {
            print("ANALYTICS FINANCE LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadHealth(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/health", method: "GET")
            health = try JSONDecoder().decode(AnalyticsHealthDTO.self, from: data)
        } catch {
            print("ANALYTICS HEALTH LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadCommunications(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(api: api, path: "/api/v1/analytics/communications", method: "GET")
            communications = try JSONDecoder().decode(AnalyticsCommunicationDTO.self, from: data)
        } catch {
            print("ANALYTICS COMMUNICATIONS LOAD ERROR:", error.localizedDescription)
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AnalyticsError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AnalyticsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalyticsError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AnalyticsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AnalyticsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AnalyticsError: LocalizedError {
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