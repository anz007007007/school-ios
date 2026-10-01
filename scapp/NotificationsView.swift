import SwiftUI
import SchoolAPIClient

struct NotificationsView: View {
    @EnvironmentObject var appState: AppState

    @State private var notifications: [AppNotificationDTO] = []
    @State private var unreadCount = 0

    @State private var isLoading = false
    @State private var isMarkingAllRead = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            headerSection

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if isLoading && notifications.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка уведомлений...")
                        Spacer()
                    }
                } else if notifications.isEmpty {
                    emptyStateView
                } else {
                    ForEach(notifications) { notification in
                        NotificationRowView(notification: notification)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    await openNotification(notification)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        Task {
                            await deleteNotifications(indexSet)
                        }
                    }
                }
            } header: {
                Text("Список")
            } footer: {
                if !notifications.isEmpty {
                    Text("Смахните уведомление влево, чтобы удалить его.")
                }
            }
        }
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await loadNotifications()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                    .font(.title2)
                    .foregroundStyle(unreadCount > 0 ? .orange : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Непрочитанные")
                        .font(.headline)

                    Text("\(unreadCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(unreadCount > 0 ? .orange : .secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            Button {
                Task {
                    await markAllNotificationsRead()
                }
            } label: {
                HStack {
                    Spacer()

                    if isMarkingAllRead {
                        ProgressView()
                    } else {
                        Label("Отметить все прочитанными", systemImage: "checkmark.circle")
                    }

                    Spacer()
                }
            }
            .disabled(isMarkingAllRead || unreadCount == 0)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Уведомлений пока нет")
                .font(.headline)

            Text("Здесь будут отображаться уведомления из приложения.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                NotificationsListResponseDTO.self,
                api: appState.api,
                path: "/api/v1/push/notifications",
                method: "GET",
                logPrefix: "NOTIFICATIONS"
            )

            notifications = response.items
            unreadCount = response.unread_count

            // Обновляем бейдж после загрузки уведомлений
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        } catch {
            errorMessage = "Не удалось загрузить уведомления: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func openNotification(_ notification: AppNotificationDTO) async {
        await markNotificationReadIfNeeded(notification)

        let route = PushRoute.route(
            notificationType: notification.notification_type,
            sectionCode: nil,
            notificationID: notification.id
        )

        await appState.markNotificationsReadForRoute(route)
        appState.openPushRoute(route)
    }

    private func markNotificationReadIfNeeded(_ notification: AppNotificationDTO) async {
        guard !notification.is_read else {
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
            return
        }

        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: appState.api,
                path: "/api/v1/push/notifications/\(notification.id)/read",
                method: "PATCH",
                logPrefix: "NOTIFICATION READ"
            )

            await loadNotifications()
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        } catch {
            errorMessage = "Не удалось отметить уведомление прочитанным: \(error.localizedDescription)"
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        }
    }

    private func markAllNotificationsRead() async {
        guard unreadCount > 0 else {
            return
        }

        isMarkingAllRead = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: appState.api,
                path: "/api/v1/push/notifications/read-all",
                method: "PATCH",
                logPrefix: "NOTIFICATIONS READ ALL"
            )

            successMessage = "Все уведомления отмечены прочитанными"
            await loadNotifications()
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        } catch {
            errorMessage = "Не удалось отметить уведомления прочитанными: \(error.localizedDescription)"
        }

        isMarkingAllRead = false
    }

    private func deleteNotifications(_ indexSet: IndexSet) async {
        errorMessage = nil
        successMessage = nil

        let itemsToDelete = indexSet.compactMap { index -> AppNotificationDTO? in
            guard notifications.indices.contains(index) else {
                return nil
            }

            return notifications[index]
        }

        guard !itemsToDelete.isEmpty else {
            return
        }

        do {
            for item in itemsToDelete {
                _ = try await APIRequestService.shared.request(
                    api: appState.api,
                    path: "/api/v1/push/notifications/\(item.id)",
                    method: "DELETE",
                    logPrefix: "NOTIFICATION DELETE"
                )
            }

            successMessage = itemsToDelete.count == 1
                ? "Уведомление удалено"
                : "Уведомления удалены"

            await loadNotifications()
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        } catch {
            errorMessage = "Не удалось удалить уведомление: \(error.localizedDescription)"
            await loadNotifications()
            await PushNotificationService.shared.refreshBadgeAfterNotificationStateChange(api: appState.api)
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotificationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            unreadIndicator

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(notification.is_read ? Color.primary : Color.blue)

                    Spacer()

                    if !notification.is_read {
                        Text("Новое")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(typeTitle(notification.notification_type), systemImage: typeIcon(notification.notification_type))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formatDate(notification.created_at))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if notification.is_read {
            Circle()
                .fill(.clear)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
        } else {
            Circle()
                .fill(.blue)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
        }
    }

    private func typeTitle(_ value: String) -> String {
        switch value {
        case "message":
            return "Сообщение"
        case "announcement":
            return "Объявление"
        case "homework":
            return "Домашнее задание"
        case "grade":
            return "Оценка"
        case "event":
            return "Событие"
        case "finance":
            return "Финансы"
        case "health":
            return "Здоровье"
        case "schedule":
            return "Расписание"
        default:
            return value
                .replacingOccurrences(of: "_", with: " ")
        }
    }

    private func typeIcon(_ value: String) -> String {
        switch value {
        case "message":
            return "message.fill"
        case "announcement":
            return "megaphone.fill"
        case "homework":
            return "book.fill"
        case "grade":
            return "star.fill"
        case "event":
            return "calendar"
        case "finance":
            return "creditcard.fill"
        case "health":
            return "cross.case.fill"
        case "schedule":
            return "clock.fill"
        default:
            return "bell.fill"
        }
    }

    private func formatDate(_ value: String) -> String {
        AppDateFormatter.dateTime(value)
    }
}