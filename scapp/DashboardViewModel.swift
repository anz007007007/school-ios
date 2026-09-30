import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponseDTO?
    @Published var familyDashboard: FamilyDashboardResponseDTO?
    @Published var mobileConfig: MobileConfigResponseDTO?
    @Published var analytics: AnalyticsResponseDTO?
    @Published var diaryFilters: DiaryFiltersResponseDTO?

    @Published var parentStudents: [DashboardStudentDTO] = []
    @Published var selectedStudentID: Int = 0
    @Published var quarterGrades: [DashboardGradeDTO] = []
    @Published var calculatedGradesBySubjectID: [Int: DashboardCalculatedGrades] = [:]
    @Published var dashboardHomeworkIncompleteCount: Int?
    @Published var isLoadingStudentGrades = false

    @Published var isLoading = false
    @Published var hasLoadedInitialData = false
    @Published var errorMessage: String?

    private var loadGeneration = UUID()
    private var studentGradesTask: Task<Void, Never>?
    private var homeworkCountTask: Task<Void, Never>?
    private var calculatedGradesTask: Task<Void, Never>?

    deinit {
        studentGradesTask?.cancel()
        homeworkCountTask?.cancel()
        calculatedGradesTask?.cancel()
    }

    var birthdays: [DashboardBirthdayDTO] {
        dashboard?.birthdays ?? []
    }

    var todayBirthdays: [DashboardBirthdayDTO] {
        birthdays
            .filter { $0.status == "today" || $0.days_offset == 0 }
            .sorted { $0.displayName < $1.displayName }
    }

    var upcomingBirthdays: [DashboardBirthdayDTO] {
        birthdays
            .filter { $0.status == "upcoming" || $0.days_offset > 0 }
            .sorted {
                if $0.days_offset == $1.days_offset {
                    return $0.displayName < $1.displayName
                }

                return $0.days_offset < $1.days_offset
            }
    }

    var pastBirthdays: [DashboardBirthdayDTO] {
        birthdays
            .filter { $0.status == "past" || $0.days_offset < 0 }
            .sorted {
                if abs($0.days_offset) == abs($1.days_offset) {
                    return $0.displayName < $1.displayName
                }

                return abs($0.days_offset) < abs($1.days_offset)
            }
    }

    var displayTitle: String? {
        let rawTitle = familyDashboard?.title ?? dashboard?.title
        return localizedDashboardText(rawTitle)
    }

    var displaySubtitle: String? {
        if let selectedStudent {
            return selectedStudent.displayName
        }

        let rawSubtitle = familyDashboard?.subtitle ?? dashboard?.subtitle
        return localizedDashboardText(rawSubtitle)
    }

    var selectedStudent: DashboardStudentDTO? {
        parentStudents.first { $0.id == selectedStudentID }
    }

    var cards: [DashboardCardDTO] {
        let sourceCards: [DashboardCardDTO]

        if let familyDashboard, !familyDashboard.cards.isEmpty {
            sourceCards = familyDashboard.cards
        } else {
            sourceCards = dashboard?.cards ?? []
        }

        return sourceCards.filter { card in
            !isFinanceCard(card.label)
        }
    }

    var summaryCards: [DashboardSummaryCard] {
        var result = cards.compactMap { card -> DashboardSummaryCard? in
            let title = localizedDashboardText(card.label) ?? card.label

            guard !isHiddenDashboardSummaryCard(title) else {
                return nil
            }

            return DashboardSummaryCard(
                title: title,
                value: valueForSummaryCard(
                    title: title,
                    fallbackValue: card.value.displayText
                ),
                source: .server(card)
            )
        }

        result.insert(
            DashboardSummaryCard(
                title: "Расписание",
                value: "Уроки",
                source: .schedule
            ),
            at: 0
        )

        return result
    }

    var todayGrades: [DashboardGradeDTO] {
        let today = Self.dateFormatter.string(from: Date())

        return quarterGrades.filter { grade in
            grade.grade_date == today
        }
    }

    var subjectAverages: [DashboardSubjectAverageDTO] {
        let grouped = Dictionary(grouping: quarterGrades) { grade in
            grade.subject_id
        }

        let today = Self.dateFormatter.string(from: Date())

        return grouped.compactMap { subjectID, grades in
            guard let subjectName = grades.first?.subject_name else {
                return nil
            }

            let values = grades.compactMap { $0.numericValue }

            let average: Double?
            if values.isEmpty {
                average = nil
            } else {
                average = values.reduce(0, +) / Double(values.count)
            }

            let todayGrades = grades
                .filter { $0.grade_date == today }
                .sorted { $0.id < $1.id }
                .map(\.grade_value)

            let calculated = calculatedGradesBySubjectID[subjectID]

            return DashboardSubjectAverageDTO(
                subjectID: subjectID,
                subjectName: subjectName,
                gradesCount: grades.count,
                todayGradesText: todayGrades.isEmpty ? "—" : todayGrades.joined(separator: ", "),
                average: average,
                calculatedQuarterGrade: calculated?.quarter,
                calculatedYearGrade: calculated?.year
            )
        }
        .sorted { $0.subjectName < $1.subjectName }
    }

    var totalAverageText: String {
        let values = quarterGrades.compactMap { $0.numericValue }

        guard !values.isEmpty else {
            return "—"
        }

        let average = values.reduce(0, +) / Double(values.count)
        return String(format: "%.2f", average)
    }

    var currentQuarterTitle: String {
        if let currentTerm = diaryFilters?.current_term,
           currentTerm.isQuarter {
            return "\(currentTerm.name): \(currentTerm.starts_at) — \(currentTerm.ends_at)"
        }

        if let currentYear = diaryFilters?.current_year {
            return "\(currentYear.name): \(currentYear.starts_at) — \(currentYear.ends_at)"
        }

        return "текущий период"
    }

    func loadInitialData(
        api: SchoolAPI,
        isParent: Bool,
        isStudent: Bool,
        isAdmin: Bool
    ) async {
        guard !isLoading else {
            print("DASHBOARD LOAD SKIPPED: already loading")
            return
        }

        let generation = UUID()
        loadGeneration = generation
        studentGradesTask?.cancel()
        homeworkCountTask?.cancel()
        calculatedGradesTask?.cancel()

        isLoading = true
        errorMessage = nil

        defer {
            if loadGeneration == generation && !hasLoadedInitialData {
                isLoading = false
            }
        }

        async let mobileConfigTask: Void = loadMobileConfig(api: api)
        async let dashboardTask: Void = loadDashboard(api: api)
        async let analyticsTask: Void = isAdmin ? loadAnalytics(api: api) : ()

        _ = await (mobileConfigTask, dashboardTask, analyticsTask)

        guard loadGeneration == generation else {
            return
        }

        if isParent || isStudent {
            async let familyTask: Void = isParent ? loadFamilyDashboard(api: api) : ()
            async let filtersTask: Void = loadDiaryFilters(api: api)
            async let studentsTask: Void = loadParentStudents(api: api)

            _ = await (familyTask, filtersTask, studentsTask)

            guard loadGeneration == generation else {
                return
            }

            if selectedStudentID == 0 {
                selectedStudentID = parentStudents.first?.id
                    ?? familyDashboard?.students.first?.id
                    ?? diaryFilters?.students.first?.id
                    ?? 0
            }

            hasLoadedInitialData = true
            isLoading = false

            startStudentDependentLoading(
                api: api,
                generation: generation
            )
        } else {
            dashboardHomeworkIncompleteCount = nil
            quarterGrades = []
            calculatedGradesBySubjectID = [:]
            hasLoadedInitialData = true
            isLoading = false
        }
    }

    func selectStudent(api: SchoolAPI, studentID: Int) async {
        let generation = UUID()
        loadGeneration = generation
        studentGradesTask?.cancel()
        homeworkCountTask?.cancel()
        calculatedGradesTask?.cancel()

        selectedStudentID = studentID
        quarterGrades = []
        calculatedGradesBySubjectID = [:]
        dashboardHomeworkIncompleteCount = nil

        startStudentDependentLoading(
            api: api,
            generation: generation
        )
    }

    private func startStudentDependentLoading(
        api: SchoolAPI,
        generation: UUID
    ) {
        guard selectedStudentID != 0 else {
            quarterGrades = []
            calculatedGradesBySubjectID = [:]
            dashboardHomeworkIncompleteCount = nil
            return
        }

        let studentID = selectedStudentID

        studentGradesTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadQuarterGrades(
                api: api,
                studentID: studentID,
                generation: generation
            )
        }

        homeworkCountTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadDashboardHomeworkIncompleteCount(
                api: api,
                studentID: studentID,
                generation: generation
            )
        }
    }

    func loadDashboard(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/school-info/dashboard",
                method: "GET"
            )

            dashboard = try JSONDecoder().decode(DashboardResponseDTO.self, from: data)
            errorMessage = nil
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD LOAD CANCELLED")
                return
            }

            errorMessage = "Не удалось загрузить главную: \(error.localizedDescription)"
        }
    }

    func loadFamilyDashboard(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/school-info/family-dashboard",
                method: "GET"
            )

            familyDashboard = try JSONDecoder().decode(FamilyDashboardResponseDTO.self, from: data)
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD FAMILY LOAD CANCELLED")
                return
            }

            // Не блокируем главную, если семейный dashboard недоступен.
        }
    }

    func loadParentStudents(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(DashboardStudentsListResponseDTO.self, from: data)

            if !decoded.items.isEmpty {
                parentStudents = decoded.items
            } else {
                applyStudentsFallback()
            }
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD STUDENTS LOAD CANCELLED")
                return
            }

            applyStudentsFallback()
        }
    }

    func loadDiaryFilters(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/diary/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(DiaryFiltersResponseDTO.self, from: data)
            diaryFilters = decoded

            if selectedStudentID == 0,
               let firstStudent = decoded.students.first {
                selectedStudentID = firstStudent.id
            }

            if parentStudents.isEmpty {
                parentStudents = decoded.students.map { student in
                    DashboardStudentDTO(
                        id: student.id,
                        student_name: student.name,
                        full_name: nil,
                        first_name: nil,
                        last_name: nil,
                        middle_name: nil,
                        class_name: nil
                    )
                }
            }
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD DIARY FILTERS LOAD CANCELLED")
                return
            }

            // Не блокируем dashboard, если фильтры дневника временно недоступны.
        }
    }

    func loadQuarterGrades(api: SchoolAPI) async {
        let generation = loadGeneration

        if selectedStudentID == 0,
           let firstStudent = diaryFilters?.students.first {
            selectedStudentID = firstStudent.id
        }

        await loadQuarterGrades(
            api: api,
            studentID: selectedStudentID,
            generation: generation
        )
    }

    private func loadQuarterGrades(
        api: SchoolAPI,
        studentID: Int,
        generation: UUID
    ) async {
        guard studentID != 0 else {
            quarterGrades = []
            calculatedGradesBySubjectID = [:]
            return
        }

        isLoadingStudentGrades = true
        calculatedGradesBySubjectID = [:]

        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "student_id", value: "\(studentID)")
            ]

            if let currentTerm = diaryFilters?.current_term,
               currentTerm.isQuarter {
                queryItems.append(URLQueryItem(name: "date_from", value: currentTerm.starts_at))
                queryItems.append(URLQueryItem(name: "date_to", value: currentTerm.ends_at))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/diary/grades",
                method: "GET",
                queryItems: queryItems
            )

            guard loadGeneration == generation else {
                return
            }

            let decoded = try JSONDecoder().decode(DashboardGradesListResponseDTO.self, from: data)

            quarterGrades = decoded.items.filter { grade in
                grade.student_id == studentID
            }

            isLoadingStudentGrades = false

            startCalculatedGradesLoading(
                api: api,
                studentID: studentID,
                generation: generation
            )
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD QUARTER GRADES LOAD CANCELLED")
                return
            }

            guard loadGeneration == generation else {
                return
            }

            quarterGrades = []
            calculatedGradesBySubjectID = [:]
            isLoadingStudentGrades = false
        }
    }

    func loadDashboardHomeworkIncompleteCount(api: SchoolAPI) async {
        await loadDashboardHomeworkIncompleteCount(
            api: api,
            studentID: selectedStudentID,
            generation: loadGeneration
        )
    }

    private func loadDashboardHomeworkIncompleteCount(
        api: SchoolAPI,
        studentID: Int,
        generation: UUID
    ) async {
        guard studentID != 0 else {
            dashboardHomeworkIncompleteCount = nil
            return
        }

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/homework",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "student_id", value: "\(studentID)")
                ]
            )

            guard loadGeneration == generation else {
                return
            }

            let decoded = try JSONDecoder().decode(HomeworkListResponseDTO.self, from: data)

            dashboardHomeworkIncompleteCount = decoded.items.filter { item in
                !item.isCompleted
            }.count
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD HOMEWORK COUNT LOAD CANCELLED")
                return
            }

            guard loadGeneration == generation else {
                return
            }

            dashboardHomeworkIncompleteCount = nil
        }
    }

    func loadMobileConfig(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/school-info/mobile-config",
                method: "GET"
            )

            mobileConfig = try JSONDecoder().decode(MobileConfigResponseDTO.self, from: data)
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD MOBILE CONFIG LOAD CANCELLED")
                return
            }

            // Не блокируем главную, если конфиг не загрузился.
        }
    }

    func loadAnalytics(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/school-info/analytics",
                method: "GET"
            )

            analytics = try JSONDecoder().decode(AnalyticsResponseDTO.self, from: data)
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD ANALYTICS LOAD CANCELLED")
                return
            }

            // Не блокируем главную, если аналитика не загрузилась.
        }
    }

    func featureEnabled(_ code: String) -> Bool {
        guard let features = mobileConfig?.features else {
            return code != "finance" || mobileConfig?.user?.role_code != "student"
        }

        switch code {
        case "diary":
            return features.diary ?? true
        case "homework":
            return features.homework ?? true
        case "events":
            return features.events ?? true
        case "clubs":
            return features.clubs ?? true
        case "finance":
            return mobileConfig?.user?.role_code != "student"
                && (features.finance ?? true)
        case "messages":
            return features.messages ?? true
        case "analytics":
            return features.analytics ?? true
        default:
            return true
        }
    }

    // MARK: - Private Methods

    private func applyStudentsFallback() {
        if let familyDashboard, !familyDashboard.students.isEmpty {
            parentStudents = familyDashboard.students
            return
        }

        if let diaryFilters, !diaryFilters.students.isEmpty {
            parentStudents = diaryFilters.students.map { student in
                DashboardStudentDTO(
                    id: student.id,
                    student_name: student.name,
                    full_name: nil,
                    first_name: nil,
                    last_name: nil,
                    middle_name: nil,
                    class_name: nil
                )
            }
        }
    }

    private func valueForSummaryCard(
        title: String,
        fallbackValue: String
    ) -> String {
        if isHomeworkCard(title), let dashboardHomeworkIncompleteCount {
            return "\(dashboardHomeworkIncompleteCount)"
        }

        return fallbackValue
    }

    private func isHomeworkCard(_ title: String) -> Bool {
        let lower = title.lowercased()

        return lower.contains("дом")
            || lower.contains("задан")
            || lower.contains("дз")
            || lower.contains("homework")
            || lower.contains("assignment")
            || lower.contains("task")
    }

    private func isHiddenDashboardSummaryCard(_ title: String) -> Bool {
        let lower = title.lowercased()

        if lower.contains("оценки сегодня") {
            return true
        }

        if lower.contains("средний за четверть") {
            return true
        }

        if lower.contains("оценки за 14")
            || lower.contains("оценок за 14")
            || lower.contains("14 дней") {
            return true
        }

        return false
    }

    private func localizedDashboardText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.localizedCaseInsensitiveContains("dashboard") {
            return clean.replacingOccurrences(
                of: "dashboard",
                with: "Главная",
                options: [.caseInsensitive]
            )
        }

        return clean
    }

    private func isFinanceCard(_ title: String) -> Bool {
        let lower = title.lowercased()

        return lower.contains("финанс")
            || lower.contains("долг")
            || lower.contains("счёт")
            || lower.contains("счет")
            || lower.contains("плат")
            || lower.contains("проср")
            || lower.contains("оплач")
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        let description = error.localizedDescription.lowercased()

        return description.contains("cancel")
            || description.contains("отмен")
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw DashboardError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw DashboardError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        print("DASHBOARD REQUEST:", method, url.absoluteString)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            if isCancellationError(error) {
                throw CancellationError()
            }

            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DashboardError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("DASHBOARD RESPONSE STATUS:", httpResponse.statusCode, "BYTES:", data.count)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw DashboardError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DashboardError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private func startCalculatedGradesLoading(
        api: SchoolAPI,
        studentID: Int,
        generation: UUID
    ) {
        calculatedGradesTask?.cancel()

        let subjectIDs = Array(Set(quarterGrades.map { $0.subject_id }))
            .sorted()

        guard studentID != 0, !subjectIDs.isEmpty else {
            calculatedGradesBySubjectID = [:]
            return
        }

        calculatedGradesTask = Task { [weak self] in
            guard let self else {
                return
            }

            var result: [Int: DashboardCalculatedGrades] = [:]

            for chunk in subjectIDs.chunked(into: 3) {
                if Task.isCancelled {
                    return
                }

                await withTaskGroup(of: (Int, DashboardCalculatedGrades).self) { group in
                    for subjectID in chunk {
                        group.addTask { [weak self] in
                            guard let self else {
                                return (
                                    subjectID,
                                    DashboardCalculatedGrades(quarter: nil, year: nil)
                                )
                            }

                            async let quarterGrade = self.loadCalculatedPeriodGrade(
                                api: api,
                                studentID: studentID,
                                subjectID: subjectID,
                                periodType: "quarter"
                            )

                            async let yearGrade = self.loadCalculatedPeriodGrade(
                                api: api,
                                studentID: studentID,
                                subjectID: subjectID,
                                periodType: "year"
                            )

                            return (
                                subjectID,
                                DashboardCalculatedGrades(
                                    quarter: await quarterGrade,
                                    year: await yearGrade
                                )
                            )
                        }
                    }

                    for await item in group {
                        result[item.0] = item.1
                    }
                }

                await MainActor.run {
                    guard self.loadGeneration == generation else {
                        return
                    }

                    self.calculatedGradesBySubjectID = result
                }
            }
        }
    }

    private func loadCalculatedPeriodGrade(
        api: SchoolAPI,
        studentID: Int,
        subjectID: Int,
        periodType: String
    ) async -> GradeCalculatedPeriodResponseDTO? {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/mobile/grades/calculated-period-grade",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "student_id", value: "\(studentID)"),
                    URLQueryItem(name: "subject_id", value: "\(subjectID)"),
                    URLQueryItem(name: "period_type", value: periodType)
                ]
            )

            print("DASHBOARD CALCULATED GRADE SUCCESS:", periodType, "student:", studentID, "subject:", subjectID)

            return try JSONDecoder().decode(GradeCalculatedPeriodResponseDTO.self, from: data)
        } catch {
            if isCancellationError(error) {
                print("DASHBOARD CALCULATED GRADE LOAD CANCELLED")
                return nil
            }

            print("DASHBOARD CALCULATED GRADE LOAD ERROR:", error.localizedDescription)
            return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

// MARK: - Supporting Types

struct DashboardSummaryCard: Identifiable, Hashable {
    enum Source: Hashable {
        case server(DashboardCardDTO)
        case todayGrades
        case quarterAverage
        case schedule
    }

    let title: String
    let value: String
    let source: Source

    var id: String {
        switch source {
        case .server(let card):
            return "server-\(card.label)-\(card.value.displayText)"
        case .todayGrades:
            return "today-grades-\(title)-\(value)"
        case .quarterAverage:
            return "quarter-average-\(title)-\(value)"
        case .schedule:
            return "schedule-\(title)-\(value)"
        }
    }
}

struct DashboardCalculatedGrades: Hashable {
    let quarter: GradeCalculatedPeriodResponseDTO?
    let year: GradeCalculatedPeriodResponseDTO?
}

enum DashboardSummaryTarget {
    case diary
    case homework
    case messages
    case events
    case clubs
    case finance
    case health
    case schedule
    case documents
    case menu
    case textbooks
    case portfolio
    case teacher
    case analytics
    case admin
    case unsupported
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        return stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}

enum DashboardError: LocalizedError {
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
            }

            return "Ошибка сервера: \(statusCode). \(text)"
        }
    }
}