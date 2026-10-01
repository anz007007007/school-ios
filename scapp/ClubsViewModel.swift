import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class ClubsViewModel: ObservableObject {
    @Published var clubs: [ClubDTO] = []
    @Published var filterStudents: [ClubFilterStudentDTO] = []
    @Published var filterTeachers: [ClubFilterTeacherDTO] = []

    @Published var clubStudents: [Int: [ClubStudentDTO]] = [:]

    @Published var selectedWeekday: WeekdayFilter = .all
    @Published var selectedTeacherID: Int = 0
    @Published var selectedStudentID: Int = 0
    @Published var selectedStatus: ClubStatusFilter = .all
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isLoadingClubStudents = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var clubStudentsTask: Task<Void, Never>?
    private var clubStudentsRequestID = 0

    enum WeekdayFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case monday = "Пн"
        case tuesday = "Вт"
        case wednesday = "Ср"
        case thursday = "Чт"
        case friday = "Пт"
        case saturday = "Сб"
        case sunday = "Вс"

        var id: String {
            rawValue
        }

        var value: Int? {
            switch self {
            case .all:
                return nil
            case .monday:
                return 1
            case .tuesday:
                return 2
            case .wednesday:
                return 3
            case .thursday:
                return 4
            case .friday:
                return 5
            case .saturday:
                return 6
            case .sunday:
                return 7
            }
        }
    }

    enum ClubStatusFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case draft = "Черновики"
        case archived = "Архив"

        var id: String {
            rawValue
        }

        var apiValue: String? {
            switch self {
            case .all:
                return nil
            case .active:
                return "active"
            case .draft:
                return "draft"
            case .archived:
                return "archived"
            }
        }
    }

    struct ClubDayGroup: Identifiable, Hashable {
        let weekday: Int
        let clubs: [ClubDTO]

        var id: Int {
            weekday
        }
    }

    struct ClubConflictGroup: Identifiable, Hashable {
        let key: String
        let clubs: [ClubDTO]

        var id: String {
            key
        }
    }

    var filteredClubs: [ClubDTO] {
        var result = clubs

        if let weekday = selectedWeekday.value {
            result = result.filter { $0.weekday == weekday }
        }

        if selectedTeacherID != 0 {
            if let teacher = filterTeachers.first(where: { $0.id == selectedTeacherID }) {
                result = result.filter {
                    $0.teacher_name.localizedCaseInsensitiveContains(teacher.teacher_name)
                }
            }
        }

        if let status = selectedStatus.apiValue {
            result = result.filter { $0.status == status }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { club in
                club.name.localizedCaseInsensitiveContains(query)
                || (club.description ?? "").localizedCaseInsensitiveContains(query)
                || club.teacher_name.localizedCaseInsensitiveContains(query)
                || club.status.localizedCaseInsensitiveContains(query)
                || club.start_time.localizedCaseInsensitiveContains(query)
                || club.end_time.localizedCaseInsensitiveContains(query)
                || (club.payment_type ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.weekday == $1.weekday {
                return $0.start_time < $1.start_time
            }

            return $0.weekday < $1.weekday
        }
    }

    var groupedByDay: [ClubDayGroup] {
        let grouped = Dictionary(grouping: filteredClubs) { $0.weekday }

        return grouped.map { weekday, clubs in
            ClubDayGroup(
                weekday: weekday,
                clubs: clubs.sorted { $0.start_time < $1.start_time }
            )
        }
        .sorted { $0.weekday < $1.weekday }
    }

    var timeConflicts: [ClubConflictGroup] {
        let grouped = Dictionary(grouping: filteredClubs) { club in
            "\(club.weekday)-\(club.start_time)-\(club.end_time)"
        }

        return grouped
            .filter { _, clubs in
                clubs.count > 1
            }
            .map { key, clubs in
                ClubConflictGroup(
                    key: key,
                    clubs: clubs.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.key < $1.key }
    }

    var totalEnrolled: Int {
        filteredClubs.reduce(0) { $0 + $1.enrolled_count }
    }

    var activeCount: Int {
        filteredClubs.filter { $0.status == "active" }.count
    }

    var fullCount: Int {
        filteredClubs.filter { $0.isFull }.count
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let clubsTask: Void = loadClubs(api: api, showLoading: false)

        _ = await (filtersTask, clubsTask)

        isLoading = false
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(ClubFiltersDTO.self, from: data)
            filterStudents = decoded.students
            filterTeachers = decoded.teachers
        } catch {
            errorMessage = "Не удалось загрузить фильтры: \(error.localizedDescription)"
        }

        isLoadingFilters = false
    }

    func loadClubs(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if let weekday = selectedWeekday.value {
                queryItems.append(URLQueryItem(name: "weekday", value: "\(weekday)"))
            }

            if selectedTeacherID != 0 {
                queryItems.append(URLQueryItem(name: "teacher_id", value: "\(selectedTeacherID)"))
            }

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if let status = selectedStatus.apiValue {
                queryItems.append(URLQueryItem(name: "status_filter", value: status))
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: query))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/clubs",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(ClubsListResponseDTO.self, from: data)
            clubs = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить кружки: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        await loadClubs(api: api)
    }

    func createClub(
        api: SchoolAPI,
        formData: ClubFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanStartTime = formData.startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEndTime = formData.endTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPriceAmount = formData.priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Введите название кружка"
            isSaving = false
            return false
        }

        guard !formData.weekdayIDs.isEmpty else {
            errorMessage = "Выберите хотя бы один день недели"
            isSaving = false
            return false
        }

        guard formData.teacherID != 0 else {
            errorMessage = "Выберите преподавателя"
            isSaving = false
            return false
        }

        guard !cleanStartTime.isEmpty, !cleanEndTime.isEmpty else {
            errorMessage = "Укажите время начала и окончания"
            isSaving = false
            return false
        }

        do {
            for weekday in formData.weekdayIDs {
                let body = clubRequestBody(
                    name: cleanName,
                    description: cleanDescription,
                    weekday: weekday,
                    startTime: cleanStartTime,
                    endTime: cleanEndTime,
                    capacity: formData.capacity,
                    priceAmount: cleanPriceAmount,
                    paymentType: formData.paymentType,
                    teacherID: formData.teacherID,
                    status: formData.status
                )

                _ = try await sendRequest(
                    api: api,
                    path: "/api/v1/clubs",
                    method: "POST",
                    body: body
                )
            }

            successMessage = formData.weekdayIDs.count > 1
                ? "Кружки добавлены"
                : "Кружок добавлен"

            await loadClubs(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить кружок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateClub(
        api: SchoolAPI,
        clubID: Int,
        formData: ClubFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanStartTime = formData.startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEndTime = formData.endTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPriceAmount = formData.priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Введите название кружка"
            isSaving = false
            return false
        }

        guard let weekday = formData.weekdayIDs.first else {
            errorMessage = "Выберите день недели"
            isSaving = false
            return false
        }

        guard formData.teacherID != 0 else {
            errorMessage = "Выберите преподавателя"
            isSaving = false
            return false
        }

        guard !cleanStartTime.isEmpty, !cleanEndTime.isEmpty else {
            errorMessage = "Укажите время начала и окончания"
            isSaving = false
            return false
        }

        do {
            let body = clubRequestBody(
                name: cleanName,
                description: cleanDescription,
                weekday: weekday,
                startTime: cleanStartTime,
                endTime: cleanEndTime,
                capacity: formData.capacity,
                priceAmount: cleanPriceAmount,
                paymentType: formData.paymentType,
                teacherID: formData.teacherID,
                status: formData.status
            )

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)",
                method: "PUT",
                body: body
            )

            successMessage = "Кружок обновлён"

            await loadClubs(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить кружок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteClub(
        api: SchoolAPI,
        club: ClubDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(club.id)",
                method: "DELETE"
            )

            clubs.removeAll { $0.id == club.id }
            clubStudents[club.id] = nil
            successMessage = "Кружок удалён"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить кружок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Admin club students

    func studentsForClub(_ clubID: Int) -> [ClubStudentDTO] {
        clubStudents[clubID, default: []]
            .sorted { $0.student_name < $1.student_name }
    }

    func availableStudentsForClub(_ clubID: Int) -> [ClubFilterStudentDTO] {
        let enrolledIDs = Set(studentsForClub(clubID).map { $0.student_id })

        return filterStudents
            .filter { !enrolledIDs.contains($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    func loadClubStudents(
        api: SchoolAPI,
        clubID: Int
    ) async {
        // Новая загрузка отменяет предыдущую: ответ старого запроса не перепишет список.
        clubStudentsTask?.cancel()
        clubStudentsRequestID += 1
        let requestID = clubStudentsRequestID

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.performLoadClubStudents(api: api, clubID: clubID, requestID: requestID)
        }
        clubStudentsTask = task
        await task.value
    }

    private func performLoadClubStudents(
        api: SchoolAPI,
        clubID: Int,
        requestID: Int
    ) async {
        isLoadingClubStudents = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(ClubStudentsListResponseDTO.self, from: data)

            guard !Task.isCancelled, requestID == clubStudentsRequestID else {
                return
            }

            clubStudents[clubID] = decoded.items
        } catch {
            guard !Task.isCancelled, requestID == clubStudentsRequestID else {
                return
            }

            if (error as? URLError)?.code == .cancelled {
                isLoadingClubStudents = false
                return
            }

            errorMessage = "Не удалось загрузить учеников кружка: \(error.localizedDescription)"
        }

        isLoadingClubStudents = false
    }

    func addStudentToClub(
        api: SchoolAPI,
        clubID: Int,
        formData: ClubStudentFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students",
                method: "POST",
                body: [
                    "student_id": formData.studentID,
                    "enrollment_status": formData.enrollmentStatus
                ]
            )

            successMessage = "Ученик добавлен в кружок"

            await loadClubStudents(api: api, clubID: clubID)
            await loadClubs(api: api, showLoading: false)
            await loadFilters(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить ученика в кружок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateClubStudentStatus(
        api: SchoolAPI,
        clubID: Int,
        studentID: Int,
        enrollmentStatus: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students/\(studentID)",
                method: "PUT",
                body: [
                    "enrollment_status": enrollmentStatus
                ]
            )

            successMessage = "Статус ученика обновлён"

            await loadClubStudents(api: api, clubID: clubID)
            await loadClubs(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить статус ученика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func removeStudentFromClub(
        api: SchoolAPI,
        clubID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students/\(studentID)",
                method: "DELETE"
            )

            successMessage = "Ученик удалён из кружка"

            await loadClubStudents(api: api, clubID: clubID)
            await loadClubs(api: api, showLoading: false)
            await loadFilters(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить ученика из кружка: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Self enroll

    func enrollToClub(
        api: SchoolAPI,
        clubID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard studentID != 0 else {
            errorMessage = "Выберите ученика для записи"
            isSaving = false
            return false
        }

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students",
                method: "POST",
                body: [
                    "student_id": studentID,
                    "enrollment_status": "active"
                ]
            )

            let decoded = try? JSONDecoder().decode(ClubEnrollStatusResponseDTO.self, from: data)

            if decoded?.status == "already_enrolled" {
                successMessage = "Ребёнок уже записан в этот кружок"
            } else {
                successMessage = "Ребёнок записан в кружок"
            }

            await loadClubStudents(api: api, clubID: clubID)
            await loadClubs(api: api, showLoading: false)
            await loadFilters(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось записать ребёнка в кружок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    // MARK: - Self unenroll (parent)

    func unenrollFromClub(
        api: SchoolAPI,
        clubID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard studentID != 0 else {
            errorMessage = "Выберите ученика для выписки"
            isSaving = false
            return false
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/clubs/\(clubID)/students/\(studentID)",
                method: "DELETE"
            )

            successMessage = "Ребёнок выписан из кружка"

            await loadClubStudents(api: api, clubID: clubID)
            await loadClubs(api: api, showLoading: false)
            await loadFilters(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось выписать ребёнка из кружка: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func clubRequestBody(
        name: String,
        description: String,
        weekday: Int,
        startTime: String,
        endTime: String,
        capacity: Int,
        priceAmount: String,
        paymentType: String,
        teacherID: Int,
        status: String
    ) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "weekday": weekday,
            "start_time": startTime,
            "end_time": endTime,
            "capacity": capacity,
            "price_amount": priceAmount.isEmpty ? "0" : priceAmount,
            "price_period": Self.normalizedPricePeriod(paymentType) ?? "free",
            "teacher_id": teacherID,
            "status": status
        ]
    }

    func weekdayTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1:
            return "Понедельник"
        case 2:
            return "Вторник"
        case 3:
            return "Среда"
        case 4:
            return "Четверг"
        case 5:
            return "Пятница"
        case 6:
            return "Суббота"
        case 7:
            return "Воскресенье"
        default:
            return "День \(weekday)"
        }
    }

    func shortWeekdayTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1:
            return "Пн"
        case 2:
            return "Вт"
        case 3:
            return "Ср"
        case 4:
            return "Чт"
        case 5:
            return "Пт"
        case 6:
            return "Сб"
        case 7:
            return "Вс"
        default:
            return "\(weekday)"
        }
    }

    func statusTitle(_ status: String) -> String {
        switch status {
        case "active":
            return "Активен"
        case "draft":
            return "Черновик"
        case "archived":
            return "Архив"
        default:
            return "Статус не указан"
        }
    }

    /// Статусы записи в кружок (schemas/education.py ClubEnrollmentCreateRequest).
    static let enrollmentStatusOptions: [(title: String, value: String)] = [
        ("Записан", "active"),
        ("Ожидание", "waiting"),
        ("Пауза", "paused"),
        ("Выбыл", "left")
    ]

    func enrollmentStatusTitle(_ status: String) -> String {
        switch status {
        case "active":
            return "Записан"
        case "waiting", "pending":
            return "Ожидание"
        case "paused":
            return "Пауза"
        case "left":
            return "Выбыл"
        default:
            return "Статус не указан"
        }
    }

    /// Варианты оплаты сервера: free | lesson | hour | month | course.
    static let pricePeriodOptions: [(title: String, value: String)] = [
        ("Бесплатно", "free"),
        ("За занятие", "lesson"),
        ("За час", "hour"),
        ("В месяц", "month"),
        ("За курс", "course")
    ]

    /// Приводит код оплаты к серверному (старые коды приложения тоже понимаем).
    static func normalizedPricePeriod(_ value: String?) -> String? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "free":
            return "free"
        case "lesson", "per_lesson":
            return "lesson"
        case "hour", "per_hour":
            return "hour"
        case "month", "monthly":
            return "month"
        case "course", "term", "one_time":
            return "course"
        default:
            return nil
        }
    }

    func paymentTypeTitle(_ value: String?) -> String {
        guard let code = Self.normalizedPricePeriod(value) else {
            return "Не указан"
        }

        return Self.pricePeriodOptions.first { $0.value == code }?.title ?? "Не указан"
    }

    func teacherID(for club: ClubDTO) -> Int {
        if let teacherID = club.teacher_id,
           filterTeachers.contains(where: { $0.id == teacherID }) {
            return teacherID
        }

        return filterTeachers.first {
            club.teacher_name.localizedCaseInsensitiveContains($0.teacher_name)
            || $0.teacher_name.localizedCaseInsensitiveContains(club.teacher_name)
        }?.id ?? 0
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw ClubsError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw ClubsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            #if DEBUG
            print("CLUBS REQUEST:", method, url.absoluteString)
            print("CLUBS BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("CLUBS REQUEST:", method, url.absoluteString)
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClubsError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("CLUBS RESPONSE STATUS:", httpResponse.statusCode)
        print("CLUBS RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw ClubsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClubsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

enum ClubsError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный адрес запроса."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            return APIRequestError.serverError(statusCode: statusCode, text: text).errorDescription
        }
    }
}