import SwiftUI
import UserNotifications
import UIKit
import SchoolAPIClient

struct NotificationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var pushService = PushNotificationService.shared

    @State private var settings: [NotificationSettingDTO] = []
    @State private var devices: [PushDeviceDTO] = []

    @State private var isLoadingSettings = false
    @State private var isLoadingDevices = false
    @State private var isSaving = false
    @State private var disablingDeviceID: Int?

    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            deviceStatusSection

            devicesSection

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }

            if let errorMessage {
                Section {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.danger)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            notificationSectionsSection

            saveSection
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInitialData()
        }
        .refreshable {
            await refreshData()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoadingSettings || isLoadingDevices || isSaving)
            }
        }
    }

    // MARK: - Device status

    private var deviceStatusSection: some View {
        Section("Статус") {
            if !appState.pushNotificationsFeatureEnabled {
                Label("Push-уведомления отключены сервером", systemImage: "bell.slash.fill")
                    .foregroundStyle(AppTheme.warning)

                Text("Настройки разделов можно просмотреть, но регистрация устройства сейчас отключена в конфигурации приложения.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                authorizationStatusView

                if let message = pushService.lastRegistrationMessage,
                   !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                if let pushError = pushService.errorMessage,
                   !pushError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Ошибка push", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warning)

                    Text(pushError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var authorizationStatusView: some View {
        switch pushService.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Уведомления разрешены", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)

            Text("Это устройство может получать push-уведомления.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await pushService.ensurePushRegistration(api: appState.api)
                    await pushService.refreshAuthorizationStatus()
                    await loadDevices()
                }
            } label: {
                Label("Проверить регистрацию", systemImage: "arrow.clockwise")
            }
            .tint(AppTheme.control)

        case .denied:
            Label("Уведомления запрещены в iOS", systemImage: "xmark.circle.fill")
                .foregroundStyle(AppTheme.danger)

            Text("Откройте настройки iOS и разрешите уведомления для приложения.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                openSystemSettings()
            } label: {
                Label("Открыть настройки iOS", systemImage: "gearshape.fill")
            }
            .tint(AppTheme.control)

        case .notDetermined:
            Label("Разрешение ещё не запрошено", systemImage: "bell.badge.fill")
                .foregroundStyle(AppTheme.warning)

            Text("Нажмите кнопку ниже, чтобы iOS показала системный запрос разрешения на уведомления.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await pushService.requestPermissionAndRegister()
                    await pushService.refreshAuthorizationStatus()
                    await loadDevices()
                }
            } label: {
                if pushService.isRequestingPermission {
                    HStack {
                        ProgressView()
                        Text("Запрашиваем разрешение...")
                    }
                } else {
                    Label("Разрешить push-уведомления", systemImage: "bell.badge.fill")
                }
            }
            .disabled(pushService.isRequestingPermission)
            .tint(AppTheme.control)

        @unknown default:
            Text("Неизвестный статус уведомлений")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        Section("Устройства") {
            if isLoadingDevices {
                HStack {
                    Spacer()
                    ProgressView("Загрузка устройств...")
                    Spacer()
                }
            } else if devices.isEmpty {
                Text("Зарегистрированные устройства не найдены.")
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await pushService.ensurePushRegistration(api: appState.api)
                        await loadDevices()
                    }
                } label: {
                    Label("Зарегистрировать это устройство", systemImage: "iphone")
                }
                .tint(AppTheme.control)
            } else {
                ForEach(devices) { device in
                    PushDeviceSettingsRowView(
                        device: device,
                        isCurrent: isCurrentDevice(device),
                        isDisabling: disablingDeviceID == device.id,
                        onDisable: {
                            Task {
                                await disableDevice(device)
                            }
                        }
                    )
                }
            }

            Button {
                Task {
                    await loadDevices()
                }
            } label: {
                Label("Обновить список устройств", systemImage: "arrow.clockwise")
            }
            .disabled(isLoadingDevices)
        }
    }

    private func isCurrentDevice(_ device: PushDeviceDTO) -> Bool {
        device.device_uid == PushNotificationService.shared.currentDeviceUID
    }

    // MARK: - Notification sections

    private var notificationSectionsSection: some View {
        Section("Разделы уведомлений") {
            if isLoadingSettings {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
            } else if settings.isEmpty {
                Text("Настройки уведомлений не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach($settings) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.section_name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Toggle("Push", isOn: $item.push_enabled)
                            .tint(AppTheme.control)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                Task {
                    await saveSettings()
                }
            } label: {
                HStack {
                    Spacer()

                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Сохранить настройки")
                            .font(.headline)
                    }

                    Spacer()
                }
            }
            .disabled(isSaving || isLoadingSettings || settings.isEmpty)
        }
    }

    // MARK: - Loading

    private func loadInitialData() async {
        await appState.refreshMobileConfigFeatures()

        if appState.pushNotificationsFeatureEnabled {
            await pushService.refreshAuthorizationStatus()
        }

        async let settingsTask: Void = loadSettings()
        async let devicesTask: Void = loadDevices()

        _ = await (settingsTask, devicesTask)
    }

    private func refreshData() async {
        await appState.refreshMobileConfigFeatures()

        if appState.pushNotificationsFeatureEnabled {
            await pushService.refreshAuthorizationStatus()
        }

        async let settingsTask: Void = loadSettings()
        async let devicesTask: Void = loadDevices()

        _ = await (settingsTask, devicesTask)
    }

    private func loadSettings() async {
        isLoadingSettings = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationSettingsListResponseDTO.self,
                api: appState.api,
                path: "/api/v1/push/settings",
                method: "GET",
                logPrefix: "PUSH SETTINGS"
            )

            settings = response.items.sorted {
                ($0.sort_order ?? 0) < ($1.sort_order ?? 0)
            }
        } catch {
            errorMessage = "Не удалось загрузить настройки уведомлений: \(error.localizedDescription)"
        }

        isLoadingSettings = false
    }

    private func loadDevices() async {
        isLoadingDevices = true
        errorMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                PushDevicesListResponseDTO.self,
                api: appState.api,
                path: "/api/v1/push/devices",
                method: "GET",
                logPrefix: "PUSH DEVICES"
            )

            devices = response.items
                .filter { $0.is_active }
                .sorted {
                    if isCurrentDevice($0) != isCurrentDevice($1) {
                        return isCurrentDevice($0)
                    }

                    return ($0.last_seen_at ?? $0.updated_at ?? $0.created_at ?? "") >
                        ($1.last_seen_at ?? $1.updated_at ?? $1.created_at ?? "")
                }
        } catch {
            errorMessage = "Не удалось загрузить устройства: \(error.localizedDescription)"
        }

        isLoadingDevices = false
    }

    // MARK: - Actions

    private func saveSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let bodyItems: [[String: Any]] = settings.map {
            [
                "section_code": $0.section_code,
                "in_app_enabled": $0.in_app_enabled,
                "push_enabled": $0.push_enabled,
                "email_enabled": $0.email_enabled,
                "sms_enabled": $0.sms_enabled
            ]
        }

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationSettingsListResponseDTO.self,
                api: appState.api,
                path: "/api/v1/push/settings",
                method: "PUT",
                body: [
                    "items": bodyItems
                ],
                logPrefix: "PUSH SETTINGS SAVE"
            )

            settings = response.items.sorted {
                ($0.sort_order ?? 0) < ($1.sort_order ?? 0)
            }

            successMessage = "Настройки уведомлений сохранены"
        } catch {
            errorMessage = "Не удалось сохранить настройки уведомлений: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func disableDevice(_ device: PushDeviceDTO) async {
        if isCurrentDevice(device) {
            errorMessage = "Текущее устройство отключается через кнопку «Выйти» в профиле."
            return
        }

        disablingDeviceID = device.id
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: appState.api,
                path: "/api/v1/push/devices/\(device.id)/disable",
                method: "PATCH",
                logPrefix: "PUSH DEVICE DISABLE"
            )

            devices.removeAll { $0.id == device.id }
            successMessage = "Устройство отключено"
        } catch {
            errorMessage = "Не удалось отключить устройство: \(error.localizedDescription)"
        }

        disablingDeviceID = nil
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

// MARK: - Device Row

struct PushDeviceSettingsRowView: View {
    let device: PushDeviceDTO
    let isCurrent: Bool
    let isDisabling: Bool
    let onDisable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrent ? Color.green.opacity(0.16) : Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: deviceIcon)
                        .foregroundStyle(isCurrent ? .green : .blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.title)
                            .font(.headline)

                        if isCurrent {
                            Text("Это устройство")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(device.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("ID: \(device.id) · \(device.tokenPreview)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if isCurrent {
                Text("Чтобы отключить это устройство, выйдите из аккаунта в профиле.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(role: .destructive) {
                    onDisable()
                } label: {
                    if isDisabling {
                        HStack {
                            ProgressView()
                            Text("Отключаем...")
                        }
                    } else {
                        Label("Отключить устройство", systemImage: "xmark.circle.fill")
                    }
                }
                .disabled(isDisabling)
            }
        }
        .padding(.vertical, 6)
    }

    private var deviceIcon: String {
        switch device.platform?.lowercased() {
        case "ios":
            return "iphone"
        case "android":
            return "apps.iphone"
        default:
            return "display"
        }
    }
}