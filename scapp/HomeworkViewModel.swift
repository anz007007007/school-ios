import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class HomeworkViewModel: ObservableObject {
    @Published var items: [HomeworkDTO] = []
    @Published var filterStudents: [HomeworkStudentFilterDTO] = []
    @Published var filterSubjects: [HomeworkSubjectFilterDTO] = []
    @Published var classes: [AdminClassDTO] = []

    @Published var selectedScope: HomeworkScope = .all
    @Published var selectedSubjectID: Int = 0
    @Published var selectedStudentID: Int = 0
    @Published var searchText = ""

    @Published var scopeBadgeCounts: [HomeworkScope: Int] = [:]

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isSaving = false
    @Published var updatingCompletionIDs: Set<Int> = []
    @Published var hasLoadedInitialData = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var loadGeneration = UUID()
    private var scopeBadgeCountsTask: Task<Void, Never>?

    deinit {
        scopeBadgeCountsTask?.cancel()
    }

    enum HomeworkScope: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case tomorrow = "Завтра"
        case week = "Неделя"
        case overdue = "Просрочено"
        case all = "Все"

        var id: String {
            rawValue
        }

        var apiValue: String? {
            switch self {
            case .today:
                return "today"
            case .tomorrow:
                return "tomorrow"
            case .week:
                return "week"
            case .overdue:
                return "overdue"
            case .all:
                return nil
            }
        }
    }

    struct HomeworkSubjectStat: Identifiable, Hashable {
        let subjectID: Int
        let subjectName: String
        let count: Int

        var id: Int {
            subjectID
        }
    }

    struct HomeworkDateGroup: Identifiable, Hashable {
        let date: String
        let items: [HomeworkDTO]

        var id: String {
            date
        }
    }

    var subjects: [HomeworkSubjectFilterDTO] {
        if !filterSubjects.isEmpty {
            return filterSubjects.sorted { $0.name < $1.name }
        }

        let pairs = items.map { ($0.subject_id, $0.subject_name) }
        var seen = Set<Int>()
        var result: [HomeworkSubjectFilterDTO] = []

        for pair in pairs {
            if !seen.contains(pair.0) {
                seen.insert(pair.0)
                result.append(
                    HomeworkSubjectFilterDTO(
                        id: pair.0,
                        name: pair.1
                    )
                )
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    var students: [HomeworkStudentFilterDTO] {
        filterStudents.sorted { $0.student_name < $1.student_name }
    }

    var filteredItems: [HomeworkDTO] {
        var result = items

        // Фильтр "Просрочено" — показываем только невыполненные просроченные задания.
        if selectedScope == .overdue {
            result = result.filter { item in
                !item.isCompleted && isOverdue(item.due_date)
            }
        }

        if selectedSubjectID != 0 {
            result = result.filter { $0.subject_id == selectedSubjectID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || item.description.localizedCaseInsensitiveContains(query)
                || item.subject_name.localizedCaseInsensitiveContains(query)
                || item.class_name.localizedCaseInsensitiveContains(query)
                || item.due_date.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            let lhsDate = dateForSorting($0.due_date)
            let rhsDate = dateForSorting($1.due_date)

            if lhsDate == rhsDate {
                if $0.subject_name == $1.subject_name {
                    return $0.id > $1.id
                }

                return $0.subject_name < $1.subject_name
            }

            return lhsDate > rhsDate
        }
    }

    var groupedByDate: [HomeworkDateGroup] {
        let grouped = Dictionary(grouping: filteredItems) { $0.due_date }

        return grouped.map { date, items in
            HomeworkDateGroup(
                date: date,
                items: items.sorted {
                    let lhsDate = dateForSorting($0.due_date)
                    let rhsDate = dateForSorting($1.due_date)

                    if lhsDate == rhsDate {
                        if $0.subject_name == $1.subject_name {
                            return $0.id > $1.id
                        }

                        return $0.subject_name < $1.subject_name
                    }

                    return lhsDate > rhsDate
                }
            )
        }
        .sorted {
            dateForSorting($0.date) > dateForSorting($1.date)
        }
    }

    var subjectStats: [HomeworkSubjectStat] {
        let grouped = Dictionary(grouping: filteredItems) { $0.subject_id }

        return grouped.compactMap { subjectID, items in
            guard let subjectName = items.first?.subject_name else {
                return nil
            }

            return HomeworkSubjectStat(
                subjectID: subjectID,
                subjectName: subjectName,
                count: items.count
            )
        }
        .sorted { $0.subjectName < $1.subjectName }
    }

    var todayCount: Int {
        filteredItems.filter { isToday($0.due_date) }.count
    }

    var overdueCount: Int {
        filteredItems.filter { item in
            !item.isCompleted && isOverdue(item.due_date)
        }.count
    }

    func badgeCount(for scope: HomeworkScope) -> Int {
        scopeBadgeCounts[scope] ?? 0
    }

    func loadInitialData(api: SchoolAPI) async {
        let generation = UUID()
        loadGeneration = generation
        scopeBadgeCountsTask?.cancel()

        isLoading = true
        errorMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let classesTask: Void = loadClasses(api: api)

        _ = await (filtersTask, classesTask)

        guard loadGeneration == generation else {
            return
        }

        restoreOrSelectDefaultStudent()
        await loadHomework(api: api, showLoading: false)

        guard loadGeneration == generation else {
            return
        }

        hasLoadedInitialData = true
        isLoading = false
        startScopeBadgeCountsLoading(api: api, generation: generation)
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/homework/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(HomeworkFiltersDTO.self, from: data)
            filterStudents = decoded.students
            filterSubjects = decoded.subjects
        } catch {
            errorMessage = "Не удалось загрузить фильтры: \(error.localizedDescription)"
        }

        isLoadingFilters = false
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
            // Не блокируем экран, если классы не загрузились.
        }
    }

    func loadHomework(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        guard selectedStudentID != 0 else {
            items = []
            errorMessage = nil
            successMessage = nil
            scopeBadgeCounts = [:]
            hasLoadedInitialData = true
            return
        }

        if showLoading {
            isLoading = true
        }

        errorMessage = nil
        successMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if let scope = selectedScope.apiValue {
                queryItems.append(URLQueryItem(name: "scope", value: scope))
            }

            queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))

            if selectedSubjectID != 0 {
                queryItems.append(URLQueryItem(name: "subject_id", value: "\(selectedSubjectID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/homework",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(HomeworkListResponseDTO.self, from: data)
            items = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить домашние задания: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadScopeBadgeCounts(api: SchoolAPI) async {
        guard selectedStudentID != 0 else {
            scopeBadgeCounts = [:]
            return
        }

        let studentID = selectedStudentID
        let subjectID = selectedSubjectID
        let previousErrorMessage = errorMessage

        let nextCounts = await fetchScopeBadgeCounts(
            api: api,
            studentID: studentID,
            subjectID: subjectID
        )

        scopeBadgeCounts = nextCounts

        if errorMessage == nil {
            errorMessage = previousErrorMessage
        }
    }

    private func startScopeBadgeCountsLoading(
        api: SchoolAPI,
        generation: UUID
    ) {
        guard selectedStudentID != 0 else {
            scopeBadgeCounts = [:]
            return
        }

        let studentID = selectedStudentID
        let subjectID = selectedSubjectID
        let previousErrorMessage = errorMessage

        scopeBadgeCountsTask?.cancel()
        scopeBadgeCountsTask = Task { [weak self] in
            guard let self else {
                return
            }

            let nextCounts = await self.fetchScopeBadgeCounts(
                api: api,
                studentID: studentID,
                subjectID: subjectID
            )

            await MainActor.run {
                guard self.loadGeneration == generation else {
                    return
                }

                self.scopeBadgeCounts = nextCounts

                if self.errorMessage == nil {
                    self.errorMessage = previousErrorMessage
                }
            }
        }
    }

    private func fetchScopeBadgeCounts(
        api: SchoolAPI,
        studentID: Int,
        subjectID: Int
    ) async -> [HomeworkScope: Int] {
        await withTaskGroup(of: (HomeworkScope, Int?).self) { group in
            for scope in HomeworkScope.allCases {
                group.addTask { [weak self] in
                    guard let self else {
                        return (scope, nil)
                    }

                    do {
                        var queryItems: [URLQueryItem] = []

                        if let apiValue = scope.apiValue {
                            queryItems.append(URLQueryItem(name: "scope", value: apiValue))
                        }

                        queryItems.append(URLQueryItem(name: "student_id", value: "\(studentID)"))

                        if subjectID != 0 {
                            queryItems.append(URLQueryItem(name: "subject_id", value: "\(subjectID)"))
                        }

                        let data = try await self.sendRequest(
                            api: api,
                            path: "/api/v1/homework",
                            method: "GET",
                            queryItems: queryItems
                        )

                        let decoded = try JSONDecoder().decode(HomeworkListResponseDTO.self, from: data)

                        let count = await self.incompleteCount(
                            for: decoded.items,
                            scope: scope
                        )

                        return (scope, count)
                    } catch {
                        return (scope, nil)
                    }
                }
            }

            var result: [HomeworkScope: Int] = [:]

            for await item in group {
                if let count = item.1 {
                    result[item.0] = count
                }
            }

            return result
        }
    }

    private func incompleteCount(
        for items: [HomeworkDTO],
        scope: HomeworkScope
    ) -> Int {
        if scope == .overdue {
            return items.filter { item in
                !item.isCompleted && isOverdue(item.due_date)
            }.count
        }

        return items.filter { item in
            !item.isCompleted
        }.count
    }

    func createHomework(
        api: SchoolAPI,
        formData: HomeworkFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "class_id": formData.classID,
                "subject_id": formData.subjectID,
                "title": formData.title,
                "description": formData.description,
                "due_date": formData.dueDate
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/homework",
                method: "POST",
                body: body
            )

            successMessage = "Домашнее задание создано"
            await loadHomework(api: api)
            await loadScopeBadgeCounts(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать домашнее задание: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteHomework(
        api: SchoolAPI,
        homeworkID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/homework/\(homeworkID)",
                method: "DELETE"
            )

            successMessage = "Домашнее задание удалено"
            await loadHomework(api: api)
            await loadScopeBadgeCounts(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить домашнее задание: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateCompletion(
        api: SchoolAPI,
        homework: HomeworkDTO,
        studentID: Int,
        isCompleted: Bool
    ) async -> Bool {
        guard studentID != 0 else {
            errorMessage = "Выберите ученика, чтобы отметить выполнение."
            return false
        }

        updatingCompletionIDs.insert(homework.id)
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "student_id": studentID,
                "is_completed": isCompleted
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/homework/\(homework.id)/completion",
                method: "PATCH",
                body: body
            )

            updateLocalCompletion(
                homeworkID: homework.id,
                studentID: studentID,
                isCompleted: isCompleted
            )

            updateScopeBadgeCountsLocally(
                homework: homework,
                isCompleted: isCompleted
            )

            successMessage = isCompleted ? "Домашка отмечена выполненной" : "Отметка выполнения снята"
            updatingCompletionIDs.remove(homework.id)

            let generation = loadGeneration
            startScopeBadgeCountsLoading(api: api, generation: generation)

            return true
        } catch {
            errorMessage = "Не удалось обновить выполнение: \(error.localizedDescription)"
            updatingCompletionIDs.remove(homework.id)
            return false
        }
    }

    private func updateLocalCompletion(
        homeworkID: Int,
        studentID: Int,
        isCompleted: Bool
    ) {
        items = items.map { item in
            guard item.id == homeworkID else {
                return item
            }

            return homeworkWithUpdatedCompletion(
                item,
                studentID: item.student_id ?? studentID,
                isCompleted: isCompleted
            )
        }
    }

    private func homeworkWithUpdatedCompletion(
        _ item: HomeworkDTO,
        studentID: Int?,
        isCompleted: Bool
    ) -> HomeworkDTO {
        HomeworkDTO(
            id: item.id,
            title: item.title,
            description: item.description,
            due_date: item.due_date,
            class_id: item.class_id,
            subject_id: item.subject_id,
            class_name: item.class_name,
            subject_name: item.subject_name,
            teacher_name: item.teacher_name,
            due_status: item.due_status,
            days_left: item.days_left,
            student_id: item.student_id ?? studentID,
            is_completed: isCompleted,
            completed_at: isCompleted ? (item.completed_at ?? "") : nil,
            completed_by_user_id: item.completed_by_user_id,
            completion_status: isCompleted ? "completed" : "not_completed"
        )
    }

    private func updateScopeBadgeCountsLocally(
        homework: HomeworkDTO,
        isCompleted: Bool
    ) {
        let oldCompleted = homework.isCompleted

        guard oldCompleted != isCompleted else {
            return
        }

        let delta = isCompleted ? -1 : 1

        func applyDelta(_ scope: HomeworkScope) {
            let current = scopeBadgeCounts[scope] ?? 0
            scopeBadgeCounts[scope] = max(0, current + delta)
        }

        applyDelta(.all)

        if isToday(homework.due_date) {
            applyDelta(.today)
        }

        if let date = parseHomeworkDate(homework.due_date),
           Calendar.current.isDateInTomorrow(date) {
            applyDelta(.tomorrow)
        }

        if isOverdue(homework.due_date) {
            applyDelta(.overdue)
        }

        if isInCurrentWeek(homework.due_date) {
            applyDelta(.week)
        }
    }

    private func isInCurrentWeek(_ dateString: String) -> Bool {
        guard let date = parseHomeworkDate(dateString),
              let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return false
        }

        return date >= week.start && date < week.end
    }

    func selectStudent(
        api: SchoolAPI,
        studentID: Int
    ) async {
        let generation = UUID()
        loadGeneration = generation
        scopeBadgeCountsTask?.cancel()

        guard studentID != 0 else {
            selectedStudentID = 0
            items = []
            scopeBadgeCounts = [:]
            errorMessage = nil
            successMessage = nil
            return
        }

        selectedStudentID = studentID
        saveSelectedStudentID(studentID)

        items = []
        scopeBadgeCounts = [:]

        await loadHomework(api: api)

        guard loadGeneration == generation else {
            return
        }

        startScopeBadgeCountsLoading(api: api, generation: generation)
    }

    private func restoreOrSelectDefaultStudent() {
        let availableStudentIDs = Set(students.map(\.id))

        if selectedStudentID != 0, availableStudentIDs.contains(selectedStudentID) {
            saveSelectedStudentID(selectedStudentID)
            return
        }

        let savedStudentID = UserDefaults.standard.integer(forKey: Self.selectedStudentIDStorageKey)

        if savedStudentID != 0, availableStudentIDs.contains(savedStudentID) {
            selectedStudentID = savedStudentID
            return
        }

        selectedStudentID = students.first?.id ?? 0

        if selectedStudentID != 0 {
            saveSelectedStudentID(selectedStudentID)
        }
    }

    private func saveSelectedStudentID(_ studentID: Int) {
        UserDefaults.standard.set(studentID, forKey: Self.selectedStudentIDStorageKey)
    }

    func reloadForFilters(api: SchoolAPI) async {
        let generation = UUID()
        loadGeneration = generation
        scopeBadgeCountsTask?.cancel()

        await loadHomework(api: api)

        guard loadGeneration == generation else {
            return
        }

        startScopeBadgeCountsLoading(api: api, generation: generation)
    }

    func dateTitle(_ dateString: String) -> String {
        guard let date = parseHomeworkDate(dateString) else {
            return dateString
        }

        let formattedDate = AppDateFormatter.date(dateString)

        if Calendar.current.isDateInToday(date) {
            return "Сегодня · \(formattedDate)"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Завтра · \(formattedDate)"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера · \(formattedDate)"
        }

        return "\(Self.displayDateFormatter.string(from: date)) · \(formattedDate)"
    }

    func isToday(_ dateString: String) -> Bool {
        guard let date = parseHomeworkDate(dateString) else {
            return false
        }

        return Calendar.current.isDateInToday(date)
    }

    func isOverdue(_ dateString: String) -> Bool {
        guard let date = parseHomeworkDate(dateString) else {
            return false
        }

        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)

        return target < today
    }

    func isHomeworkOverdue(_ homework: HomeworkDTO) -> Bool {
        !homework.isCompleted && isOverdue(homework.due_date)
    }

    func deadlineStatusTitle(_ dateString: String) -> String {
        if isOverdue(dateString) {
            return "Просрочено"
        }

        if isToday(dateString) {
            return "На сегодня"
        }

        guard let date = parseHomeworkDate(dateString) else {
            return "Срок"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "На завтра"
        }

        return "Предстоит"
    }

    private func dateForSorting(_ value: String) -> Date {
        parseHomeworkDate(value) ?? Date.distantPast
    }

    private func parseHomeworkDate(_ value: String) -> Date? {
        if let date = Self.dateFormatter.date(from: value) {
            return date
        }

        for formatter in Self.fallbackDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw HomeworkError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw HomeworkError.badURL
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
            throw HomeworkError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw HomeworkError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw HomeworkError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }

    private static let selectedStudentIDStorageKey = "homework_selected_student_id"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "dd.MM.yyyy",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

enum HomeworkError: LocalizedError {
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
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}