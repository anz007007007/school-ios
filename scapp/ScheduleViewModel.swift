import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var lessons: [ScheduleLessonDTO] = []
    @Published var students: [ScheduleStudentDTO] = []

    @Published var selectedWeekday: WeekdayFilter = .defaultSchoolDay
    @Published var selectedStudentID: Int = 0
    @Published var selectedClassID: Int = 0
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingStudents = false
    @Published var errorMessage: String?

    private var scheduleLoadTask: Task<[ScheduleLessonDTO], Error>?
    private var scheduleLoadGeneration = UUID()

    enum WeekdayFilter: String, CaseIterable, Identifiable {
        case monday = "Пн"
        case tuesday = "Вт"
        case wednesday = "Ср"
        case thursday = "Чт"
        case friday = "Пт"
        case saturday = "Сб"
        case sunday = "Вс"
        case all = "Все"

        var id: String {
            rawValue
        }

        var value: Int? {
            switch self {
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
            case .all:
                return nil
            }
        }

        static var defaultSchoolDay: WeekdayFilter {
            let weekday = Calendar.current.component(.weekday, from: Date())

            // Apple Calendar:
            // Sunday = 1, Monday = 2, Tuesday = 3, Wednesday = 4,
            // Thursday = 5, Friday = 6, Saturday = 7.
            switch weekday {
            case 2:
                return .monday
            case 3:
                return .tuesday
            case 4:
                return .wednesday
            case 5:
                return .thursday
            case 6:
                return .friday
            case 1, 7:
                return .monday
            default:
                return .monday
            }
        }
    }

    struct ScheduleDayGroup: Identifiable, Hashable {
        let weekday: Int
        let lessons: [ScheduleLessonDTO]

        var id: Int {
            weekday
        }
    }

    var availableClasses: [(id: Int, title: String)] {
        let pairs = students.compactMap { student -> (Int, String)? in
            guard let classID = student.class_id else {
                return nil
            }

            return (classID, student.class_name ?? "Класс \(classID)")
        }

        var seen = Set<Int>()
        var result: [(id: Int, title: String)] = []

        for pair in pairs {
            if !seen.contains(pair.0) {
                seen.insert(pair.0)
                result.append((id: pair.0, title: pair.1))
            }
        }

        return result.sorted { $0.title < $1.title }
    }

    var filteredLessons: [ScheduleLessonDTO] {
        var result = lessons

        if let weekday = selectedWeekday.value {
            result = result.filter { $0.weekday == weekday }
        }

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        if selectedClassID != 0 {
            result = result.filter { $0.class_id == selectedClassID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { lesson in
                lesson.class_name.localizedCaseInsensitiveContains(query)
                || lesson.subject_name.localizedCaseInsensitiveContains(query)
                || (lesson.teacher_name ?? "").localizedCaseInsensitiveContains(query)
                || (lesson.student_name ?? "").localizedCaseInsensitiveContains(query)
                || (lesson.room ?? "").localizedCaseInsensitiveContains(query)
                || (lesson.note ?? "").localizedCaseInsensitiveContains(query)
                || lesson.starts_at.localizedCaseInsensitiveContains(query)
                || lesson.ends_at.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.weekday != $1.weekday {
                return $0.weekday < $1.weekday
            }

            if $0.lesson_number != $1.lesson_number {
                return $0.lesson_number < $1.lesson_number
            }

            if $0.starts_at != $1.starts_at {
                return $0.starts_at < $1.starts_at
            }

            if $0.class_name != $1.class_name {
                return $0.class_name < $1.class_name
            }

            if $0.subject_name != $1.subject_name {
                return $0.subject_name < $1.subject_name
            }

            return ($0.student_name ?? "") < ($1.student_name ?? "")
        }
    }

    var groupedByDay: [ScheduleDayGroup] {
        let grouped = Dictionary(grouping: filteredLessons) { $0.weekday }

        return grouped.map { weekday, lessons in
            ScheduleDayGroup(
                weekday: weekday,
                lessons: lessons.sorted {
                    if $0.lesson_number != $1.lesson_number {
                        return $0.lesson_number < $1.lesson_number
                    }

                    if $0.starts_at != $1.starts_at {
                        return $0.starts_at < $1.starts_at
                    }

                    if $0.class_name != $1.class_name {
                        return $0.class_name < $1.class_name
                    }

                    if $0.subject_name != $1.subject_name {
                        return $0.subject_name < $1.subject_name
                    }

                    return ($0.student_name ?? "") < ($1.student_name ?? "")
                }
            )
        }
        .sorted { $0.weekday < $1.weekday }
    }

    var subjectsCount: Int {
        Set(filteredLessons.map { $0.subject_id }).count
    }

    var classesCount: Int {
        Set(filteredLessons.map { $0.class_id }).count
    }

    var studentsCount: Int {
        Set(filteredLessons.compactMap { $0.student_id }).count
    }

    func loadInitialData(
        api: SchoolAPI,
        teacherOnly: Bool = false
    ) async {
        isLoading = true
        errorMessage = nil

        if teacherOnly {
            await loadSchedule(
                api: api,
                teacherOnly: true,
                showLoading: false
            )
        } else {
            await loadStudents(api: api)
            selectDefaultStudentIfNeeded()

            await loadSchedule(
                api: api,
                teacherOnly: false,
                showLoading: false
            )
        }

        isLoading = false
    }

    func loadStudents(api: SchoolAPI) async {
        isLoadingStudents = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/schedule/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(ScheduleStudentsResponseDTO.self, from: data)

            var seenStudentIDs = Set<Int>()

            students = decoded.students
                .filter { student in
                    if seenStudentIDs.contains(student.id) {
                        return false
                    }

                    seenStudentIDs.insert(student.id)
                    return true
                }
                // Как в дневнике и на главной — по имени, чтобы по умолчанию был выбран тот же ребёнок.
                .sorted {
                    $0.student_name.localizedCaseInsensitiveCompare($1.student_name) == .orderedAscending
                }

            selectDefaultStudentIfNeeded()
        } catch {
            print("SCHEDULE STUDENTS LOAD ERROR:", error.localizedDescription)
            // Не блокируем расписание, если фильтр учеников не загрузился.
        }

        isLoadingStudents = false
    }

    func loadSchedule(
        api: SchoolAPI,
        teacherOnly: Bool = false,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        // Прошлая загрузка отменяется; её ответ (для другого ребёнка) не применяется.
        scheduleLoadTask?.cancel()
        let generation = UUID()
        scheduleLoadGeneration = generation

        if !teacherOnly {
            selectDefaultStudentIfNeeded()
        }

        let studentID = selectedStudentID

        let task = Task { [weak self] () throws -> [ScheduleLessonDTO] in
            guard let self else {
                throw CancellationError()
            }

            if teacherOnly {
                return try await self.fetchTeacherSchedule(api: api)
            }

            return try await self.fetchGeneralSchedule(api: api, studentID: studentID)
        }

        scheduleLoadTask = task

        let result = await task.result

        guard scheduleLoadGeneration == generation else {
            return
        }

        switch result {
        case .success(let loadedLessons):
            if teacherOnly {
                selectedStudentID = 0
                selectedClassID = 0
                students = []
            }

            lessons = loadedLessons
        case .failure(let error):
            if !Self.isCancellation(error) {
                errorMessage = "Не удалось загрузить расписание: \(readableScheduleError(error))"
            }
        }

        if showLoading {
            isLoading = false
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSURLErrorCancelled
    }

    private func fetchGeneralSchedule(api: SchoolAPI, studentID: Int) async throws -> [ScheduleLessonDTO] {

        var queryItems: [URLQueryItem] = []

        if studentID != 0 {
            queryItems.append(URLQueryItem(name: "student_id", value: "\(studentID)"))
        }

        let data = try await sendRequest(
            api: api,
            path: "/api/v1/schedule",
            method: "GET",
            queryItems: queryItems
        )

        let decoded = try JSONDecoder().decode(ScheduleListResponseDTO.self, from: data)
        return deduplicatedLessons(decoded.items)
    }

    private func fetchTeacherSchedule(api: SchoolAPI) async throws -> [ScheduleLessonDTO] {
        let data = try await sendRequest(
            api: api,
            path: "/api/v1/teacher/schedule",
            method: "GET"
        )

        let decoded = try JSONDecoder().decode(TeacherScheduleResponseDTO.self, from: data)

        return deduplicatedLessons(
            decoded.items.map { item in
                ScheduleLessonDTO(
                    id: item.id,
                    class_id: item.class_id ?? 0,
                    subject_id: item.subject_id ?? 0,
                    teacher_id: nil,
                    weekday: item.weekday ?? 0,
                    lesson_number: item.lesson_number ?? 0,
                    starts_at: item.starts_at ?? "",
                    ends_at: item.ends_at ?? "",
                    room: item.room,
                    note: nil,
                    class_name: item.class_name ?? "Класс",
                    subject_name: item.subject_name ?? "Предмет",
                    teacher_name: nil,
                    student_id: nil,
                    student_name: nil
                )
            }
        )
    }

    private func deduplicatedLessons(_ items: [ScheduleLessonDTO]) -> [ScheduleLessonDTO] {
        var seenKeys = Set<String>()
        var result: [ScheduleLessonDTO] = []

        for item in items {
            // studentId входит в ключ: у двух детей из одного класса одинаковые уроки,
            // и без него они сливались в один.
            let key = [
                "\(item.student_id ?? 0)",
                "\(item.class_id)",
                item.class_name.trimmingCharacters(in: .whitespacesAndNewlines),
                "\(item.subject_id)",
                item.subject_name.trimmingCharacters(in: .whitespacesAndNewlines),
                "\(item.teacher_id ?? 0)",
                item.teacher_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                "\(item.weekday)",
                "\(item.lesson_number)",
                item.starts_at,
                item.ends_at,
                item.room?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ]
            .joined(separator: "|")

            guard !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            result.append(item)
        }

        return result.sorted {
            if $0.weekday != $1.weekday {
                return $0.weekday < $1.weekday
            }

            if $0.lesson_number != $1.lesson_number {
                return $0.lesson_number < $1.lesson_number
            }

            if $0.starts_at != $1.starts_at {
                return $0.starts_at < $1.starts_at
            }

            if $0.class_name != $1.class_name {
                return $0.class_name < $1.class_name
            }

            return $0.subject_name < $1.subject_name
        }
    }

    func reloadForFilters(
        api: SchoolAPI,
        teacherOnly: Bool = false
    ) async {
        await loadSchedule(
            api: api,
            teacherOnly: teacherOnly
        )
    }

    func resetFilters(
        api: SchoolAPI,
        teacherOnly: Bool = false
    ) async {
        selectedWeekday = .defaultSchoolDay
        selectedClassID = 0
        searchText = ""

        if !teacherOnly {
            selectDefaultStudentIfNeeded()
        } else {
            selectedStudentID = 0
        }

        await loadSchedule(
            api: api,
            teacherOnly: teacherOnly
        )
    }

    private func selectDefaultStudentIfNeeded() {
        guard !students.isEmpty else {
            selectedStudentID = 0
            return
        }

        if selectedStudentID == 0
            || !students.contains(where: { $0.id == selectedStudentID }) {
            selectedStudentID = students.first?.id ?? 0
        }
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

    private func readableScheduleError(_ error: Error) -> String {
        if let scheduleError = error as? ScheduleError {
            return scheduleError.errorDescription ?? error.localizedDescription
        }

        return error.localizedDescription
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw ScheduleError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw ScheduleError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        #if DEBUG
        print("SCHEDULE REQUEST:", method, url.absoluteString)
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScheduleError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("SCHEDULE RESPONSE STATUS:", httpResponse.statusCode)
        print("SCHEDULE RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw ScheduleError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ScheduleError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

enum ScheduleError: LocalizedError {
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
            return Self.readableServerError(statusCode: statusCode, text: text)
        }
    }

    private static func readableServerError(statusCode: Int, text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if statusCode == 401 {
            return readableDetail(from: cleanText)
                ?? "Сессия истекла. Войдите снова."
        }

        if statusCode == 403 {
            return readableDetail(from: cleanText)
                ?? "Нет доступа к расписанию."
        }

        if statusCode == 404 {
            return "Раздел расписания пока недоступен."
        }

        if statusCode >= 500 {
            return "Ошибка сервера. Попробуйте позже."
        }

        return readableDetail(from: cleanText)
            ?? (cleanText.isEmpty ? "Ошибка сервера: \(statusCode)" : "Ошибка сервера: \(statusCode). \(cleanText)")
    }

    private static func readableDetail(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] as? String else {
            return nil
        }

        switch detail {
        case "Authorization header is required":
            return "Нет токена авторизации. Войдите снова."
        case "Invalid token":
            return "Сессия истекла. Войдите снова."
        case "You do not have access to schedule":
            return "У вас нет доступа к расписанию."
        default:
            return detail
        }
    }
}