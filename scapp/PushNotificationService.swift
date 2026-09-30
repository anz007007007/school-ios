import Foundation
import Combine
import UserNotifications
import UIKit
import FirebaseMessaging
import SchoolAPIClient

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    private nonisolated static let pendingNotificationUserInfoStorageKey = "push.pending_notification_user_info"
    private nonisolated static let latestRemoteNotificationUserInfoStorageKey = "push.latest_remote_notification_user_info"

    nonisolated static func storeLatestRemoteNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        storePayload(
            userInfo,
            storageKey: latestRemoteNotificationUserInfoStorageKey,
            logMessage: "PUSH LATEST REMOTE NOTIFICATION STORED"
        )
    }

    nonisolated static func storePendingNotificationTapPayload(_ userInfo: [AnyHashable: Any]) {
        storePayload(
            userInfo,
            storageKey: pendingNotificationUserInfoStorageKey,
            logMessage: "PUSH PENDING NOTIFICATION STORED"
        )
    }

    private nonisolated static func storePayload(
        _ userInfo: [AnyHashable: Any],
        storageKey: String,
        logMessage: String
    ) {
        let sanitized = sanitizeDictionary(userInfo)

        guard JSONSerialization.isValidJSONObject(sanitized),
              let data = try? JSONSerialization.data(withJSONObject: sanitized) else {
            print("PUSH PAYLOAD STORE SKIPPED: invalid json")
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
        print(logMessage)
    }

    private nonisolated static func sanitizeDictionary(_ dictionary: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]

        for (key, value) in dictionary {
            result["\(key)"] = sanitizeValue(value)
        }

        return result
    }

    private nonisolated static func sanitizeValue(_ value: Any) -> Any {
        if let stringValue = value as? String {
            return stringValue
        }

        if let intValue = value as? Int {
            return intValue
        }

        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue
        }

        if let dictionaryValue = value as? [AnyHashable: Any] {
            return sanitizeDictionary(dictionaryValue)
        }

        if let dictionaryValue = value as? [String: Any] {
            return sanitizeDictionary(Dictionary(uniqueKeysWithValues: dictionaryValue.map { (AnyHashable($0.key), $0.value) }))
        }

        if let arrayValue = value as? [Any] {
            return arrayValue.map { sanitizeValue($0) }
        }

        return "\(value)"
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var apnsToken: String?
    @Published private(set) var fcmToken: String?
    @Published private(set) var badgeCount: Int = 0
    @Published private(set) var isRequestingPermission = false

    @Published var errorMessage: String?
    @Published var lastRegistrationMessage: String?

    private weak var currentAPI: SchoolAPI?
    weak var appState: AppState?

    private let deviceUIDStorageKey = "push.device_uid"
    private let lastRegisteredFCMTokenStorageKey = "push.last_registered_fcm_token"

    private var lastRegisteredFCMToken: String?
    private var isRegisteringDevice = false
    private var isRefreshingFCMToken = false
    private var isRefreshingBadge = false
    private var isAttached = false

    private var hasAPNSToken = false
    private var isWaitingForFreshFCMTokenAfterAPNS = false
    private var didCreateFreshFCMTokenAfterAPNS = false

    private var pendingNotificationTapUserInfo: [AnyHashable: Any]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.pendingNotificationUserInfoStorageKey),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return dict
        }
        set {
            if let newValue = newValue as? [String: Any],
               JSONSerialization.isValidJSONObject(newValue),
               let data = try? JSONSerialization.data(withJSONObject: newValue) {
                UserDefaults.standard.set(data, forKey: Self.pendingNotificationUserInfoStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.pendingNotificationUserInfoStorageKey)
            }
        }
    }

    private var latestRemoteNotificationUserInfo: [AnyHashable: Any]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.latestRemoteNotificationUserInfoStorageKey),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return dict
        }
        set {
            if let newValue = newValue as? [String: Any],
               JSONSerialization.isValidJSONObject(newValue),
               let data = try? JSONSerialization.data(withJSONObject: newValue) {
                UserDefaults.standard.set(data, forKey: Self.latestRemoteNotificationUserInfoStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.latestRemoteNotificationUserInfoStorageKey)
            }
        }
    }

    private override init() {
        lastRegisteredFCMToken = UserDefaults.standard.string(forKey: lastRegisteredFCMTokenStorageKey)
        super.init()
    }

    // MARK: - Public Properties

    var currentDeviceUID: String {
        deviceUID
    }

    // MARK: - Configuration

    func configure() {
        UNUserNotificationCenter.current().delegate = self

        Task {
            await refreshAuthorizationStatus()

            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("PUSH AUTH STATUS:", settings.authorizationStatus.rawValue)

            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral {
                lastRegistrationMessage = "Уведомления разрешены. Запрашиваем APNs token."
                print("PUSH REGISTER FOR REMOTE NOTIFICATIONS FROM CONFIGURE")
                UIApplication.shared.registerForRemoteNotifications()
            } else if settings.authorizationStatus == .notDetermined {
                lastRegistrationMessage = "Разрешение ещё не запрошено."
                print("PUSH AUTH NOT DETERMINED")
            } else {
                lastRegistrationMessage = "Уведомления запрещены в настройках iOS."
                print("PUSH AUTH DENIED")
            }
        }
    }

    func attach(api: SchoolAPI) {
        currentAPI = api

        Task {
            await refreshBadge(api: api)

            if let fcmToken, !fcmToken.isEmpty {
                await registerDeviceIfPossible(api: api, force: true)
            }
        }

        guard !isAttached else {
            print("PUSH ATTACH: already attached")

            Task {
                await ensurePushRegistration(api: api)
            }

            return
        }

        isAttached = true

        guard hasAPNSToken else {
            print("PUSH ATTACH: API attached, waiting for APNs token")
            lastRegistrationMessage = "API подключён. Ждём APNs token."

            if let fcmToken, !fcmToken.isEmpty {
                Task {
                    await registerDeviceIfPossible(api: api, force: true)
                }
            }

            return
        }

        guard didCreateFreshFCMTokenAfterAPNS else {
            print("PUSH ATTACH: waiting for fresh FCM token after APNS")
            refreshFCMToken()
            return
        }

        Task {
            await registerDeviceIfPossible(api: api, force: true)
        }
    }

    func ensurePushRegistration(api: SchoolAPI) async {
        currentAPI = api
        errorMessage = nil

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .notDetermined:
            lastRegistrationMessage = "Разрешение на push ещё не запрошено. Запрашиваем разрешение."
            print("PUSH PERMISSION NOT DETERMINED: requesting permission")

            await requestPermissionAndRegister()

        case .authorized, .provisional, .ephemeral:
            lastRegistrationMessage = "Push разрешены. Проверяем регистрацию устройства."
            print("PUSH AUTHORIZED: register for remote notifications")

            UIApplication.shared.registerForRemoteNotifications()

            if let fcmToken, !fcmToken.isEmpty {
                await registerDeviceIfPossible(api: api, force: true)
            } else {
                refreshFCMToken()
            }

            await refreshBadge(api: api)

        case .denied:
            lastRegistrationMessage = "Push запрещены в настройках iOS."
            print("PUSH AUTH DENIED")
            await setBadgeCount(0)

        @unknown default:
            lastRegistrationMessage = "Неизвестный статус разрешения push."
        }
    }

    func requestPermissionAndRegister() async {
        guard !isRequestingPermission else {
            print("PUSH PERMISSION SKIPPED: already requesting")
            return
        }

        isRequestingPermission = true
        errorMessage = nil
        lastRegistrationMessage = nil

        defer {
            isRequestingPermission = false
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if settings.authorizationStatus == .denied {
            lastRegistrationMessage = "Push запрещены в настройках iOS."
            errorMessage = "Уведомления запрещены. Разрешите их в настройках iOS."
            print("PUSH PERMISSION SKIPPED: denied")
            return
        }

        if settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral {
            lastRegistrationMessage = "Уведомления уже разрешены. Запрашиваем APNs token."
            print("PUSH PERMISSION ALREADY GRANTED")

            UIApplication.shared.registerForRemoteNotifications()

            if let currentAPI {
                if let fcmToken, !fcmToken.isEmpty {
                    await registerDeviceIfPossible(api: currentAPI, force: true)
                } else {
                    refreshFCMToken()
                }

                await refreshBadge(api: currentAPI)
            }

            return
        }

        print("PUSH PERMISSION REQUEST START")

        let result = await requestNotificationAuthorizationUsingCallback()

        await refreshAuthorizationStatus()

        switch result {
        case .success(let granted):
            if granted {
                lastRegistrationMessage = "Разрешение получено. Запрашиваем APNs token."
                print("PUSH PERMISSION GRANTED")
                print("PUSH REGISTER FOR REMOTE NOTIFICATIONS AFTER PERMISSION")

                UIApplication.shared.registerForRemoteNotifications()

                if let currentAPI {
                    if let fcmToken, !fcmToken.isEmpty {
                        await registerDeviceIfPossible(api: currentAPI, force: true)
                    } else {
                        refreshFCMToken()
                    }

                    await refreshBadge(api: currentAPI)
                }
            } else {
                errorMessage = "Пользователь не разрешил push-уведомления."
                lastRegistrationMessage = "Пользователь не разрешил push-уведомления."
                print("PUSH PERMISSION DENIED BY USER")
            }

        case .failure(let error):
            errorMessage = "Не удалось запросить разрешение на уведомления: \(error.localizedDescription)"
            lastRegistrationMessage = "Ошибка запроса разрешения push: \(error.localizedDescription)"
            print("PUSH PERMISSION ERROR:", error.localizedDescription)

            if let currentAPI, let fcmToken, !fcmToken.isEmpty {
                print("PUSH PERMISSION ERROR FALLBACK: device already has FCM, registering on server")
                await registerDeviceIfPossible(api: currentAPI, force: true)
            }
        }
    }

    private func requestNotificationAuthorizationUsingCallback() async -> Result<Bool, Error> {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            ) { granted, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(granted))
                }
            }
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - APNs

    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()

        apnsToken = token
        hasAPNSToken = true
        didCreateFreshFCMTokenAfterAPNS = false
        isWaitingForFreshFCMTokenAfterAPNS = true
        lastRegisteredFCMToken = UserDefaults.standard.string(forKey: lastRegisteredFCMTokenStorageKey)

        lastRegistrationMessage = "APNs token получен. Обновляем FCM token."
        print("PUSH APNS TOKEN:", token)

        resetAndRefreshFCMTokenAfterAPNS()
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        errorMessage = "Не удалось зарегистрировать устройство для push: \(error.localizedDescription)"
        lastRegistrationMessage = "APNs регистрация не удалась: \(error.localizedDescription)"
        print("PUSH APNS REGISTER ERROR:", error.localizedDescription)

        if let currentAPI, let fcmToken, !fcmToken.isEmpty {
            Task {
                await registerDeviceIfPossible(api: currentAPI, force: true)
            }
        }
    }

    // MARK: - FCM

    func didReceiveFCMTokenFromDelegate(_ token: String?) {
        guard let token, !token.isEmpty else {
            lastRegistrationMessage = "Firebase прислал пустой FCM token."
            print("PUSH FCM TOKEN EMPTY FROM DELEGATE")
            return
        }

        fcmToken = token
        didCreateFreshFCMTokenAfterAPNS = hasAPNSToken
        isWaitingForFreshFCMTokenAfterAPNS = false

        lastRegistrationMessage = "FCM token получен: \(token.prefix(16))..."
        print("PUSH FCM TOKEN ACCEPTED:", token)

        if let currentAPI {
            Task {
                await registerDeviceIfPossible(api: currentAPI, force: true)
                await refreshBadge(api: currentAPI)
            }
        }
    }

    func didReceiveFCMToken(_ token: String?) {
        didReceiveFCMTokenFromDelegate(token)
    }

    func refreshFCMToken() {
        guard hasAPNSToken else {
            lastRegistrationMessage = "APNs token ещё не получен. Используем FCM token из Firebase delegate."
            print("PUSH FCM REFRESH SKIPPED: no APNs token")

            if let fcmToken, !fcmToken.isEmpty, let currentAPI {
                Task {
                    await registerDeviceIfPossible(api: currentAPI, force: true)
                }
            } else {
                UIApplication.shared.registerForRemoteNotifications()
            }

            return
        }

        guard didCreateFreshFCMTokenAfterAPNS else {
            resetAndRefreshFCMTokenAfterAPNS()
            return
        }

        requestFCMToken()
    }

    func resetAndRefreshFCMTokenAfterAPNS() {
        guard hasAPNSToken else {
            lastRegistrationMessage = "Нет APNs token — FCM token не пересоздаём."
            print("PUSH FCM RESET SKIPPED: no APNs token")
            return
        }

        guard !isRefreshingFCMToken else {
            print("PUSH FCM RESET SKIPPED: already refreshing")
            return
        }

        isRefreshingFCMToken = true
        isWaitingForFreshFCMTokenAfterAPNS = true
        didCreateFreshFCMTokenAfterAPNS = false
        errorMessage = nil

        print("PUSH FCM DELETE TOKEN START")

        Messaging.messaging().deleteToken { [weak self] error in
            guard let service = self else {
                return
            }

            Task { @MainActor in
                if let error {
                    service.isRefreshingFCMToken = false
                    service.errorMessage = "Не удалось удалить старый FCM token: \(error.localizedDescription)"
                    service.lastRegistrationMessage = "Не удалось удалить старый FCM token."
                    print("PUSH FCM DELETE TOKEN ERROR:", error.localizedDescription)
                    return
                }

                service.fcmToken = nil
                service.lastRegisteredFCMToken = UserDefaults.standard.string(forKey: service.lastRegisteredFCMTokenStorageKey)
                service.lastRegistrationMessage = "Старый FCM token удалён. Запрашиваем новый."
                print("PUSH FCM DELETE TOKEN OK")

                service.requestFCMToken()
            }
        }
    }

    private func requestFCMToken() {
        print("PUSH FCM TOKEN REQUEST START")

        Messaging.messaging().token { [weak self] token, error in
            guard let service = self else {
                return
            }

            Task { @MainActor in
                service.isRefreshingFCMToken = false

                if let error {
                    service.errorMessage = "Не удалось получить FCM token: \(error.localizedDescription)"
                    service.lastRegistrationMessage = "Не удалось получить FCM token."
                    print("PUSH FCM TOKEN REQUEST ERROR:", error.localizedDescription)
                    return
                }

                service.didReceiveFreshFCMTokenAfterAPNS(token)
            }
        }
    }

    private func didReceiveFreshFCMTokenAfterAPNS(_ token: String?) {
        guard let token, !token.isEmpty else {
            lastRegistrationMessage = "FCM token пока не получен."
            print("PUSH FCM TOKEN EMPTY")
            return
        }

        fcmToken = token
        didCreateFreshFCMTokenAfterAPNS = hasAPNSToken
        isWaitingForFreshFCMTokenAfterAPNS = false

        lastRegistrationMessage = "Новый FCM token получен: \(token.prefix(16))..."
        print("PUSH FCM TOKEN:", token)

        if let currentAPI {
            Task {
                await registerDeviceIfPossible(api: currentAPI, force: true)
                await refreshBadge(api: currentAPI)
            }
        }
    }

    // MARK: - Server Registration

    func registerDeviceIfPossible(api: SchoolAPI, force: Bool = false) async {
        currentAPI = api
        errorMessage = nil

        guard !isRegisteringDevice else {
            print("PUSH REGISTER SKIPPED: already registering")
            return
        }

        guard let fcmToken, !fcmToken.isEmpty else {
            lastRegistrationMessage = "FCM token ещё не получен."
            print("PUSH REGISTER SKIPPED: no FCM token")
            refreshFCMToken()
            return
        }

        if !hasAPNSToken {
            lastRegistrationMessage = "APNs token ещё не получен, регистрируем устройство по FCM token."
            print("PUSH REGISTER CONTINUE: no APNs token, using FCM token")
        }

        if !force, lastRegisteredFCMToken == fcmToken {
            lastRegistrationMessage = "FCM token уже отправлен на сервер."
            print("PUSH REGISTER SKIPPED: token already registered")
            return
        }

        isRegisteringDevice = true

        do {
            let body: [String: Any] = [
                "platform": "ios",
                "device_token": fcmToken,
                "device_uid": deviceUID,
                "environment": apnsEnvironment,
                "apns_environment": apnsEnvironment
            ]

            print("PUSH DEVICE REGISTER BODY:", body)

            let response = try await APIRequestService.shared.decode(
                PushDeviceRegisterResponseDTO.self,
                api: api,
                path: "/api/v1/push/devices",
                method: "POST",
                body: body,
                logPrefix: "PUSH DEVICE REGISTER"
            )

            lastRegisteredFCMToken = fcmToken
            UserDefaults.standard.set(fcmToken, forKey: lastRegisteredFCMTokenStorageKey)
            lastRegistrationMessage = "FCM token отправлен на сервер. device_id: \(response.push_device_id?.description ?? "-")"

            await refreshBadge(api: api)
        } catch {
            errorMessage = "Не удалось отправить FCM token на сервер: \(error.localizedDescription)"
            lastRegistrationMessage = "Не удалось зарегистрировать устройство на сервере."
            print("PUSH DEVICE REGISTER ERROR:", error.localizedDescription)
        }

        isRegisteringDevice = false
    }

    func unregisterCurrentDevice(api: SchoolAPI) async {
        guard let fcmToken else {
            return
        }

        do {
            let response = try await APIRequestService.shared.decode(
                PushDevicesListResponseDTO.self,
                api: api,
                path: "/api/v1/push/devices",
                method: "GET",
                logPrefix: "PUSH DEVICES"
            )

            let currentDevice = response.items.first { device in
                device.device_token == fcmToken || device.device_uid == deviceUID
            }

            guard let currentDevice else {
                return
            }

            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/push/devices/\(currentDevice.id)/disable",
                method: "PATCH",
                logPrefix: "PUSH DEVICE DISABLE"
            )

            lastRegisteredFCMToken = nil
            UserDefaults.standard.removeObject(forKey: lastRegisteredFCMTokenStorageKey)
            lastRegistrationMessage = "FCM token отключён на сервере."
            await setBadgeCount(0)
        } catch {
            errorMessage = "Не удалось отключить push для устройства: \(error.localizedDescription)"
        }
    }

    // MARK: - Badge

    func refreshBadgeAfterNotificationStateChange(api: SchoolAPI) async {
        await refreshBadge(api: api)
    }

    func refreshBadgeFromCurrentAPI() async {
        guard let currentAPI else {
            return
        }

        await refreshBadge(api: currentAPI)
    }

    func refreshBadge(api: SchoolAPI) async {
        guard !isRefreshingBadge else {
            return
        }

        isRefreshingBadge = true

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationsListResponseDTO.self,
                api: api,
                path: "/api/v1/push/notifications",
                method: "GET",
                logPrefix: "PUSH BADGE"
            )

            await setBadgeCount(response.unread_count)
            await appState?.refreshUnreadNotificationsBySection()
        } catch {
            print("PUSH BADGE REFRESH ERROR:", error.localizedDescription)
        }

        isRefreshingBadge = false
    }

    func setBadgeCount(_ value: Int) async {
        let safeValue = max(value, 0)

        await MainActor.run {
            badgeCount = safeValue
        }

        if #available(iOS 16.0, *) {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(safeValue)
            } catch {
                print("PUSH SET BADGE ERROR:", error.localizedDescription)
            }
        } else {
            await MainActor.run {
                setLegacyApplicationBadgeNumber(safeValue)
            }
        }

        print("PUSH BADGE SET:", safeValue)
    }

    @available(iOS, deprecated: 17.0)
    private func setLegacyApplicationBadgeNumber(_ value: Int) {
        UIApplication.shared.applicationIconBadgeNumber = value
    }

    // MARK: - Notification Routing

    func storeLatestRemoteNotification(userInfo: [AnyHashable: Any]) {
        latestRemoteNotificationUserInfo = userInfo
        print("PUSH LATEST REMOTE NOTIFICATION STORED")
    }

    func clearLatestRemoteNotification() {
        latestRemoteNotificationUserInfo = nil
    }

    func latestRemoteNotificationRoute() -> PushRoute? {
        guard let latestRemoteNotificationUserInfo else {
            return nil
        }

        let notificationID = extractInt(
            from: latestRemoteNotificationUserInfo,
            keys: [
                "notification_id",
                "notificationId",
                "push_notification_id",
                "pushNotificationId",
                "app_notification_id",
                "appNotificationId",
                "id",
                "notification.id",
                "data.notification_id"
            ]
        )

        let routeValues = extractRouteValues(from: latestRemoteNotificationUserInfo)

        return PushRoute.route(
            values: routeValues,
            notificationID: notificationID
        )
    }

    func storePendingNotificationTap(userInfo: [AnyHashable: Any]) {
        pendingNotificationTapUserInfo = userInfo
        print("PUSH PENDING NOTIFICATION STORED")
    }

    func processPendingNotificationTapIfNeeded() async {
        guard let pendingNotificationTapUserInfo = pendingNotificationTapUserInfo else {
            return
        }

        self.pendingNotificationTapUserInfo = nil
        print("PUSH PROCESSING PENDING NOTIFICATION")
        await handleNotificationTap(userInfo: pendingNotificationTapUserInfo)
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        print("PUSH TAP USER INFO:", userInfo)

        let notificationID = extractInt(
            from: userInfo,
            keys: [
                "notification_id",
                "notificationId",
                "push_notification_id",
                "pushNotificationId",
                "app_notification_id",
                "appNotificationId",
                "id",
                "notification.id",
                "data.notification_id"
            ]
        )

        let routeValues = extractRouteValues(from: userInfo)

        let route = PushRoute.route(
            values: routeValues,
            notificationID: notificationID
        )

        print("PUSH ROUTE RESULT:", route)

        appState?.openPushRoute(route)

        if let currentAPI {
            await refreshBadge(api: currentAPI)
            await appState?.refreshUnreadNotificationsBySection()
        }
    }

    private func extractRouteValues(from userInfo: [AnyHashable: Any]) -> [String] {
        var values: [String] = []

        let directKeys = [
            "section_code",
            "sectionCode",
            "section",
            "target",
            "target_section",
            "targetSection",
            "module",
            "screen",
            "route",
            "deeplink",
            "deep_link",
            "url",
            "notification_type",
            "notificationType",
            "type",
            "event_type",
            "eventType",
            "category",
            "click_action",
            "title",
            "body",
            "message"
        ]

        values.append(contentsOf: extractStrings(from: userInfo, keys: directKeys))

        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            values.append(contentsOf: extractStrings(from: aps, keys: directKeys))

            if let alert = aps["alert"] as? [AnyHashable: Any] {
                values.append(contentsOf: extractStrings(
                    from: alert,
                    keys: [
                        "title",
                        "subtitle",
                        "body",
                        "loc-key",
                        "loc-args"
                    ]
                ))
            } else if let alertText = aps["alert"] as? String {
                values.append(alertText)
            }

            if let category = aps["category"] as? String {
                values.append(category)
            }
        }

        if let data = userInfo["data"] as? [AnyHashable: Any] {
            values.append(contentsOf: extractStrings(from: data, keys: directKeys))
            values.append(contentsOf: flattenStringValues(from: data))
        }

        values.append(contentsOf: flattenStringValues(from: userInfo))

        return Array(Set(values))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func extractStrings(from userInfo: [AnyHashable: Any], keys: [String]) -> [String] {
        var values: [String] = []

        for key in keys {
            if let value = userInfo[key] as? String {
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

                if !clean.isEmpty {
                    values.append(clean)
                }
            } else if let value = userInfo[key] {
                let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)

                if !clean.isEmpty && clean != "<null>" {
                    values.append(clean)
                }
            }
        }

        return values
    }

    private func flattenStringValues(from dictionary: [AnyHashable: Any]) -> [String] {
        var values: [String] = []

        for (_, value) in dictionary {
            if let stringValue = value as? String {
                let clean = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if !clean.isEmpty {
                    values.append(clean)
                }
            } else if let nestedDictionary = value as? [AnyHashable: Any] {
                values.append(contentsOf: flattenStringValues(from: nestedDictionary))
            } else if let nestedArray = value as? [Any] {
                for item in nestedArray {
                    if let stringItem = item as? String {
                        let clean = stringItem.trimmingCharacters(in: .whitespacesAndNewlines)

                        if !clean.isEmpty {
                            values.append(clean)
                        }
                    } else if let nestedItemDictionary = item as? [AnyHashable: Any] {
                        values.append(contentsOf: flattenStringValues(from: nestedItemDictionary))
                    }
                }
            } else {
                let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)

                if !clean.isEmpty && clean != "<null>" {
                    values.append(clean)
                }
            }
        }

        return values
    }

    // MARK: - Int Extraction

    private func extractInt(from userInfo: [AnyHashable: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = extractIntValue(userInfo[key]) {
                return value
            }
        }

        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            for key in keys {
                if let value = extractIntValue(aps[key]) {
                    return value
                }
            }
        }

        if let data = userInfo["data"] as? [AnyHashable: Any] {
            for key in keys {
                if let value = extractIntValue(data[key]) {
                    return value
                }
            }
        }

        return findFirstIntValue(
            in: userInfo,
            matchingKeys: [
                "notification_id",
                "notificationid",
                "push_notification_id",
                "pushnotificationid",
                "app_notification_id",
                "appnotificationid"
            ]
        )
    }

    private func extractIntValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }

        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }

        if let stringValue = value as? String {
            let clean = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if let intValue = Int(clean) {
                return intValue
            }
        }

        return nil
    }

    private func findFirstIntValue(
        in dictionary: [AnyHashable: Any],
        matchingKeys: Set<String>
    ) -> Int? {
        for (key, value) in dictionary {
            let normalizedKey = "\(key)"
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: ".", with: "_")

            if matchingKeys.contains(normalizedKey),
               let intValue = extractIntValue(value) {
                return intValue
            }

            if let nestedDictionary = value as? [AnyHashable: Any],
               let intValue = findFirstIntValue(in: nestedDictionary, matchingKeys: matchingKeys) {
                return intValue
            }

            if let nestedArray = value as? [Any] {
                for item in nestedArray {
                    if let nestedDictionary = item as? [AnyHashable: Any],
                       let intValue = findFirstIntValue(in: nestedDictionary, matchingKeys: matchingKeys) {
                        return intValue
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Private Properties

    private var deviceUID: String {
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString, !vendorID.isEmpty {
            return vendorID
        }

        if let storedUID = UserDefaults.standard.string(forKey: deviceUIDStorageKey), !storedUID.isEmpty {
            return storedUID
        }

        let newUID = "ios-\(UUID().uuidString)"
        UserDefaults.standard.set(newUID, forKey: deviceUIDStorageKey)
        return newUID
    }

    private var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        DispatchQueue.global(qos: .utility).async {
            PushNotificationService.storeLatestRemoteNotificationPayload(userInfo)

            DispatchQueue.main.async {
                completionHandler([.banner, .sound, .badge, .list])
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        DispatchQueue.global(qos: .userInitiated).async {
            PushNotificationService.storePendingNotificationTapPayload(userInfo)

            DispatchQueue.main.async {
                completionHandler()
                AuthSessionEvents.notifyPushNotificationTapStored()
            }
        }
    }
}