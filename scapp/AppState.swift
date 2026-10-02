import Foundation
import Combine
import SchoolAPIClient

enum PushRoute: Hashable, Identifiable {
    case diary(notificationID: Int?)
    case homework(notificationID: Int?)
    case messages(notificationID: Int?)
    case events(notificationID: Int?)
    case finance(notificationID: Int?)
    case health(notificationID: Int?)
    case schedule(notificationID: Int?)
    case documents(notificationID: Int?)
    case menu(notificationID: Int?)
    case textbooks(notificationID: Int?)
    case portfolio(notificationID: Int?)
    case clubs(notificationID: Int?)
    case community(notificationID: Int?)
    case notifications(notificationID: Int?)

    var id: String {
        switch self {
        case .diary(let notificationID):
            return "diary-\(notificationID ?? 0)"
        case .homework(let notificationID):
            return "homework-\(notificationID ?? 0)"
        case .messages(let notificationID):
            return "messages-\(notificationID ?? 0)"
        case .events(let notificationID):
            return "events-\(notificationID ?? 0)"
        case .finance(let notificationID):
            return "finance-\(notificationID ?? 0)"
        case .health(let notificationID):
            return "health-\(notificationID ?? 0)"
        case .schedule(let notificationID):
            return "schedule-\(notificationID ?? 0)"
        case .documents(let notificationID):
            return "documents-\(notificationID ?? 0)"
        case .menu(let notificationID):
            return "menu-\(notificationID ?? 0)"
        case .textbooks(let notificationID):
            return "textbooks-\(notificationID ?? 0)"
        case .portfolio(let notificationID):
            return "portfolio-\(notificationID ?? 0)"
        case .clubs(let notificationID):
            return "clubs-\(notificationID ?? 0)"
        case .community(let notificationID):
            return "community-\(notificationID ?? 0)"
        case .notifications(let notificationID):
            return "notifications-\(notificationID ?? 0)"
        }
    }

    var notificationID: Int? {
        switch self {
        case .diary(let notificationID),
             .homework(let notificationID),
             .messages(let notificationID),
             .events(let notificationID),
             .finance(let notificationID),
             .health(let notificationID),
             .schedule(let notificationID),
             .documents(let notificationID),
             .menu(let notificationID),
             .textbooks(let notificationID),
             .portfolio(let notificationID),
             .clubs(let notificationID),
             .community(let notificationID),
             .notifications(let notificationID):
            return notificationID
        }
    }

    var sectionKey: String {
        switch self {
        case .diary:
            return "diary"
        case .homework:
            return "homework"
        case .messages:
            return "messages"
        case .events:
            return "events"
        case .finance:
            return "finance"
        case .health:
            return "health"
        case .schedule:
            return "schedule"
        case .documents:
            return "documents"
        case .menu:
            return "menu"
        case .textbooks:
            return "textbooks"
        case .portfolio:
            return "portfolio"
        case .clubs:
            return "clubs"
        case .community:
            return "community"
        case .notifications:
            return "notifications"
        }
    }

    static func route(notificationType: String?, sectionCode: String?, notificationID: Int?) -> PushRoute {
        let values = [
            sectionCode,
            notificationType
        ]
        .compactMap { $0 }
        .map { normalizeRouteValue($0) }

        return route(
            values: values,
            notificationID: notificationID
        )
    }

    static func route(values: [String], notificationID: Int?) -> PushRoute {
        let normalizedValues = values
            .map { normalizeRouteValue($0) }
            .filter { !$0.isEmpty }

        let joined = normalizedValues.joined(separator: " ")

        #if DEBUG
        print("PUSH ROUTE VALUES:", normalizedValues)
        print("PUSH ROUTE JOINED:", joined)
        #endif

        if containsAny(
            joined,
            [
                "grade",
                "grades",
                "mark",
                "marks",
                "diary",
                "journal",
                "grade_created",
                "new_grade",
                "student_grade",
                "оцен",
                "дневник",
                "журнал"
            ]
        ) {
            return .diary(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "homework",
                "home_work",
                "task",
                "assignment",
                "домаш",
                "дз",
                "задан"
            ]
        ) {
            return .homework(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "message",
                "messages",
                "chat",
                "mail",
                "conversation",
                "сообщ",
                "чат",
                "письм"
            ]
        ) {
            return .messages(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "event",
                "events",
                "calendar",
                "событ",
                "мероприят"
            ]
        ) {
            return .events(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "finance",
                "payment",
                "payments",
                "invoice",
                "invoices",
                "bill",
                "bills",
                "финанс",
                "плат",
                "счет",
                "счёт",
                "квитанц"
            ]
        ) {
            return .finance(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "health",
                "medical",
                "medicine",
                "здоров",
                "медиц"
            ]
        ) {
            return .health(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "schedule",
                "lesson",
                "lessons",
                "timetable",
                "распис",
                "урок"
            ]
        ) {
            return .schedule(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "document",
                "documents",
                "doc",
                "docs",
                "документ",
                "справк"
            ]
        ) {
            return .documents(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "menu",
                "food",
                "meal",
                "school_menu",
                "питан",
                "меню"
            ]
        ) {
            return .menu(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "textbook",
                "textbooks",
                "material",
                "materials",
                "учебник",
                "материал",
                "пособ"
            ]
        ) {
            return .textbooks(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "portfolio",
                "achievement",
                "achievements",
                "портфолио",
                "достижен"
            ]
        ) {
            return .portfolio(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "club",
                "clubs",
                "circle",
                "circles",
                "круж",
                "клуб",
                "секц"
            ]
        ) {
            return .clubs(notificationID: notificationID)
        }

        if containsAny(
            joined,
            [
                "community",
                "announcement",
                "announcements",
                "promo",
                "ad",
                "ads",
                "объяв",
                "новост"
            ]
        ) {
            return .community(notificationID: notificationID)
        }

        return .notifications(notificationID: notificationID)
    }

