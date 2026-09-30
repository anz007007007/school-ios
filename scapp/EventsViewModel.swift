import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventTimelineDTO] = []
    @Published var filterClasses: [EventClassFilterDTO] = []
    @Published var filterStudents: [EventStudentFilterDTO] = []
    @Published var eventParticipants: [Int: [EventParticipantDTO]] = [:]

    @Published var selectedScope: EventScope = .upcoming
    @Published var selectedClassID: Int = 0
    @Published var selectedStudentID: Int = 0
    @Published var selectedEventType: String = "all"
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingFilters = false
    @Published var isLoadingParticipants = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum EventScope: String, CaseIterable, Identifiable {
        case upcoming = "Ближайшие"
        case past = "Прошедшие"
        case all = "Все"

        var id: String {
            rawValue
        }

        var apiValue: String {
            switch self {
            case .upcoming:
                return "upcoming"
            case .past:
                return "past"
            case .all:
                return "all"
            }
        }
    }

    struct EventDayGroup: Identifiable, Hashable {
        let day: String
        let sortDate: Date
        let events: [EventTimelineDTO]

        var id: String {
            day
        }
    }

    struct EventConflictGroup: Identifiable, Hashable {
        let key: String
        let events: [EventTimelineDTO]

        var id: String {
            key
        }
    }

    let availableEventTypes: [String] = [
        "meeting",
        "holiday",
        "exam",
        "trip",
        "competition",
        "sport",
        "club",
        "class",
        "other"
    ]

    let participationStatuses: [(code: String, title: String)] = [
        ("pending", "Ожидает"),
        ("confirmed", "Участвует"),
        ("declined", "Не участвует"),
        ("attended", "Был"),
        ("absent", "Не был")
    ]

    var eventTypes: [String] {
        let types = Set(events.map { $0.event_type })
        let merged = Set(availableEventTypes).union(types)
        return merged.sorted()
    }

    var filteredEvents: [EventTimelineDTO] {
        var result = events

        if selectedEventType != "all" {
            result = result.filter { $0.event_type == selectedEventType }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { event in
                event.title.localizedCaseInsensitiveContains(query)
                || event.event_type.localizedCaseInsensitiveContains(query)
                || (event.description ?? "").localizedCaseInsensitiveContains(query)
                || dateTimeTitle(event.starts_at).localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            let lhsDate = dateForSorting($0.starts_at)
            let rhsDate = dateForSorting($1.starts_at)

            if lhsDate == rhsDate {
                return $0.id > $1.id
            }

            return lhsDate > rhsDate
        }
    }

    var groupedByDay: [EventDayGroup] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            dayKey(event.starts_at)
        }

        return grouped.compactMap { day, events in
            let sortedEvents = events.sorted {
                let lhsDate = dateForSorting($0.starts_at)
                let rhsDate = dateForSorting($1.starts_at)

                if lhsDate == rhsDate {
                    return $0.id > $1.id
                }

                return lhsDate > rhsDate
            }

            guard let first = sortedEvents.first else {
                return nil
            }

            return EventDayGroup(
                day: day,
                sortDate: dateForSorting(first.starts_at),
                events: sortedEvents
            )
        }
        .sorted { $0.sortDate > $1.sortDate }
    }

    var timeConflicts: [EventConflictGroup] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            conflictTimeKey(event.starts_at)
        }

        return grouped
            .filter { _, events in
                events.count > 1
            }
            .map { key, events in
                EventConflictGroup(
                    key: key,
                    events: events.sorted {
                        let lhsDate = dateForSorting($0.starts_at)
                        let rhsDate = dateForSorting($1.starts_at)

                        if lhsDate == rhsDate {
                            return $0.id > $1.id
                        }

                        return lhsDate > rhsDate
                    }
                )
            }
            .sorted { $0.key > $1.key }
    }

    var totalParticipants: Int {
        filteredEvents.reduce(0) { $0 + $1.participants_count }
    }

    var totalConfirmed: Int {
        filteredEvents.reduce(0) { $0 + $1.confirmed_count }
    }

    var totalDeclined: Int {
        filteredEvents.reduce(0) { $0 + $1.declined_count }
    }

    var waitingCount: Int {
        totalParticipants - totalConfirmed - totalDeclined
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let eventsTask: Void = loadEvents(api: api, showLoading: false)

        _ = await (filtersTask, eventsTask)

        isLoading = false
    }

    func loadFilters(api: SchoolAPI) async {
        isLoadingFilters = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/events/filters",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(EventFiltersDTO.self, from: data)
            filterClasses = decoded.classes
            filterStudents = decoded.students
        } catch {
            errorMessage = "Не удалось загрузить фильтры: \(error.localizedDescription)"
        }

        isLoadingFilters = false
    }

    func loadEvents(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "scope", value: selectedScope.apiValue)
            ]

            if selectedClassID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(selectedClassID)"))
            }

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if selectedEventType != "all" {
                queryItems.append(URLQueryItem(name: "event_type", value: selectedEventType))
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: query))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/events/timeline",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(EventsTimelineResponseDTO.self, from: data)
            events = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить события: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        await loadEvents(api: api)
    }

    func createEvent(
        api: SchoolAPI,
        formData: EventFormData
    ) async -> Bool {
        await saveEvent(
            api: api,
            eventID: nil,
            formData: formData
        )
    }

    func updateEvent(
        api: SchoolAPI,
        eventID: Int,
        formData: EventFormData
    ) async -> Bool {
        await saveEvent(
            api: api,
            eventID: eventID,
            formData: formData
        )
    }

    func deleteEvent(
        api: SchoolAPI,
        event: EventTimelineDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/events/\(event.id)",
                method: "DELETE"
            )

            events.removeAll { $0.id == event.id }
            eventParticipants[event.id] = nil
            successMessage = "Событие удалено"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить событие: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func saveEvent(
        api: SchoolAPI,
        eventID: Int?,
        formData: EventFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanTitle = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            errorMessage = "Введите название события"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "title": cleanTitle,
                "event_type": formData.eventType,
                "starts_at": Self.apiDateFormatter.string(from: formData.startsAt),
                "description": cleanDescription,
                "class_ids": formData.classIDs,
                "student_ids": formData.studentIDs
            ]

            let path: String
            let method: String

            if let eventID {
                path = "/api/v1/events/\(eventID)"
                method = "PUT"
            } else {
                path = "/api/v1/events"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = eventID == nil ? "Событие добавлено" : "Событие обновлено"

            await loadEvents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = eventID == nil
                ? "Не удалось добавить событие: \(error.localizedDescription)"
                : "Не удалось обновить событие: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func participantsForEvent(_ eventID: Int) -> [EventParticipantDTO] {
        eventParticipants[eventID, default: []]
            .sorted { $0.student_name < $1.student_name }
    }

    func availableStudentsForEvent(_ eventID: Int) -> [EventStudentFilterDTO] {
        let participantIDs = Set(participantsForEvent(eventID).map { $0.student_id })

        return filterStudents
            .filter { !participantIDs.contains($0.id) }
            .sorted { $0.student_name < $1.student_name }
    }

    func loadEventParticipants(
        api: SchoolAPI,
        eventID: Int
    ) async {
        isLoadingParticipants = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/events/\(eventID)/participants",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(EventParticipantsListResponseDTO.self, from: data)
            eventParticipants[eventID] = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить участников события: \(error.localizedDescription)"
        }

        isLoadingParticipants = false
    }

    func addParticipants(
        api: SchoolAPI,
        eventID: Int,
        studentIDs: [Int]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard !studentIDs.isEmpty else {
            errorMessage = "Выберите хотя бы одного ученика"
            isSaving = false
            return false
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/events/\(eventID)/participants",
                method: "POST",
                body: [
                    "student_ids": studentIDs
                ]
            )

            successMessage = "Участники добавлены"

            await loadEventParticipants(api: api, eventID: eventID)
            await loadEvents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить участников: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateParticipantStatus(
        api: SchoolAPI,
        eventID: Int,
        studentID: Int,
        status: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/events/\(eventID)/participants/\(studentID)",
                method: "PUT",
                body: [
                    "participation_status": status
                ]
            )

            successMessage = "Статус участника обновлён"

            await loadEventParticipants(api: api, eventID: eventID)
            await loadEvents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить статус участника: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func sendParticipationFeedback(
        api: SchoolAPI,
        eventID: Int,
        studentID: Int,
        willParticipate: Bool
    ) async -> Bool {
        let status = willParticipate ? "confirmed" : "declined"

        let success = await updateParticipantStatus(
            api: api,
            eventID: eventID,
            studentID: studentID,
            status: status
        )

        if success {
            successMessage = willParticipate
                ? "Спасибо! Участие подтверждено"
                : "Ответ сохранён: участие отклонено"
        }

        return success
    }

    func removeParticipant(
        api: SchoolAPI,
        eventID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/events/\(eventID)/participants/\(studentID)",
                method: "DELETE"
            )

            successMessage = "Участник удалён"

            await loadEventParticipants(api: api, eventID: eventID)
            await loadEvents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить участника: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func eventTypeTitle(_ value: String) -> String {
        switch value {
        case "meeting":
            return "Собрание"
        case "holiday":
            return "Праздник"
        case "exam":
            return "Экзамен"
        case "trip":
            return "Экскурсия"
        case "competition":
            return "Конкурс"
        case "sport":
            return "Спорт"
        case "club":
            return "Кружок"
        case "class":
            return "Класс"
        case "other":
            return "Другое"
        default:
            return value
        }
    }

    func participationStatusTitle(_ value: String) -> String {
        switch value {
        case "pending":
            return "Ожидает"
        case "confirmed":
            return "Участвует"
        case "declined":
            return "Не участвует"
        case "attended":
            return "Был"
        case "absent":
            return "Не был"
        default:
            return value
        }
    }

    func dayTitle(_ startsAt: String) -> String {
        guard let date = parseDate(startsAt) else {
            return startsAt
        }

        if Calendar.current.isDateInToday(date) {
            return "Сегодня · \(Self.dayDisplayFormatter.string(from: date))"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Завтра · \(Self.dayDisplayFormatter.string(from: date))"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера · \(Self.dayDisplayFormatter.string(from: date))"
        }

        return Self.dayDisplayFormatter.string(from: date)
    }

    func timeTitle(_ startsAt: String) -> String {
        guard let date = parseDate(startsAt) else {
            return startsAt
        }

        return Self.timeFormatter.string(from: date)
    }

    func dateTimeTitle(_ startsAt: String) -> String {
        guard let date = parseDate(startsAt) else {
            return startsAt
        }

        return Self.dateTimeFormatter.string(from: date)
    }

    func isPast(_ startsAt: String) -> Bool {
        guard let date = parseDate(startsAt) else {
            return false
        }

        return date < Date()
    }

    func dayKey(_ startsAt: String) -> String {
        guard let date = parseDate(startsAt) else {
            return startsAt
        }

        return Self.dayKeyFormatter.string(from: date)
    }

    func conflictTimeKey(_ startsAt: String) -> String {
        guard let date = parseDate(startsAt) else {
            return startsAt
        }

        return Self.conflictTimeFormatter.string(from: date)
    }

    func dateForSorting(_ startsAt: String) -> Date {
        parseDate(startsAt) ?? Date.distantPast
    }

    func parseDate(_ value: String) -> Date? {
        if let date = Self.isoFormatter.date(from: value) {
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
            throw EventsError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw EventsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("EVENTS REQUEST:", method, url.absoluteString)
            print("EVENTS BODY:", body)
        } else {
            print("EVENTS REQUEST:", method, url.absoluteString)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EventsError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("EVENTS RESPONSE STATUS:", httpResponse.statusCode)
        print("EVENTS RESPONSE BODY:", responseText)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw EventsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dayDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let conflictTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

enum EventsError: LocalizedError {
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