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
    @Published private(set) var unreadNotificationsBySection: [String: Int] = [:]
    @Published private(set) var tabReselectToken: [MainTabSelection: Int] = [:]

    let api = SchoolAPI(
        baseURL: URL(string: "https://sc.it-status.ru/")!
    )

    private var cancellables = Set<AnyCancellable>()

    init() {
        PushNotificationService.shared.appState = self

        NotificationCenter.default.publisher(for: .authSessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleSessionExpired()
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
        guard isAuthenticated else {
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

        guard LoginSecurityService.shared.rememberLogin else {
            await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
            return
        }

        do {
            guard let credentials = try LoginSecurityService.shared.loadCredentials() else {
                await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
                return
            }

            isLoading = true
            errorMessage = nil

            _ = try await api.login(
                login: credentials.login,
                password: credentials.password
            )

            currentUser = try await api.getCurrentUser()
            isAuthenticated = true

            await refreshMobileConfigFeatures()
            await refreshUnreadNotificationsBySection()

            await registerPushNotificationsIfNeeded()

            await PushNotificationService.shared.processPendingNotificationTapIfNeeded()

            if let pushRoute {
                await markPushNotificationReadIfNeeded(pushRoute.notificationID)
            }
        } catch {
            errorMessage = "Не удалось восстановить вход: \(readableLoginError(error))"
            isAuthenticated = false
            unreadNotificationsBySection = [:]
            await PushNotificationService.shared.processPendingNotificationTapIfNeeded()
        }

        isLoading = false
    }

    func openPushRoute(_ route: PushRoute) {
        #if DEBUG
        print("PUSH OPEN ROUTE:", route.sectionKey, "notificationID:", route.notificationID as Any)
        #endif

        pushRoute = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            #if DEBUG
            print("PUSH SET ROUTE:", route.sectionKey)
            #endif
            self?.pushRoute = route
        }

        guard isAuthenticated else {
            return
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

        do {
            _ = try await api.login(
                login: login,
                password: password
            )

            currentUser = try await api.getCurrentUser()
            isAuthenticated = true

            await refreshMobileConfigFeatures()
            await refreshUnreadNotificationsBySection()

            await registerPushNotificationsIfNeeded()

            await PushNotificationService.shared.processPendingNotificationTapIfNeeded()

            if let pushRoute {
                await markPushNotificationReadIfNeeded(pushRoute.notificationID)
            }
        } catch {
            errorMessage = readableLoginError(error)
            isAuthenticated = false
            unreadNotificationsBySection = [:]
        }

        isLoading = false
    }

    func refreshCurrentUser() async {
        do {
            currentUser = try await api.getCurrentUser()
            isAuthenticated = true

            await refreshMobileConfigFeatures()
            await refreshUnreadNotificationsBySection()
        } catch {
            if isUnauthorizedError(error) {
                handleSessionExpired()
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
                handleSessionExpired()
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
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
        pushNotificationsFeatureEnabled = true
        unreadNotificationsBySection = [:]
    }

    func handleSessionExpired() {
        guard isAuthenticated else {
            return
        }

        isAuthenticated = false
        currentUser = nil
        pushNotificationsFeatureEnabled = true
        unreadNotificationsBySection = [:]
        errorMessage = "Сессия истекла. Войдите снова."
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

    func hasPermission(_ permission: String) -> Bool {
        isAdmin || permissions.contains(permission)
    }

    func hasAnyPermission(_ values: [String]) -> Bool {
        if isAdmin {
            return true
        }

        return values.contains { permissions.contains($0) }
    }

    // MARK: - Teacher permissions

    var canOpenTeacherCabinet: Bool {
        isAdmin || isTeacher || hasAnyPermission([
            "teacher:classes",
            "teacher:subjects",
            "teacher:students",
            "teacher:grades",
            "teacher:homework",
            "teacher:attendance",
            "teacher:gradebook",
            "teacher:schedule",
            "admin:teachers",
            "admin:grades"
        ])
    }

    var canTeacherManageGrades: Bool {
        isAdmin || isTeacher || hasAnyPermission([
            "grades.manage",
            "teacher:grades",
            "grades:create",
            "grades:delete",
            "admin:grades"
        ])
    }

    var canTeacherManageHomework: Bool {
        isAdmin || hasAnyPermission([
            "teacher:homework",
            "homework:create",
            "homework:delete",
            "admin:homework"
        ])
    }

    var canTeacherManageAttendance: Bool {
        isAdmin || hasAnyPermission([
            "teacher:attendance",
            "attendance:create",
            "admin:attendance"
        ])
    }

    var canTeacherManageFinalGrades: Bool {
        isAdmin || isTeacher || hasAnyPermission([
            "grades.manage",
            "teacher:grades",
            "teacher:gradebook",
            "teacher:final-grades",
            "final-grades:create",
            "final-grades:update",
            "admin:grades"
        ])
    }

    // MARK: - Feature permissions

    var canManageHomework: Bool {
        hasAnyPermission([
            "homework:create",
            "homework:update",
            "homework:delete",
            "teacher:homework",
            "admin:homework"
        ])
    }

    /// events.py: управлять событиями могут admin/manager и учитель с правом events.manage.
    var canManageEvents: Bool {
        isAdmin || isManager || (isTeacher && hasAnyPermission([
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
        isAdmin || isManager || (isTeacher && hasAnyPermission([
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
        if isAdmin || isManager {
            return true
        }

        guard canManageClubs,
              let userID = currentUser?.id,
              let teacherUserID = club.teacher_user_id else {
            return false
        }

        return teacherUserID == userID
    }

    var canManageSchedule: Bool {
        hasAnyPermission([
            "schedule:create",
            "schedule:update",
            "schedule:delete",
            "admin:schedule"
        ])
    }

    var canSendMessages: Bool {
        isAdmin
        || isTeacher
        || isParent
        || isStudent
        || hasAnyPermission([
            "messages:send",
            "messages:create",
            "admin:messages",
            "teacher:messages"
        ])
    }

    var canUseFinance: Bool {
        !isStudent
        && (
            isAdmin
            || isManager
            || isParent
            || hasAnyPermission([
                "finance:view",
                "finance:read",
                "finance:create",
                "finance:update",
                "finance:delete",
                "payments:create",
                "payments:update",
                "payments:delete",
                "admin:finance"
            ])
        )
    }

    var canSelfEnrollClubs: Bool {
        isParent
    }

    var canManageMenu: Bool {
        isCook || isManager || hasAnyPermission([
            "menu:create",
            "menu:update",
            "menu:delete",
            "menu:dishes",
            "menu:week",
            "admin:menu"
        ])
    }

    var canViewHealth: Bool {
        isAdmin
        || isManager
        || isParent
        || isCook
        || hasAnyPermission([
            "health:view",
            "health:read",
            "health:cards",
            "medical:health",
            "admin:health"
        ])
    }

    var canManageHealth: Bool {
        !isCook
        && (
            isManager
            || isParent
            || hasAnyPermission([
                "health:create",
                "health:update",
                "health:delete",
                "health:cards",
                "medical:health",
                "admin:health"
            ])
        )
    }

    /// Документы (routers/documents.py): управлять могут только admin/manager
    /// (_ensure_can_manage_documents), право по permission тут не помогает — сервер ответит 403.
    var canManageDocuments: Bool {
        isAdmin || isManager
    }

    /// Профили, ученики и сгенерированные документы (_append_profile_access_filter):
    /// admin/manager — все, parent/student — свои, остальным ролям сервер отвечает 403.
    /// Публичные документы доступны всем.
    var canReadDocumentProfiles: Bool {
        isAdmin || isManager || isParent || isStudent
    }

    var canViewTextbooks: Bool {
        isAdmin
        || isManager
        || isTeacher
        || isParent
        || isStudent
        || hasAnyPermission([
            "textbooks:view",
            "textbooks:read",
            "admin:textbooks"
        ])
    }

    var canManageTextbooks: Bool {
        isAdmin
        || isManager
        || hasAnyPermission([
            "textbooks:create",
            "textbooks:update",
            "textbooks:delete",
            "textbooks:manage",
            "admin:textbooks"
        ])
    }

    var canManageFinance: Bool {
        !isStudent
        && (
            isManager
            || hasAnyPermission([
                "finance:create",
                "finance:update",
                "finance:delete",
                "payments:create",
                "payments:update",
                "payments:delete",
                "admin:finance"
            ])
        )
    }
}