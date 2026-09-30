import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminScheduleViewModel: ObservableObject {
    @Published var lessons: [AdminScheduleLessonDTO] = []
    @Published var classes: [AdminClassDTO] = []
    @Published var subjects: [AdminSubjectDTO] = []
    @Published var teachers: [AdminTeacherDTO] = []
    @Published var selectedWeekday: WeekdayFilter = .all
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

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

    var filteredLessons: [AdminScheduleLessonDTO] {
        var result = lessons

        if let weekday = selectedWeekday.value {
            result = result.filter { $0.weekday == weekday }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { lesson in
                lesson.class_name.localizedCaseInsensitiveContains(query)
                || lesson.subject_name.localizedCaseInsensitiveContains(query)
                || lesson.starts_at.localizedCaseInsensitiveContains(query)
                || lesson.ends_at.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.weekday == $1.weekday {
                return $0.lesson_number < $1.lesson_number
            }

            return $0.weekday < $1.weekday
        }
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let lessonsTask: Void = loadLessons(api: api, showLoading: false)
        async let classesTask: Void = loadClasses(api: api)
        async let subjectsTask: Void = loadSubjects(api: api)
        async let teachersTask: Void = loadTeachers(api: api)

        _ = await (lessonsTask, classesTask, subjectsTask, teachersTask)

        isLoading = false
    }

    func loadLessons(api: SchoolAPI, showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/schedule",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminScheduleResponseDTO.self, from: data)
            lessons = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить расписание: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
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
            errorMessage = "Не удалось загрузить классы: \(error.localizedDescription)"
        }
    }

    func loadSubjects(api: SchoolAPI) async {
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

    func createLesson(
        api: SchoolAPI,
        classID: Int,
        subjectID: Int,
        teacherID: Int,
        weekday: Int,
        lessonNumber: Int,
        startsAt: String,
        endsAt: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "class_id": classID,
                "subject_id": subjectID,
                "weekday": weekday,
                "lesson_number": lessonNumber,
                "starts_at": startsAt,
                "ends_at": endsAt
            ]

            if teacherID != 0 {
                body["teacher_id"] = teacherID
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/schedule",
                method: "POST",
                body: body
            )

            successMessage = "Урок создан"
            await loadLessons(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать урок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateLesson(
        api: SchoolAPI,
        lessonID: Int,
        classID: Int,
        subjectID: Int,
        teacherID: Int,
        weekday: Int,
        lessonNumber: Int,
        startsAt: String,
        endsAt: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "class_id": classID,
                "subject_id": subjectID,
                "weekday": weekday,
                "lesson_number": lessonNumber,
                "starts_at": startsAt,
                "ends_at": endsAt
            ]

            if teacherID != 0 {
                body["teacher_id"] = teacherID
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/schedule/\(lessonID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Урок обновлён"
            await loadLessons(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить урок: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteLesson(
        api: SchoolAPI,
        lessonID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/schedule/\(lessonID)",
                method: "DELETE"
            )

            successMessage = "Урок удалён"
            await loadLessons(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить урок: \(error.localizedDescription)"
            isSaving = false
            return false
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

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AdminScheduleError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminScheduleError.badURL
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
            throw AdminScheduleError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminScheduleError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminScheduleError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminScheduleError: LocalizedError {
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