    private static func normalizeRouteValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        let words = value.split(separator: " ")
        return needles.contains { needle in
            words.contains { $0.hasPrefix(needle) }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: SchoolAPIClient.Components.Schemas.CurrentUserResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pushNotificationsFeatureEnabled = true
    @Published var pushRoute: PushRoute?
    @Published var didTryRestoreSession = false
    /// Идёт автоматический вход по сохранённым данным при запуске.
    @Published private(set) var isRestoringSession = false
    /// Вход при запуске не удался из-за сети или ошибки сервера: данные входа
    /// сохранены, показываем «Повторить» и «Выйти» вместо формы входа.
    @Published var startupErrorMessage: String?
    /// Последняя попытка входа отклонена сервером (4xx). Только такие попытки
    /// идут в счётчик блокировки; сетевые ошибки и 5xx — нет.
    @Published private(set) var lastLoginRejected = false
    @Published private(set) var unreadNotificationsBySection: [String: Int] = [:]
    @Published private(set) var tabReselectToken: [MainTabSelection: Int] = [:]

    let api = SchoolAPI(
        baseURL: URL(string: "https://sc.it-status.ru/")!
    )

    private var cancellables = Set<AnyCancellable>()
    private var sessionCheckTask: Task<Void, Never>?

    init() {
        PushNotificationService.shared.appState = self

        NotificationCenter.default.publisher(for: .authSessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let requestToken = notification.userInfo?[AuthSessionEvents.requestTokenKey] as? String

                Task { @MainActor in
                    self?.handleSessionExpiredEvent(requestToken: requestToken)
                }
            }
            .store(in: &cancellables)
    }

    func unreadNotificationsCount(for sectionKey: String) -> Int {
        unreadNotificationsBySection[sectionKey] ?? 0
    }

    func hasUnreadNotifications(for sectionKey: String) -> Bool {
        unreadNotificationsCount(for: sectionKey) > 0
    }

    func refreshUnreadNotificationsBySection() async {
        guard isAuthenticated, let requestToken = api.authToken else {
            unreadNotificationsBySection = [:]
            return
        }

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationsListResponseDTO.self,
                api: api,
                path: "/api/v1/push/notifications",
                method: "GET",
                logPrefix: "PUSH SECTION UNREAD BADGES"
            )

            var result: [String: Int] = [:]

            for notification in response.items where !notification.is_read {
                var routeValues = [
                    notification.notification_type,
                    notification.title,
                    notification.body
                ]

                if let sectionCode = notification.section_code {
                    routeValues.append(sectionCode)
                }

                if let payload = notification.payload_json {
                    routeValues.append(contentsOf: payload.map { "\($0.key) \($0.value.stringValue)" })
                }

                let route = PushRoute.route(
                    values: routeValues,
                    notificationID: notification.id
                )

                guard route.sectionKey != "notifications" else {
                    continue
                }

                result[route.sectionKey, default: 0] += 1
            }

            // Ответ мог прийти уже после выхода или входа под другим пользователем.
            guard isAuthenticated, api.authToken == requestToken else {
                return
            }

            unreadNotificationsBySection = result
        } catch {
            #if DEBUG
            print("PUSH SECTION UNREAD BADGES ERROR:", error.localizedDescription)
            #endif
        }
    }

    func restoreSessionIfPossible() async {
        guard !didTryRestoreSession else {
            return
        }

        didTryRestoreSession = true
        await performSessionRestore()
    }

    /// «Повторить» на экране ошибки запуска.
    func retrySessionRestore() async {
        startupErrorMessage = nil
        await performSessionRestore()
    }

    /// «Выйти» на экране ошибки запуска: больше не входим автоматически.
    func cancelSessionRestore() {
        startupErrorMessage = nil
        errorMessage = nil
        LoginSecurityService.shared.isSessionActive = false
    }

    private func performSessionRestore() async {
        let security = LoginSecurityService.shared

        guard security.rememberLogin, security.isSessionActive else {
            return
        }

        guard let credentials = try? security.loadCredentials() else {
            return
        }

        isRestoringSession = true
        isLoading = true
        errorMessage = nil
        startupErrorMessage = nil

        await PushNotificationService.shared.waitForPendingDetach()

        switch await authenticate(login: credentials.login, password: credentials.password) {
        case .success:
            await completeLogin()

        case .rejected(let statusCode, let message):
            // Сервер отклонил сохранённые данные (сменили пароль, учётку отключили):
            // удаляем их только на 401/403, на прочие 4xx оставляем.
            if statusCode == 401 || statusCode == 403 {
                security.deleteCredentials()
                security.rememberLogin = false
            }

            errorMessage = "Не удалось восстановить вход: \(message)"

        case .failed(let message):
            // Сеть или 5xx: данные входа не трогаем, даём повторить.
            startupErrorMessage = message
        }

        isLoading = false
        isRestoringSession = false
    }

    private enum AuthAttemptResult {
        case success
        /// Сервер отклонил вход (4xx).
        case rejected(statusCode: Int, message: String)
        /// Сеть, 5xx или неразборчивый ответ.
        case failed(message: String)
    }

    /// Вход и загрузка /auth/me. Токен остаётся в `api` только если оба шага прошли.
    private func authenticate(login: String, password: String) async -> AuthAttemptResult {
        do {
            _ = try await api.login(login: login, password: password)
        } catch {
            api.logout()

            if let statusCode = Self.loginStatusCode(from: error), (400..<500).contains(statusCode) {
                return .rejected(statusCode: statusCode, message: readableLoginError(error))
            }

            return .failed(message: readableLoginError(error))
        }

        do {
            currentUser = try await api.getCurrentUser()
            return .success
        } catch {
            api.logout()
            currentUser = nil

            if isUnauthorizedError(error) {
                return .rejected(statusCode: 401, message: readableLoginError(error))
            }

            if error.localizedDescription.contains("403") {
                return .rejected(statusCode: 403, message: readableLoginError(error))
            }

            return .failed(message: "Не удалось загрузить данные пользователя. Проверьте интернет и попробуйте снова.")
        }
    }

    /// Код ответа сервера на /auth/login по ошибке из SchoolAPI.login (пакет не отдаёт код напрямую).
    private static func loginStatusCode(from error: Error) -> Int? {
        guard let apiError = error as? SchoolAPIError,
              case .serverError(let message) = apiError else {
            return nil
        }

        switch message {
        case "Неверный логин или пароль.":
            return 401
        case "Проверьте данные для входа и согласия.":
            return 400
        case "Проверьте логин, пароль и согласия.":
            return 422
        case "Ошибка сервера. Попробуйте позже.":
            return 500
        default:
            let prefix = "Ошибка авторизации: "

            guard message.hasPrefix(prefix) else {
                return nil
            }

            return Int(message.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
        }
    }

    private func completeLogin() async {
        isAuthenticated = true
        errorMessage = nil
        startupErrorMessage = nil
        LoginSecurityService.shared.isSessionActive = true

        await refreshMobileConfigFeatures()
        await refreshUnreadNotificationsBySection()

        await registerPushNotificationsIfNeeded()

        await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
    }

    func openPushRoute(_ route: PushRoute) {
        #if DEBUG
        print("PUSH OPEN ROUTE:", route.sectionKey, "notificationID:", route.notificationID as Any)
        #endif

        guard isAuthenticated else {
            return
        }

        let route = canOpenPushRoute(route) ? route : .notifications(notificationID: route.notificationID)
        let userID = currentUser?.id

        pushRoute = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            // Пока ждали, могли выйти или войти под другим пользователем.
            guard let self, self.isAuthenticated, self.currentUser?.id == userID else {
                return
            }

            #if DEBUG
            print("PUSH SET ROUTE:", route.sectionKey)
            #endif
            self.pushRoute = route
        }

        Task {
            await markPushNotificationReadIfNeeded(route.notificationID)
            await markNotificationsReadForRoute(route)
        }
    }

    func markPushNotificationReadIfNeeded(_ notificationID: Int?) async {
        guard let notificationID else {
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
            return
        }

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/push/notifications/\(notificationID)/read",
                method: "PATCH",
                logPrefix: "PUSH NOTIFICATION READ FROM ROUTE"
            )

            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
        } catch {
            #if DEBUG
            print("PUSH NOTIFICATION READ FROM ROUTE ERROR:", error.localizedDescription)
            #endif
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
        }
    }

    func markNotificationsReadForRoute(_ route: PushRoute) async {
        guard isAuthenticated else {
            return
        }

        guard route.sectionKey != "notifications" else {
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
            return
        }

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationsListResponseDTO.self,
                api: api,
                path: "/api/v1/push/notifications",
                method: "GET",
                logPrefix: "PUSH SECTION NOTIFICATIONS"
            )

            let unreadItems = response.items.filter { notification in
                guard !notification.is_read else {
                    return false
                }

                var routeValues = [
                    notification.notification_type,
                    notification.title,
                    notification.body
                ]

                if let sectionCode = notification.section_code {
                    routeValues.append(sectionCode)
                }

                if let payload = notification.payload_json {
                    routeValues.append(contentsOf: payload.map { "\($0.key) \($0.value.stringValue)" })
                }

                let notificationRoute = PushRoute.route(
                    values: routeValues,
                    notificationID: notification.id
                )

                return notificationRoute.sectionKey == route.sectionKey
            }

            guard !unreadItems.isEmpty else {
                await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
                return
            }

            let currentAPI = api

            await withTaskGroup(of: Void.self) { group in
                for item in unreadItems {
                    group.addTask {
                        _ = try? await APIRequestService.shared.request(
                            api: currentAPI,
                            path: "/api/v1/push/notifications/\(item.id)/read",
                            method: "PATCH",
                            logPrefix: "PUSH SECTION NOTIFICATION READ"
                        )
                    }
                }
            }

            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
        } catch {
            #if DEBUG
            print("PUSH SECTION NOTIFICATIONS READ ERROR:", error.localizedDescription)
            #endif
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: api)
        }
    }

    func login(
        login: String,
        password: String,
        personalDataAgreement: Bool,
        termsAgreement: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        startupErrorMessage = nil
        lastLoginRejected = false

        // Отвязка push после прошлого выхода должна закончиться до нового входа,
        // иначе она удалит устройство уже нового пользователя.
        await PushNotificationService.shared.waitForPendingDetach()

        switch await authenticate(login: login, password: password) {
        case .success:
            await completeLogin()

        case .rejected(_, let message):
            errorMessage = message
            lastLoginRejected = true
            isAuthenticated = false
            unreadNotificationsBySection = [:]

        case .failed(let message):
            errorMessage = message
            isAuthenticated = false
            unreadNotificationsBySection = [:]
        }

        isLoading = false
    }

    func refreshCurrentUser() async {
        guard isAuthenticated, let requestToken = api.authToken else {
            return
        }

        do {
            let user = try await api.getCurrentUser()

            // Ответ на запрос прошлой сессии не должен подменить пользователя.
            guard isAuthenticated, api.authToken == requestToken else {
                return
            }

            currentUser = user

            await refreshMobileConfigFeatures()
            await refreshUnreadNotificationsBySection()
        } catch {
            if isUnauthorizedError(error) {
                handleSessionExpiredEvent(requestToken: requestToken)
            } else {
                errorMessage = "Не удалось обновить профиль: \(error.localizedDescription)"
            }
        }
    }

    private var lastParentContextRefreshDate = Date.distantPast

    func refreshParentLinkedStudentsContextIfNeeded() async {
        guard isAuthenticated, isParent else {
            return
        }

        guard Date().timeIntervalSince(lastParentContextRefreshDate) > 300 else {
            return
        }

        lastParentContextRefreshDate = Date()

        await refreshCurrentUser()
    }

    /// Bumped when the user taps a tab that's already selected, so that screen can do a quiet refresh.
    func bumpTabReselectToken(for tab: MainTabSelection) {
        tabReselectToken[tab, default: 0] += 1
    }

    func registerPushNotificationsIfNeeded() async {
        guard isAuthenticated else {
            return
        }

        guard pushNotificationsFeatureEnabled else {
            return
        }

        PushNotificationService.shared.attach(api: api)
        await PushNotificationService.shared.requestPermissionAndRegister()
        await PushNotificationService.shared.ensurePushRegistration(api: api)
    }

    func refreshMobileConfigFeatures() async {
        guard let token = api.authToken else {
            return
        }

        guard let url = URL(string: "https://sc.it-status.ru/api/v1/school-info/mobile-config") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            if httpResponse.statusCode == 401 {
                handleSessionExpiredEvent(requestToken: token)
                return
            }

            guard api.authToken == token else {
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return
            }

            let decoded = try JSONDecoder().decode(MobileConfigResponseDTO.self, from: data)
            pushNotificationsFeatureEnabled = decoded.features?.push_notifications ?? true
        } catch {
            #if DEBUG
            print("APP STATE MOBILE CONFIG ERROR:", error.localizedDescription)
            #endif
        }
    }

    func logout() {
        // Токен нужен, чтобы удалить push-устройство на сервере уже после выхода.
        let authToken = api.authToken

        PushNotificationService.shared.detachOnLogout(authToken: authToken)
        LoginSecurityService.shared.isSessionActive = false

        resetSessionState()
        errorMessage = nil
    }

    /// 401 от запроса. `requestToken` — токен, с которым ушёл запрос, если он известен.
    /// Запоздавший ответ на запрос прошлой сессии не должен разлогинить только что
    /// вошедшего пользователя.
    func handleSessionExpiredEvent(requestToken: String?) {
        guard isAuthenticated else {
            return
        }

        guard let currentToken = api.authToken else {
            handleSessionExpired()
            return
        }

        if let requestToken {
            if requestToken == currentToken {
                handleSessionExpired()
            }

            return
        }

        // Токен запроса неизвестен (экраны со своим URLSession): проверяем текущую
        // сессию через /auth/me и выходим, только если и он ответит 401.
        guard sessionCheckTask == nil else {
            return
        }

        sessionCheckTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.sessionCheckTask = nil
            }

            do {
                _ = try await self.api.getCurrentUser()
            } catch {
                guard self.isAuthenticated, self.api.authToken == currentToken else {
                    return
                }

                if self.isUnauthorizedError(error) {
                    self.handleSessionExpired()
                }
            }
        }
    }

    func handleSessionExpired() {
        guard isAuthenticated else {
            return
        }

        // Токен уже недействителен: устройство на сервере не удалить, но FCM-токен
        // и показанные уведомления чистим.
        PushNotificationService.shared.detachOnLogout(authToken: nil)

        resetSessionState()
        errorMessage = "Сессия истекла. Войдите снова."
    }

    /// Сбрасывает всё, что относится к пользователю. Экраны (их ViewModel) живут
    /// внутри MainTabView и уничтожаются вместе с ним при isAuthenticated = false.
    private func resetSessionState() {
        sessionCheckTask?.cancel()
        sessionCheckTask = nil

        api.logout()

        isAuthenticated = false
        currentUser = nil
        pushRoute = nil
        pushNotificationsFeatureEnabled = true
        unreadNotificationsBySection = [:]
        tabReselectToken = [:]
        lastParentContextRefreshDate = .distantPast
        lastLoginRejected = false

        // Выбранный ребёнок в «Домашке» относится к прошлому пользователю.
        UserDefaults.standard.removeObject(forKey: "homework_selected_student_id")
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()

        return message.contains("401")
        || message.contains("unauthorized")
        || message.contains("not authenticated")
        || message.contains("сессия истекла")
        || message.contains("войдите снова")
    }

    private func readableLoginError(_ error: Error) -> String {
        let rawMessage = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedMessage = rawMessage.lowercased()

        if normalizedMessage.contains("cancelled")
            || normalizedMessage.contains("canceled")
            || normalizedMessage.contains("отмен") {
            return "Вход был отменён. Попробуйте ещё раз."
        }

        if normalizedMessage.contains("timed out")
            || normalizedMessage.contains("timeout")
            || normalizedMessage.contains("превышен")
            || normalizedMessage.contains("тайм") {
            return "Сервер слишком долго не отвечает. Проверьте интернет и попробуйте снова."
        }

        if normalizedMessage.contains("not connected to the internet")
            || normalizedMessage.contains("network connection was lost")
            || normalizedMessage.contains("internet connection appears to be offline")
            || normalizedMessage.contains("could not connect")
            || normalizedMessage.contains("cannot connect")
            || normalizedMessage.contains("offline")
            || normalizedMessage.contains("соединение")
            || normalizedMessage.contains("интернет")
            || normalizedMessage.contains("сеть") {
            return "Нет подключения к серверу. Проверьте интернет и попробуйте снова."
        }

        if normalizedMessage.contains("ssl")
            || normalizedMessage.contains("certificate")
            || normalizedMessage.contains("сертификат") {
            return "Не удалось установить защищённое соединение с сервером. Проверьте дату и время на устройстве или попробуйте позже."
        }

        if normalizedMessage.contains("401")
            || normalizedMessage.contains("unauthorized")
            || normalizedMessage.contains("invalid credentials")
            || normalizedMessage.contains("incorrect username or password")
            || normalizedMessage.contains("wrong password")
            || normalizedMessage.contains("bad credentials")
            || normalizedMessage.contains("невер")
            || normalizedMessage.contains("парол")
            || normalizedMessage.contains("логин") {
            return "Неверный логин или пароль. Проверьте данные и попробуйте снова."
        }

        if normalizedMessage.contains("403")
            || normalizedMessage.contains("forbidden")
            || normalizedMessage.contains("access denied")
            || normalizedMessage.contains("доступ запрещ") {
            return "У вашей учётной записи нет доступа к мобильному приложению. Обратитесь к администратору школы."
        }

        if normalizedMessage.contains("404")
            || normalizedMessage.contains("not found") {
            return "Сервис авторизации временно недоступен. Попробуйте позже."
        }

        if normalizedMessage.contains("422")
            || normalizedMessage.contains("validation")
            || normalizedMessage.contains("unprocessable") {
            if let detail = serverDetail(from: rawMessage) {
                return readableLoginValidationDetail(detail)
            }

            return "Проверьте правильность заполнения логина и пароля."
        }

        if normalizedMessage.contains("429")
            || normalizedMessage.contains("too many requests")
            || normalizedMessage.contains("rate limit") {
            return "Слишком много попыток входа. Подождите немного и попробуйте снова."
        }

        if normalizedMessage.contains("500")
            || normalizedMessage.contains("502")
            || normalizedMessage.contains("503")
            || normalizedMessage.contains("504")
            || normalizedMessage.contains("internal server error")
            || normalizedMessage.contains("bad gateway")
            || normalizedMessage.contains("service unavailable") {
            return "На сервере временная ошибка. Попробуйте войти позже."
        }

        if let detail = serverDetail(from: rawMessage) {
            return readableLoginValidationDetail(detail)
        }

        if rawMessage.isEmpty {
            return "Не удалось выполнить вход. Проверьте интернет и попробуйте снова."
        }

        return "Не удалось выполнить вход. \(rawMessage)"
    }

    private func serverDetail(from message: String) -> String? {
        guard let jsonStartIndex = message.firstIndex(of: "{") else {
            return nil
        }

        let jsonText = String(message[jsonStartIndex...])

        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let detail = json["detail"] as? String {
            return detail.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let message = json["message"] as? String {
            return message.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let error = json["error"] as? String {
            return error.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func readableLoginValidationDetail(_ detail: String) -> String {
        let normalizedDetail = detail.lowercased()

        if normalizedDetail.contains("invalid credentials")
            || normalizedDetail.contains("incorrect username or password")
            || normalizedDetail.contains("wrong password")
            || normalizedDetail.contains("bad credentials")
            || normalizedDetail.contains("невер")
            || normalizedDetail.contains("парол")
            || normalizedDetail.contains("логин") {
            return "Неверный логин или пароль. Проверьте данные и попробуйте снова."
        }

        if normalizedDetail.contains("inactive")
            || normalizedDetail.contains("disabled")
            || normalizedDetail.contains("blocked")
            || normalizedDetail.contains("заблок")
            || normalizedDetail.contains("отключ")
            || normalizedDetail.contains("неактив") {
            return "Учётная запись отключена или заблокирована. Обратитесь к администратору школы."
        }

        if normalizedDetail.contains("agreement")
            || normalizedDetail.contains("terms")
            || normalizedDetail.contains("personal data")
            || normalizedDetail.contains("соглас")
            || normalizedDetail.contains("услов") {
            return "Для входа необходимо принять согласие на обработку персональных данных и условия пользования приложением."
        }

        if normalizedDetail.contains("mobile")
            || normalizedDetail.contains("app access")
            || normalizedDetail.contains("permission")
            || normalizedDetail.contains("доступ") {
            return "У вашей учётной записи нет доступа к мобильному приложению. Обратитесь к администратору школы."
        }

        return detail
    }

    var userRoleCode: String {
        currentUser?.role_code ?? ""
    }

    var userRoleName: String {
        currentUser?.role_name ?? "Неизвестная роль"
    }

    var userFullName: String {
        currentUser?.full_name ?? "Пользователь"
    }

    var permissions: [String] {
        currentUser?.permissions ?? []
    }

    var isAdmin: Bool {
        userRoleCode == "admin"
    }

    var isTeacher: Bool {
        userRoleCode == "teacher"
    }

    var isStudent: Bool {
        userRoleCode == "student"
    }

    var isParent: Bool {
        userRoleCode == "parent"
    }

    var isCook: Bool {
        userRoleCode == "cook"
    }

    var isManager: Bool {
        userRoleCode == "manager"
    }

    var isAdminOrManager: Bool {
        isAdmin || isManager
    }

    private func hasRole(_ roles: String...) -> Bool {
        roles.contains(userRoleCode)
    }

    // MARK: - Permissions
    //
    // Сервер присылает права как «раздел.действие» (finance.read, medical.manage,
    // messages.send). Поддерживаем и старый разделитель «:» и вид admin.<раздел>.
    // Правила ниже повторяют проверки бэкенда (app/routers/*): часть разделов сервер
    // пускает по праву (homework.manage, messages.send, events.manage), часть — только
    // по роли (финансы, документы, меню, медкарты, учебники, портфолио, объявления).
    // Если дать доступ по праву там, где сервер смотрит на роль, кнопка появится,
    // а сервер ответит 403.

    enum PermissionLevel {
        /// Любое право на раздел: read, manage, send…
        case read
        /// Право изменять: manage, create, update, delete…
        case manage
    }

    /// Меню на сервере проверяется как menu.*, в справочнике прав (app/permissions.py) — food.*.
    private static let permissionResourceAliases: [String: Set<String>] = [
        "menu": ["menu", "food"]
    ]

    private static let manageActions: Set<String> = [
        "manage", "create", "update", "delete", "write", "edit", "admin", "all", "*"
    ]

    private static func parsePermission(_ raw: String) -> (resource: String, action: String)? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ":", with: ".")
            .replacingOccurrences(of: "-", with: "_")

        guard !normalized.isEmpty else {
            return nil
        }

        let parts = normalized.split(separator: ".", maxSplits: 1).map(String.init)

        // admin.finance / admin:finance — управление разделом.
        if parts.count == 2 && parts[0] == "admin" {
            return (parts[1], "manage")
        }

        // Голое «finance» раньше означало полный доступ к разделу.
        return (parts[0], parts.count == 2 ? parts[1] : "manage")
    }

    /// Есть ли у пользователя право на раздел `resource` уровня `level`.
    /// `extraActions` — действия, которых тоже достаточно (например, send для сообщений).
    /// Можно передать и полный код права («clubs.manage», «finance:read», «admin.menu»):
    /// он разбирается так же, как права с сервера.
    func hasPermission(
        _ resource: String,
        level: PermissionLevel = .read,
        extraActions: Set<String> = []
    ) -> Bool {
        if resource.contains(".") || resource.contains(":") {
            guard let requested = Self.parsePermission(resource) else {
                return false
            }

            // «finance.read» — любое право на раздел; «clubs.manage»/«admin.clubs» — право
            // изменять; прочее («messages.send») — это действие или право изменять.
            if requested.action == "read" && level == .read {
                return hasPermission(requested.resource)
            }

            if Self.manageActions.contains(requested.action) {
                return hasPermission(requested.resource, level: .manage, extraActions: extraActions)
            }

            return hasPermission(
                requested.resource,
                level: .manage,
                extraActions: extraActions.union([requested.action])
            )
        }

        let names = Self.permissionResourceAliases[resource] ?? [resource]

        return permissions.contains { raw in
            guard let permission = Self.parsePermission(raw),
                  names.contains(permission.resource) else {
                return false
            }

            switch level {
            case .read:
                return true
            case .manage:
                return Self.manageActions.contains(permission.action)
                    || extraActions.contains(permission.action)
            }
        }
    }

    /// Хотя бы одно из прав. Коды в любом формате: «resource.action», «resource:action»,
    /// «admin.<resource>». Администратор проходит всегда.
    func hasAnyPermission(_ values: [String]) -> Bool {
        if isAdmin {
            return true
        }

        return values.contains { hasPermission($0) }
    }

    // MARK: - Teacher permissions (teacher.py)

    var canOpenTeacherCabinet: Bool {
        hasRole("admin", "teacher")
    }

    var canTeacherManageGrades: Bool {
        isAdmin || (isTeacher && hasPermission("grades", level: .manage))
    }

    var canTeacherManageHomework: Bool {
        isAdmin || (isTeacher && hasPermission("homework", level: .manage))
    }

    var canTeacherManageAttendance: Bool {
        isAdmin || (isTeacher && hasPermission("attendance", level: .manage))
    }

    var canTeacherManageFinalGrades: Bool {
        canTeacherManageGrades
    }

    // MARK: - Feature permissions

    /// homework.py: создание по праву homework.manage (одной роли учителя мало).
    var canManageHomework: Bool {
        isAdmin || hasPermission("homework", level: .manage)
    }

    /// events.py: управлять событиями могут admin/manager и учитель с правом events.manage.
    var canManageEvents: Bool {
        isAdmin || (hasRole("manager", "teacher") && hasAnyPermission([
            "events.manage",
            "events:manage",
            "events:create",
            "events:update",
            "events:delete",
            "admin:events"
        ]))
    }

    /// clubs.py: создавать и менять кружки могут admin/manager и учитель с правом clubs.manage.
    var canManageClubs: Bool {
        isAdmin || (hasRole("manager", "teacher") && hasAnyPermission([
            "clubs.manage",
            "clubs:manage",
            "clubs:create",
            "clubs:update",
            "clubs:delete",
            "admin:clubs"
        ]))
    }

    /// clubs.py _ensure_can_manage_club: учитель меняет, удаляет и записывает учеников только в свои кружки.
    func canManageClub(_ club: ClubDTO) -> Bool {
        if isAdmin || (isManager && canManageClubs) {
            return true
        }

        guard canManageClubs,
              let userID = currentUser?.id,
              let teacherUserID = club.teacher_user_id else {
            return false
        }

        return teacherUserID == userID
    }

    /// admin.py: расписание правят admin/manager.
    var canManageSchedule: Bool {
        isAdminOrManager
    }

    /// messages.py: отправка (в т. ч. рассылка) по праву messages.send.
    var canSendMessages: Bool {
        hasRole("admin", "manager", "teacher", "parent")
            || hasPermission("messages", level: .manage, extraActions: ["send"])
    }

    /// Рассылка нескольким адресатам — для сотрудников с правом отправки.
    var canSendBulkMessages: Bool {
        canSendMessages && hasRole("admin", "manager", "teacher")
    }

    /// messages.py: объявления — events.manage и роль admin/manager/teacher.
    var canCreateAnnouncements: Bool {
        isAdmin || (hasRole("manager", "teacher") && hasPermission("events", level: .manage))
    }

    /// finance.py: смотреть admin/manager/parent (ученику раздел не показываем).
    var canUseFinance: Bool {
        hasRole("admin", "manager", "parent")
    }

    /// finance.py: управлять — finance.manage и роль admin/manager; одного права мало.
    var canManageFinance: Bool {
        isAdmin || (isManager && hasPermission("finance", level: .manage))
    }

    var canSelfEnrollClubs: Bool {
        isParent
    }

    /// menu.py: menu.manage и роль admin/manager/cook.
    var canManageMenu: Bool {
        isAdmin || (hasRole("manager", "cook") && hasPermission("menu", level: .manage))
    }

    /// health.py: проверка только по роли (права medical.* сервер не смотрит).
    var canViewHealth: Bool {
        hasRole("admin", "manager", "teacher", "parent", "cook")
    }

    var canManageHealth: Bool {
        hasRole("admin", "manager", "teacher", "parent")
    }

    /// documents.py: все разделы документов требуют documents.read
    /// (по умолчанию есть у admin, manager, parent; у учителя и ученика нет).
    var canViewDocuments: Bool {
        isAdminOrManager || hasPermission("documents")
    }

    /// documents.py (_append_profile_access_filter): профили, ученики и сгенерированные
    /// документы — admin/manager все, parent/student свои, остальным ролям 403.
    var canReadDocumentProfiles: Bool {
        canViewDocuments && hasRole("admin", "manager", "parent", "student")
    }

    /// documents.py: documents.manage и роль admin/manager.
    var canManageDocuments: Bool {
        isAdmin || (isManager && hasPermission("documents", level: .manage))
    }

    /// textbooks.py: смотреть все, кроме повара; управлять admin/manager.
    var canViewTextbooks: Bool {
        currentUser != nil && !isCook
    }

    var canManageTextbooks: Bool {
        isAdminOrManager
    }

    /// portfolio.py: смотреть admin/manager/teacher/parent/student.
    var canUsePortfolio: Bool {
        hasRole("admin", "manager", "teacher", "parent", "student")
    }

    /// community_ads.py: смотреть admin/manager/teacher/parent, управлять admin/manager.
    var canViewCommunity: Bool {
        hasRole("admin", "manager", "teacher", "parent")
    }

    /// community_ads.py: school.manage и роль admin/manager.
    var canManageCommunity: Bool {
        isAdmin || (isManager && hasPermission("school", level: .manage))
    }

    /// Можно ли открыть раздел, в который ведёт уведомление. Иначе открываем
    /// список уведомлений, а не экран, который сервер отклонит 403.
    func canOpenPushRoute(_ route: PushRoute) -> Bool {
        switch route {
        case .finance:
            return canUseFinance
        case .health:
            return canViewHealth
        case .documents:
            return canViewDocuments
        case .textbooks:
            return canViewTextbooks
        case .portfolio:
            return canUsePortfolio
        case .community:
            return canViewCommunity
        default:
            return true
        }
    }
}