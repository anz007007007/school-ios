import SwiftUI
import SchoolAPIClient

struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MessagesViewModel()

    @State private var selectedMessage: MessageDTO?
    @State private var selectedAnnouncement: AnnouncementDTO?

    @State private var isShowingComposeMessage = false
    @State private var isShowingBulkMessage = false
    @State private var isShowingAnnouncementForm = false

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    }
                }

                Section {
                    statsView
                }

                if !viewModel.filteredAnnouncements.isEmpty {
                    Section("Объявления") {
                        announcementsView
                    }
                }

                messagesSection
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Сообщения")
            .searchable(text: $viewModel.searchText, prompt: "Поиск сообщений")
            .preferredColorScheme(.light)
            .onSubmit(of: .search) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }
            .refreshable {
                viewModel.currentUserID = appState.currentUser?.id
                await viewModel.loadInitialData(api: appState.api)
            }
            .task {
                Task {
                    await appState.markNotificationsReadForRoute(.messages(notificationID: nil))
                }
                PushNotificationService.shared.clearLatestRemoteNotification()

                viewModel.currentUserID = appState.currentUser?.id

                await viewModel.loadInitialData(api: appState.api)
            }
            .onChange(of: appState.tabReselectToken[.messages]) {
                Task {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if appState.canSendMessages {
                        Menu {
                            Button {
                                isShowingComposeMessage = true
                            } label: {
                                Label("Написать", systemImage: "square.and.pencil")
                            }

                            if appState.canSendBulkMessages {
                                Button {
                                    isShowingBulkMessage = true
                                } label: {
                                    Label("Рассылка", systemImage: "paperplane.fill")
                                }
                            }

                            if appState.canCreateAnnouncements {
                                Button {
                                    isShowingAnnouncementForm = true
                                } label: {
                                    Label("Объявление", systemImage: "megaphone.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    Button {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if viewModel.isLoadingMessageDetail {
                    ZStack {
                        Color.black.opacity(0.12)
                            .ignoresSafeArea()

                        ProgressView("Открываем сообщение...")
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .sheet(item: $selectedMessage) { message in
                MessageDetailView(
                    message: message,
                    dateTitle: viewModel.dateTimeTitle(message.created_at),
                    canManage: appState.canSendMessages,
                    canMarkRead: message.isIncoming(for: appState.currentUser?.id),
                    isArchived: viewModel.selectedFolder == .archive,
                    onMarkRead: {
                        selectedMessage = nil

                        Task {
                            _ = await viewModel.markAsRead(
                                api: appState.api,
                                message: message,
                                currentUserID: appState.currentUser?.id
                            )
                        }
                    },
                    onArchive: {
                        selectedMessage = nil

                        Task {
                            if viewModel.selectedFolder == .archive {
                                _ = await viewModel.unarchiveMessage(
                                    api: appState.api,
                                    message: message
                                )
                            } else {
                                _ = await viewModel.archiveMessage(
                                    api: appState.api,
                                    message: message
                                )
                            }
                        }
                    }
                )
            }
            .sheet(item: $selectedAnnouncement) { announcement in
                AnnouncementDetailView(
                    announcement: announcement,
                    dateTitle: viewModel.dateTimeTitle(announcement.created_at),
                    audienceTitle: viewModel.announcementAudienceTitle(announcement)
                )
            }
            .sheet(isPresented: $isShowingComposeMessage) {
                MessageComposeView(
                    mode: .single,
                    contacts: viewModel.contacts,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSendSingle: { formData in
                        let safeFormData = MessageCreateFormData(
                            recipientUserID: formData.recipientUserID,
                            subject: String(formData.subject),
                            body: String(formData.body),
                            isImportant: formData.isImportant
                        )

                        Task { @MainActor in
                            _ = await viewModel.sendMessage(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    },
                    onSendBulk: { _ in }
                )
                .preferredColorScheme(.light)
            }
            .sheet(isPresented: $isShowingBulkMessage) {
                MessageComposeView(
                    mode: .bulk,
                    contacts: viewModel.contacts,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSendSingle: { _ in },
                    onSendBulk: { formData in
                        let safeFormData = MessageBulkFormData(
                            recipientUserIDs: Array(formData.recipientUserIDs),
                            subject: String(formData.subject),
                            body: String(formData.body),
                            isImportant: formData.isImportant
                        )

                        Task { @MainActor in
                            _ = await viewModel.sendBulkMessage(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingAnnouncementForm) {
                AnnouncementFormView(
                    audiences: viewModel.audiences,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = AnnouncementFormData(
                            title: String(formData.title),
                            body: String(formData.body),
                            targetAudience: String(formData.targetAudience),
                            isImportant: formData.isImportant
                        )

                        Task { @MainActor in
                            _ = await viewModel.createAnnouncement(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            Picker("Папка", selection: $viewModel.selectedFolder) {
                ForEach(MessagesViewModel.MessageFolder.allCases) { folder in
                    Text(folder.rawValue).tag(folder)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedFolder) { _ in
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            Toggle("Только непрочитанные", isOn: $viewModel.showOnlyUnread)

            Toggle("Скрывать прочитанные объявления", isOn: $viewModel.hideReadAnnouncements)

            Toggle("Только важные", isOn: $viewModel.showOnlyImportant)

            Button {
                viewModel.searchText = ""
                viewModel.showOnlyUnread = true
                viewModel.hideReadAnnouncements = true
                viewModel.showOnlyImportant = false

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            } label: {
                Label("Сбросить фильтры", systemImage: "xmark.circle")
            }
            .disabled(
                viewModel.searchText.isEmpty
                && viewModel.showOnlyUnread
                && viewModel.hideReadAnnouncements
                && !viewModel.showOnlyImportant
            )
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            MessageStatCard(
                title: "Сообщений",
                value: "\(viewModel.filteredMessages.count)",
                color: .blue,
                systemImage: "envelope.fill"
            )

            MessageStatCard(
                title: "Непроч.",
                value: "\(viewModel.unreadCount)",
                color: .orange,
                systemImage: "envelope.badge.fill"
            )

            MessageStatCard(
                title: "Важные",
                value: "\(viewModel.importantCount)",
                color: .red,
                systemImage: "exclamationmark.circle.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var announcementsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.filteredAnnouncements.prefix(3)) { announcement in
                Button {
                    viewModel.markAnnouncementOpened(announcement)
                    selectedAnnouncement = announcement
                } label: {
                    AnnouncementRowView(
                        announcement: announcement,
                        dateTitle: viewModel.dateTimeTitle(announcement.created_at),
                        audienceTitle: viewModel.announcementAudienceTitle(announcement)
                    )
                }
                .buttonStyle(.plain)

                if announcement.id != viewModel.filteredAnnouncements.prefix(3).last?.id {
                    Divider()
                }
            }

            if appState.canCreateAnnouncements {
                Button {
                    isShowingAnnouncementForm = true
                } label: {
                    Label("Создать объявление", systemImage: "plus")
                }
            }
        }
    }

    private var messagesSection: some View {
        Section("Письма") {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Повторить") {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.groupedMessages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Сообщений нет")
                        .font(.headline)

                    Text("По выбранным фильтрам ничего не найдено.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if appState.canSendMessages {
                        Button {
                            isShowingComposeMessage = true
                        } label: {
                            Label("Написать сообщение", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.groupedMessages) { group in
                    Section {
                        ForEach(group.messages) { message in
                            Button {
                                Task {
                                    if let opened = await viewModel.openMessage(
                                        api: appState.api,
                                        message: message,
                                        currentUserID: appState.currentUser?.id
                                    ) {
                                        selectedMessage = opened
                                    }
                                }
                            } label: {
                                MessageRowView(
                                    message: message,
                                    timeTitle: viewModel.timeTitle(message.created_at)
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if viewModel.selectedFolder == .archive {
                                    Button {
                                        Task {
                                            _ = await viewModel.unarchiveMessage(
                                                api: appState.api,
                                                message: message
                                            )
                                        }
                                    } label: {
                                        Label("Вернуть", systemImage: "tray.and.arrow.up")
                                    }
                                    .tint(.green)
                                } else {
                                    Button {
                                        Task {
                                            _ = await viewModel.archiveMessage(
                                                api: appState.api,
                                                message: message
                                            )
                                        }
                                    } label: {
                                        Label("В архив", systemImage: "archivebox")
                                    }
                                    .tint(.blue)
                                }

                                if !message.is_read && message.isIncoming(for: appState.currentUser?.id) {
                                    Button {
                                        Task {
                                            _ = await viewModel.markAsRead(
                                                api: appState.api,
                                                message: message,
                                                currentUserID: appState.currentUser?.id
                                            )
                                        }
                                    } label: {
                                        Label("Прочитано", systemImage: "envelope.open")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    } header: {
                        Text(viewModel.dateTitle(group.day))
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }

                if appState.canSendMessages {
                    Button {
                        isShowingComposeMessage = true
                    } label: {
                        Label("Написать сообщение", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct MessageRowView: View {
    let message: MessageDTO
    let timeTitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: message.is_read ? "envelope.open.fill" : "envelope.badge.fill")
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(message.subject)
                        .font(message.is_read ? .headline : .headline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if message.is_important {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Text(timeTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(message.sender_name, systemImage: "arrow.up.circle")
                    Spacer()
                    Label(message.recipient_name, systemImage: "arrow.down.circle")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        if message.is_important {
            return .red
        }

        if !message.is_read {
            return .orange
        }

        return .blue
    }
}

struct AnnouncementRowView: View {
    let announcement: AnnouncementDTO
    let dateTitle: String
    let audienceTitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(announcement.is_important ? .red.opacity(0.15) : .blue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: announcement.is_important ? "megaphone.fill" : "info.circle.fill")
                    .foregroundStyle(announcement.is_important ? .red : .blue)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(announcement.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if announcement.is_important {
                        Text("Важно")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(announcement.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(audienceTitle, systemImage: "person.3.fill")
                    Spacer()
                    Text(dateTitle)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let message: MessageDTO
    let dateTitle: String
    let canManage: Bool
    let canMarkRead: Bool
    var isArchived: Bool = false
    let onMarkRead: () -> Void
    let onArchive: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(message.is_read ? "Прочитано" : "Новое")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(message.is_read ? .blue.opacity(0.12) : .orange.opacity(0.12))
                                .foregroundStyle(message.is_read ? .blue : .orange)
                                .clipShape(Capsule())

                            if message.is_important {
                                Text("Важно")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }

                            Spacer()
                        }

                        Text(message.subject)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(message.body)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical)
                }

                Section("Информация") {
                    LabeledContent("От", value: message.sender_name)
                    LabeledContent("Кому", value: message.recipient_name)
                    LabeledContent("Дата", value: dateTitle)

                    if let senderRole = message.sender_role_code {
                        LabeledContent("Роль отправителя", value: MessagesViewModel.roleTitle(senderRole))
                    }

                    if let recipientRole = message.recipient_role_code {
                        LabeledContent("Роль получателя", value: MessagesViewModel.roleTitle(recipientRole))
                    }
                }

                Section("Действия") {
                    if !message.is_read && canMarkRead {
                        Button {
                            onMarkRead()
                        } label: {
                            Label("Отметить прочитанным", systemImage: "envelope.open")
                        }
                    }

                    Button {
                        onArchive()
                    } label: {
                        if isArchived {
                            Label("Вернуть из архива", systemImage: "tray.and.arrow.up")
                        } else {
                            Label("В архив", systemImage: "archivebox")
                        }
                    }
                }
            }
            .navigationTitle("Сообщение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AnnouncementDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let announcement: AnnouncementDTO
    let dateTitle: String
    let audienceTitle: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(audienceTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            if announcement.is_important {
                                Text("Важно")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }

                            Spacer()
                        }

                        Text(announcement.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(announcement.body)
                            .font(.body)
                    }
                    .padding(.vertical)
                }

                Section("Информация") {
                    LabeledContent("Автор", value: announcement.author_name)
                    LabeledContent("Аудитория", value: audienceTitle)
                    LabeledContent("Дата", value: dateTitle)
                }
            }
            .navigationTitle("Объявление")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MessageStatCard: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}