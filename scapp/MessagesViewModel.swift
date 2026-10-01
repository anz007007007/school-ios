import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var messages: [MessageDTO] = []
    @Published var announcements: [AnnouncementDTO] = []
    @Published var contacts: [MessageContactDTO] = []
    @Published var classes: [MessageClassDTO] = []
    @Published var unreadCount: Int = 0

    @Published var selectedFolder: MessageFolder = .inbox
    @Published var showOnlyUnread = true
    @Published var showOnlyImportant = false
    @Published var hideReadAnnouncements = true
    @Published var readAnnouncementIDs: Set<Int> = []
    @Published var archivedMessageIDs: Set<Int> = []
    @Published var searchText = ""
    @Published var currentUserID: Int?

    @Published var isLoading = false
    @Published var isLoadingContacts = false
    @Published var isLoadingMessageDetail = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var filteredAnnouncements: [AnnouncementDTO] {
        var result = announcements

        if hideReadAnnouncements {
            result = result.filter { announcement in
                announcement.is_read != true && !readAnnouncementIDs.contains(announcement.id)
            }
        }

        if showOnlyImportant {
            result = result.filter { $0.is_important }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { announcement in
                announcement.title.localizedCaseInsensitiveContains(query)
                || announcement.body.localizedCaseInsensitiveContains(query)
                || announcement.author_name.localizedCaseInsensitiveContains(query)
                || announcement.created_at.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            dateForSorting($0.created_at) > dateForSorting($1.created_at)
        }
    }

    var importantCount: Int {
        filteredMessages.filter { $0.is_important }.count
            + filteredAnnouncements.filter { $0.is_important }.count
    }

    enum MessageFolder: String, CaseIterable, Identifiable {
        case inbox = "Входящие"
        case sent = "Отправленные"
        case archive = "Архив"
        case all = "Все"

        var id: String {
            rawValue
        }

        var apiValue: String? {
            switch self {
            case .inbox:
                return "inbox"
            case .sent:
                return "sent"
            case .archive:
                return "archive"
            case .all:
                return nil
            }
        }
    }

    let archiveStateCode = "archive"

    let audiences: [(code: String, title: String)] = [
        ("all", "Все"),
        ("teachers", "Учителя"),
        ("parents", "Родители"),
        ("students", "Ученики")
    ]

    var filteredMessages: [MessageDTO] {
        var result = messages

        if let currentUserID {
            switch selectedFolder {
            case .inbox:
                result = result.filter {
                    $0.recipient_user_id == currentUserID
                    && !archivedMessageIDs.contains($0.id)
                }

            case .sent:
                result = result.filter {
                    $0.sender_user_id == currentUserID
                    && !archivedMessageIDs.contains($0.id)
                }

            case .archive:
                result = result.filter {
                    archivedMessageIDs.contains($0.id)
                }

            case .all:
                result = result.filter {
                    !archivedMessageIDs.contains($0.id)
                }
            }
        } else {
            switch selectedFolder {
            case .archive:
                result = result.filter {
                    archivedMessageIDs.contains($0.id)
                }

            case .inbox, .sent, .all:
                result = result.filter {
                    !archivedMessageIDs.contains($0.id)
                }
            }
        }

        if showOnlyUnread {
            result = result.filter { !$0.is_read }
        }

        if showOnlyImportant {
            result = result.filter { $0.is_important }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { message in
                message.subject.localizedCaseInsensitiveContains(query)
                || message.body.localizedCaseInsensitiveContains(query)
                || message.sender_name.localizedCaseInsensitiveContains(query)
                || message.recipient_name.localizedCaseInsensitiveContains(query)
                || message.created_at.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            dateForSorting($0.created_at) > dateForSorting($1.created_at)
        }
    }

    var unreadFilteredCount: Int {
        filteredMessages.filter { !$0.is_read }.count
    }

    var groupedMessages: [MessageDateGroup] {
        let grouped = Dictionary(grouping: filteredMessages) { message in
            dayKey(message.created_at)
        }

        return grouped.compactMap { day, messages in
            guard let first = messages.first else {
                return nil
            }

            return MessageDateGroup(
                day: day,
                sortDate: dateForSorting(first.created_at),
                messages: messages.sorted {
                    dateForSorting($0.created_at) > dateForSorting($1.created_at)
                }
            )
        }
        .sorted { $0.sortDate > $1.sortDate }
    }

    struct MessageDateGroup: Identifiable, Hashable {
        let day: String
        let sortDate: Date
        let messages: [MessageDTO]

        var id: String {
            day
        }
    }

    func loadInitialData(api: SchoolAPI) async {
        loadReadAnnouncementIDs()
        loadArchivedMessageIDs()

        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let messagesTask: Void = loadMessages(api: api, showLoading: false)
        async let announcementsTask: Void = loadAnnouncements(api: api)
        async let unreadTask: Void = loadUnreadCount(api: api)
        async let contactsTask: Void = loadContacts(api: api)
        async let classesTask: Void = loadClasses(api: api)

        _ = await (messagesTask, announcementsTask, unreadTask, contactsTask, classesTask)

        isLoading = false
    }

    func loadContacts(api: SchoolAPI) async {
        isLoadingContacts = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/contacts",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MessageContactsListResponseDTO.self, from: data)
            contacts = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить контакты: \(error.localizedDescription)"
        }

        isLoadingContacts = false
    }

    func loadClasses(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/classes",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MessageClassesListResponseDTO.self, from: data)
            classes = decoded.items
        } catch {
            // Не блокируем экран, если классы не загрузились.
        }
    }

    func loadMessages(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if let folder = selectedFolder.apiValue {
                queryItems.append(URLQueryItem(name: "folder", value: folder))
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: query))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(MessagesListResponseDTO.self, from: data)
            messages = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить сообщения: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadMessageDetail(
        api: SchoolAPI,
        messageID: Int
    ) async -> MessageDTO? {
        isLoadingMessageDetail = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/\(messageID)",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(MessageDTO.self, from: data)

            messages = messages.map { item in
                item.id == decoded.id ? decoded : item
            }

            isLoadingMessageDetail = false
            return decoded
        } catch {
            errorMessage = "Не удалось загрузить сообщение: \(error.localizedDescription)"
            isLoadingMessageDetail = false
            return nil
        }
    }

    func openMessage(
        api: SchoolAPI,
        message: MessageDTO,
        currentUserID: Int?
    ) async -> MessageDTO? {
        let detail = await loadMessageDetail(api: api, messageID: message.id) ?? message

        if !detail.is_read, detail.isIncoming(for: currentUserID) {
            _ = await markAsRead(
                api: api,
                message: detail,
                currentUserID: currentUserID
            )

            return messages.first { $0.id == detail.id } ?? detail
        }

        return detail
    }

    func loadUnreadCount(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/unread-count",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(UnreadMessagesCountDTO.self, from: data)
            unreadCount = decoded.unread_count
        } catch {
            // Не блокируем весь экран, если только счётчик не загрузился.
        }
    }

    func loadAnnouncements(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/announcements",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AnnouncementsListResponseDTO.self, from: data)
            announcements = decoded.items
        } catch {
            // Объявления не критичны для сообщений.
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        async let messagesTask: Void = loadMessages(api: api)
        async let unreadCountTask: Void = loadUnreadCount(api: api)

        _ = await (messagesTask, unreadCountTask)
    }

    func sendMessage(
        api: SchoolAPI,
        formData: MessageCreateFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanSubject = formData.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = formData.body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard formData.recipientUserID != 0 else {
            errorMessage = "Выберите получателя"
            isSaving = false
            return false
        }

        guard !cleanSubject.isEmpty else {
            errorMessage = "Введите тему"
            isSaving = false
            return false
        }

        guard !cleanBody.isEmpty else {
            errorMessage = "Введите текст сообщения"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "recipient_user_id": formData.recipientUserID,
                "subject": cleanSubject,
                "body": cleanBody,
                "is_important": formData.isImportant
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/messages",
                method: "POST",
                body: body
            )

            successMessage = "Сообщение отправлено"
            await loadMessages(api: api, showLoading: false)
            await loadUnreadCount(api: api)
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отправить сообщение: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func sendBulkMessage(
        api: SchoolAPI,
        formData: MessageBulkFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanSubject = formData.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = formData.body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanSubject.isEmpty else {
            errorMessage = "Введите тему"
            isSaving = false
            return false
        }

        guard !cleanBody.isEmpty else {
            errorMessage = "Введите текст сообщения"
            isSaving = false
            return false
        }

        do {
            var body: [String: Any] = [
                "subject": cleanSubject,
                "body": cleanBody,
                "is_important": formData.isImportant
            ]

            if !formData.recipientUserIDs.isEmpty {
                body["recipient_user_ids"] = formData.recipientUserIDs
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/messages/bulk",
                method: "POST",
                body: body
            )

            let decoded = try? JSONDecoder().decode(BulkMessageStatusResponseDTO.self, from: data)

            if let count = decoded?.sent_count {
                successMessage = "Рассылка отправлена: \(count)"
            } else {
                successMessage = "Рассылка отправлена"
            }

            await loadMessages(api: api, showLoading: false)
            await loadUnreadCount(api: api)
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отправить рассылку: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createAnnouncement(
        api: SchoolAPI,
        formData: AnnouncementFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanTitle = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = formData.body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            errorMessage = "Введите заголовок объявления"
            isSaving = false
            return false
        }

        guard !cleanBody.isEmpty else {
            errorMessage = "Введите текст объявления"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "title": cleanTitle,
                "body": cleanBody,
                "target_audience": formData.targetAudience,
                "is_important": formData.isImportant
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/messages/announcements",
                method: "POST",
                body: body
            )

            successMessage = "Объявление создано"
            await loadAnnouncements(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать объявление: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func markAsRead(
        api: SchoolAPI,
        message: MessageDTO,
        currentUserID: Int?
    ) async -> Bool {
        guard message.isIncoming(for: currentUserID) else {
            return false
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/messages/\(message.id)/read",
                method: "PATCH"
            )

            messages = messages.map { item in
                if item.id == message.id {
                    return MessageDTO(
                        id: item.id,
                        parent_message_id: item.parent_message_id,
                        subject: item.subject,
                        body: item.body,
                        is_read: true,
                        is_important: item.is_important,
                        created_at: item.created_at,
                        read_at: item.read_at,
                        sender_user_id: item.sender_user_id,
                        recipient_user_id: item.recipient_user_id,
                        sender_name: item.sender_name,
                        recipient_name: item.recipient_name,
                        sender_role_code: item.sender_role_code,
                        recipient_role_code: item.recipient_role_code
                    )
                }

                return item
            }

            unreadCount = max(unreadCount - 1, 0)
            await loadUnreadCount(api: api)
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
            return true
        } catch {
            errorMessage = "Не удалось отметить сообщение прочитанным: \(error.localizedDescription)"
            return false
        }
    }

    func archiveMessage(
        api: SchoolAPI,
        message: MessageDTO
    ) async -> Bool {
        let success = await updateMessageState(
            api: api,
            message: message,
            state: archiveStateCode
        )

        if success {
            archivedMessageIDs.insert(message.id)
            saveArchivedMessageIDs()

            if selectedFolder != .archive {
                messages.removeAll { $0.id == message.id }
            }
        }

        return success
    }

    func updateMessageState(
        api: SchoolAPI,
        message: MessageDTO,
        state: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "state": state
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/messages/\(message.id)/state",
                method: "PATCH",
                body: body
            )

            successMessage = "Сообщение перемещено в архив"
            await loadMessages(api: api, showLoading: false)
            await loadUnreadCount(api: api)
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось переместить сообщение в архив: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func markAnnouncementOpened(_ announcement: AnnouncementDTO) {
        readAnnouncementIDs.insert(announcement.id)
        saveReadAnnouncementIDs()
    }

    func loadReadAnnouncementIDs() {
        let values = UserDefaults.standard.array(forKey: "read_announcement_ids") as? [Int] ?? []
        readAnnouncementIDs = Set(values)
    }

    private func saveReadAnnouncementIDs() {
        UserDefaults.standard.set(Array(readAnnouncementIDs), forKey: "read_announcement_ids")
    }

    func loadArchivedMessageIDs() {
        let values = UserDefaults.standard.array(forKey: "archived_message_ids") as? [Int] ?? []
        archivedMessageIDs = Set(values)
    }

    private func saveArchivedMessageIDs() {
        UserDefaults.standard.set(Array(archivedMessageIDs), forKey: "archived_message_ids")
    }

    func dateTitle(_ value: String) -> String {
        guard let date = parseDate(value) else {
            return value
        }

        if Calendar.current.isDateInToday(date) {
            return "Сегодня"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера"
        }

        return Self.dayDisplayFormatter.string(from: date)
    }

    func dateTimeTitle(_ value: String) -> String {
        guard let date = parseDate(value) else {
            return value
        }

        return Self.dateTimeFormatter.string(from: date)
    }

    func timeTitle(_ value: String) -> String {
        guard let date = parseDate(value) else {
            return value
        }

        return Self.timeFormatter.string(from: date)
    }

    func dayKey(_ value: String) -> String {
        guard let date = parseDate(value) else {
            return value
        }

        return Self.dayKeyFormatter.string(from: date)
    }

    func dateForSorting(_ value: String) -> Date {
        parseDate(value) ?? Date.distantPast
    }

    func audienceTitle(_ value: String) -> String {
        audiences.first { $0.code == value }?.title ?? value
    }

    func roleTitle(_ value: String) -> String {
        switch value {
        case "admin":
            return "Администратор"
        case "teacher":
            return "Учитель"
        case "parent":
            return "Родитель"
        case "student":
            return "Ученик"
        case "cook":
            return "Повар"
        default:
            return value
        }
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
            throw MessagesError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw MessagesError.badURL
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
            print("MESSAGES REQUEST:", method, url.absoluteString)
            print("MESSAGES BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("MESSAGES REQUEST:", method, url.absoluteString)
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MessagesError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("MESSAGES RESPONSE STATUS:", httpResponse.statusCode)
        print("MESSAGES RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw MessagesError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MessagesError.serverError(statusCode: httpResponse.statusCode, text: responseText)
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

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let dayDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

enum MessagesError: LocalizedError {
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