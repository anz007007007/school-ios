import SwiftUI

struct EventsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = EventsViewModel()

    @State private var selectedEvent: EventTimelineDTO?
    @State private var editingEvent: EventTimelineDTO?
    @State private var managingParticipantsEvent: EventTimelineDTO?
    @State private var isShowingCreateForm = false
    @State private var eventToDelete: EventTimelineDTO?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if !viewModel.events.isEmpty {
                    Section {
                        statsView
                    }

                    if !viewModel.timeConflicts.isEmpty {
                        Section("Пересечения") {
                            conflictsView
                        }
                    }
                }

                timelineSection
            }
            .appThemedList()
            .navigationTitle("События")
            .searchable(text: $viewModel.searchText, prompt: "Поиск события")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
                Task {
                    await markEventsNotificationsRead()
                }
            }
            .refreshable {
                await viewModel.loadInitialData(api: appState.api)
                Task {
                    await markEventsNotificationsRead()
                }
            }
            .task {
                await viewModel.loadInitialData(api: appState.api)

                Task {
                    await markEventsNotificationsRead()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if appState.canManageEvents {
                        Button {
                            isShowingCreateForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    Button {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                            await markEventsNotificationsRead()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(
                    event: event,
                    eventTypeTitle: viewModel.eventTypeTitle(event.event_type),
                    dateTimeTitle: viewModel.dateTimeTitle(event.starts_at),
                    isPast: viewModel.isPast(event.starts_at),
                    canManage: appState.canManageEvents,
                    selectedStudentID: viewModel.selectedStudentID,
                    selectedStudentName: selectedStudentName,
                    isSaving: viewModel.isSaving,
                    onConfirmParticipation: {
                        Task {
                            _ = await viewModel.sendParticipationFeedback(
                                api: appState.api,
                                eventID: event.id,
                                studentID: viewModel.selectedStudentID,
                                willParticipate: true
                            )
                        }
                    },
                    onDeclineParticipation: {
                        Task {
                            _ = await viewModel.sendParticipationFeedback(
                                api: appState.api,
                                eventID: event.id,
                                studentID: viewModel.selectedStudentID,
                                willParticipate: false
                            )
                        }
                    },
                    onManageParticipants: {
                        selectedEvent = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            managingParticipantsEvent = event
                        }
                    },
                    onEdit: {
                        selectedEvent = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            editingEvent = event
                        }
                    },
                    onDelete: {
                        selectedEvent = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            eventToDelete = event
                            isShowingDeleteConfirmation = true
                        }
                    }
                )
            }
            .sheet(item: $managingParticipantsEvent) { event in
                EventParticipantsManagementView(
                    event: event,
                    viewModel: viewModel
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $isShowingCreateForm) {
                EventFormView(
                    mode: .create,
                    event: nil,
                    eventTypes: viewModel.availableEventTypes,
                    classes: viewModel.filterClasses,
                    students: viewModel.filterStudents,
                    eventTypeTitle: viewModel.eventTypeTitle,
                    parseDate: viewModel.parseDate,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = EventFormData(
                            title: String(formData.title),
                            eventType: String(formData.eventType),
                            startsAt: formData.startsAt,
                            description: String(formData.description),
                            classIDs: Array(formData.classIDs),
                            studentIDs: Array(formData.studentIDs)
                        )

                        Task { @MainActor in
                            _ = await viewModel.createEvent(
                                api: appState.api,
                                formData: safeFormData
                            )

                            await markEventsNotificationsRead()
                        }
                    }
                )
            }
            .sheet(item: $editingEvent) { event in
                EventFormView(
                    mode: .edit,
                    event: event,
                    eventTypes: viewModel.availableEventTypes,
                    classes: viewModel.filterClasses,
                    students: viewModel.filterStudents,
                    eventTypeTitle: viewModel.eventTypeTitle,
                    parseDate: viewModel.parseDate,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = EventFormData(
                            title: String(formData.title),
                            eventType: String(formData.eventType),
                            startsAt: formData.startsAt,
                            description: String(formData.description),
                            classIDs: Array(formData.classIDs),
                            studentIDs: Array(formData.studentIDs)
                        )

                        Task { @MainActor in
                            _ = await viewModel.updateEvent(
                                api: appState.api,
                                eventID: event.id,
                                formData: safeFormData
                            )

                            await markEventsNotificationsRead()
                        }
                    }
                )
            }
            .confirmationDialog(
                "Удалить событие?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let eventToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deleteEvent(
                            api: appState.api,
                            event: eventToDelete
                        )

                        self.eventToDelete = nil
                        await markEventsNotificationsRead()
                    }
                }

                Button("Отмена", role: .cancel) {
                    eventToDelete = nil
                }
            } message: {
                if let eventToDelete {
                    Text("Событие «\(eventToDelete.title)» будет удалено без возможности восстановления.")
                }
            }
        }
    }

    private func markEventsNotificationsRead() async {
        await appState.markNotificationsReadForRoute(.events(notificationID: nil))
    }

    private var selectedStudentName: String? {
        guard viewModel.selectedStudentID != 0 else {
            return nil
        }

        return viewModel.filterStudents.first {
            $0.id == viewModel.selectedStudentID
        }?.student_name
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            Picker("Период", selection: $viewModel.selectedScope) {
                ForEach(EventsViewModel.EventScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedScope) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                    await markEventsNotificationsRead()
                }
            }

            if viewModel.isLoadingFilters {
                HStack {
                    Spacer()
                    ProgressView("Загрузка фильтров...")
                    Spacer()
                }
            }

            if !viewModel.filterClasses.isEmpty {
                Picker("Класс", selection: $viewModel.selectedClassID) {
                    Text("Все классы").tag(0)

                    ForEach(viewModel.filterClasses) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .onChange(of: viewModel.selectedClassID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                        await markEventsNotificationsRead()
                    }
                }
            }

            if !viewModel.filterStudents.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    Text("Все ученики").tag(0)

                    ForEach(viewModel.filterStudents) { item in
                        Text(item.student_name).tag(item.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                        await markEventsNotificationsRead()
                    }
                }
            }

            if !viewModel.eventTypes.isEmpty {
                Picker("Тип", selection: $viewModel.selectedEventType) {
                    Text("Все типы").tag("all")

                    ForEach(viewModel.eventTypes, id: \.self) { type in
                        Text(viewModel.eventTypeTitle(type)).tag(type)
                    }
                }
                .onChange(of: viewModel.selectedEventType) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                        await markEventsNotificationsRead()
                    }
                }
            }

            Button {
                viewModel.searchText = ""

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                    await markEventsNotificationsRead()
                }
            } label: {
                Label("Сбросить поиск", systemImage: "xmark.circle")
            }
            .disabled(viewModel.searchText.isEmpty)
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            EventStatCard(
                title: "Событий",
                value: "\(viewModel.filteredEvents.count)",
                color: .blue,
                systemImage: "calendar"
            )

            EventStatCard(
                title: "Участников",
                value: "\(viewModel.totalParticipants)",
                color: .purple,
                systemImage: "person.3.fill"
            )

            EventStatCard(
                title: "Ожидают",
                value: "\(max(viewModel.waitingCount, 0))",
                color: .orange,
                systemImage: "clock.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var conflictsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Найдены события в одно и то же время", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)

            ForEach(viewModel.timeConflicts) { conflict in
                VStack(alignment: .leading, spacing: 6) {
                    Text(conflict.key)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(conflict.events) { event in
                        HStack {
                            Circle()
                                .fill(eventColor(event.event_type))
                                .frame(width: 8, height: 8)

                            Text(event.title)
                                .font(.caption)

                            Spacer()

                            Text(viewModel.eventTypeTitle(event.event_type))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Пересечения считаются по одинаковой дате и времени начала. Если событие влияет на конкретных учеников или классы, используйте фильтры выше.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var timelineSection: some View {
        Section("Таймлайн") {
            if viewModel.isLoading && viewModel.events.isEmpty {
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
                            await markEventsNotificationsRead()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.groupedByDay.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Событий нет")
                        .font(.headline)

                    Text("По выбранным фильтрам события не найдены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if appState.canManageEvents {
                        Button {
                            isShowingCreateForm = true
                        } label: {
                            Label("Добавить событие", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.groupedByDay) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.dayTitle(group.day))
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)

                        ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                            Button {
                                selectedEvent = event

                                Task {
                                    await markEventsNotificationsRead()
                                }
                            } label: {
                                EventTimelineRowView(
                                    event: event,
                                    timeTitle: viewModel.timeTitle(event.starts_at),
                                    eventTypeTitle: viewModel.eventTypeTitle(event.event_type),
                                    isPast: viewModel.isPast(event.starts_at),
                                    color: eventColor(event.event_type),
                                    showLine: index != group.events.count - 1,
                                    canSendFeedback: viewModel.selectedStudentID != 0 && !viewModel.isPast(event.starts_at),
                                    isSaving: viewModel.isSaving,
                                    onConfirmParticipation: {
                                        Task {
                                            _ = await viewModel.sendParticipationFeedback(
                                                api: appState.api,
                                                eventID: event.id,
                                                studentID: viewModel.selectedStudentID,
                                                willParticipate: true
                                            )
                                        }
                                    },
                                    onDeclineParticipation: {
                                        Task {
                                            _ = await viewModel.sendParticipationFeedback(
                                                api: appState.api,
                                                eventID: event.id,
                                                studentID: viewModel.selectedStudentID,
                                                willParticipate: false
                                            )
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if appState.canManageEvents {
                                    Button(role: .destructive) {
                                        eventToDelete = event
                                        isShowingDeleteConfirmation = true
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }

                                    Button {
                                        editingEvent = event
                                    } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button {
                                        managingParticipantsEvent = event
                                    } label: {
                                        Label("Участники", systemImage: "person.3.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func eventColor(_ type: String) -> Color {
        switch type {
        case "meeting":
            return .blue
        case "holiday":
            return .pink
        case "exam":
            return .red
        case "trip":
            return .green
        case "competition":
            return .purple
        case "sport":
            return .orange
        case "club":
            return .teal
        default:
            return .gray
        }
    }
}

struct EventTimelineRowView: View {
    let event: EventTimelineDTO
    let timeTitle: String
    let eventTypeTitle: String
    let isPast: Bool
    let color: Color
    let showLine: Bool
    let canSendFeedback: Bool
    let isSaving: Bool
    let onConfirmParticipation: () -> Void
    let onDeclineParticipation: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 38, height: 38)

                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                }

                if showLine {
                    Rectangle()
                        .fill(color.opacity(0.25))
                        .frame(width: 2, height: 58)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(timeTitle)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text(eventTypeTitle)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .foregroundStyle(color)
                        .clipShape(Capsule())

                    Spacer()

                    if isPast {
                        Text("Прошло")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                participationView
                feedbackView
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.vertical, 4)
    }

    private var participationView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(event.participants_count)", systemImage: "person.3.fill")
                Label("\(event.confirmed_count)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(event.declined_count)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ProgressView(value: progressValue)
                .tint(.green)
        }
    }

    @ViewBuilder
    private var feedbackView: some View {
        if isPast {
            EmptyView()
        } else if canSendFeedback {
            HStack(spacing: 8) {
                Button {
                    onConfirmParticipation()
                } label: {
                    Label("Приму участие", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)

                Button {
                    onDeclineParticipation()
                } label: {
                    Label("Не смогу", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isSaving)
            }
            .padding(.top, 4)
        } else {
            Text("Выберите ученика в фильтре, чтобы отправить ответ.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var progressValue: Double {
        guard event.participants_count > 0 else {
            return 0
        }

        return Double(event.confirmed_count) / Double(event.participants_count)
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventTimelineDTO
    let eventTypeTitle: String
    let dateTimeTitle: String
    let isPast: Bool
    let canManage: Bool
    let selectedStudentID: Int
    let selectedStudentName: String?
    let isSaving: Bool
    let onConfirmParticipation: () -> Void
    let onDeclineParticipation: () -> Void
    let onManageParticipants: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(eventTypeTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            Spacer()

                            if isPast {
                                Text("Прошло")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Label(dateTimeTitle, systemImage: "calendar")
                            .foregroundStyle(.secondary)

                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Обратная связь") {
                    if isPast {
                        Label("Мероприятие уже прошло", systemImage: "clock.fill")
                            .foregroundStyle(.secondary)
                    } else if selectedStudentID == 0 {
                        Label("Выберите ученика в фильтре, чтобы принять участие или отказаться", systemImage: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.secondary)
                    } else {
                        if let selectedStudentName {
                            Text("Ответ для: \(selectedStudentName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            onConfirmParticipation()
                        } label: {
                            if isSaving {
                                HStack {
                                    ProgressView()
                                    Text("Сохраняем...")
                                }
                            } else {
                                Label("Приму участие", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .tint(.green)
                        .disabled(isSaving)

                        Button(role: .destructive) {
                            onDeclineParticipation()
                        } label: {
                            if isSaving {
                                HStack {
                                    ProgressView()
                                    Text("Сохраняем...")
                                }
                            } else {
                                Label("Не смогу участвовать", systemImage: "xmark.circle.fill")
                            }
                        }
                        .disabled(isSaving)
                    }
                }

                Section("Участники") {
                    LabeledContent("Всего", value: "\(event.participants_count)")
                    LabeledContent("Подтвердили", value: "\(event.confirmed_count)")
                    LabeledContent("Отказались", value: "\(event.declined_count)")
                    LabeledContent("Ожидают", value: "\(max(event.participants_count - event.confirmed_count - event.declined_count, 0))")
                }

                if canManage {
                    Section("Управление") {
                        Button {
                            onManageParticipants()
                        } label: {
                            Label("Участники события", systemImage: "person.3.fill")
                        }

                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }

                Section("Система") {
                    LabeledContent("ID события", value: "\(event.id)")
                    LabeledContent("Тип", value: event.event_type)
                    LabeledContent("Дата сервера", value: AppDateFormatter.dateTime(event.starts_at))
                }
            }
            .appThemedList()
            .navigationTitle("Событие")
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

struct EventParticipantsManagementView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let event: EventTimelineDTO
    @ObservedObject var viewModel: EventsViewModel

    @State private var selectedStudentIDs: Set<Int> = []
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Участников: \(event.participants_count)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                addParticipantsSection

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                participantsSection
            }
            .appThemedList()
            .navigationTitle("Участники")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadEventParticipants(api: appState.api, eventID: event.id)
            }
            .refreshable {
                await viewModel.loadEventParticipants(api: appState.api, eventID: event.id)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private var addParticipantsSection: some View {
        Section("Добавить участников") {
            let availableStudents = viewModel.availableStudentsForEvent(event.id)

            if availableStudents.isEmpty {
                Text("Все доступные ученики уже добавлены или список учеников не загружен.")
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup("Выбрано: \(selectedStudentIDs.count)") {
                    ForEach(availableStudents) { student in
                        Toggle(
                            student.student_name,
                            isOn: Binding(
                                get: {
                                    selectedStudentIDs.contains(student.id)
                                },
                                set: { isSelected in
                                    if isSelected {
                                        selectedStudentIDs.insert(student.id)
                                    } else {
                                        selectedStudentIDs.remove(student.id)
                                    }
                                }
                            )
                        )
                    }
                }

                Button {
                    addSelectedParticipants()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Label("Добавить выбранных", systemImage: "plus.circle.fill")
                    }
                }
                .disabled(viewModel.isSaving || selectedStudentIDs.isEmpty)
            }
        }
    }

    private var participantsSection: some View {
        Section("Список участников") {
            if viewModel.isLoadingParticipants {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
            } else {
                let participants = viewModel.participantsForEvent(event.id)

                if participants.isEmpty {
                    Text("Участников пока нет.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(participants) { participant in
                        EventParticipantRowView(
                            participant: participant,
                            statuses: viewModel.participationStatuses,
                            statusTitle: viewModel.participationStatusTitle(participant.participation_status),
                            onStatusChange: { newStatus in
                                Task {
                                    _ = await viewModel.updateParticipantStatus(
                                        api: appState.api,
                                        eventID: event.id,
                                        studentID: participant.student_id,
                                        status: newStatus
                                    )
                                }
                            },
                            onDelete: {
                                Task {
                                    _ = await viewModel.removeParticipant(
                                        api: appState.api,
                                        eventID: event.id,
                                        studentID: participant.student_id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func addSelectedParticipants() {
        validationMessage = nil

        guard !selectedStudentIDs.isEmpty else {
            validationMessage = "Выберите хотя бы одного ученика"
            return
        }

        Task {
            let success = await viewModel.addParticipants(
                api: appState.api,
                eventID: event.id,
                studentIDs: Array(selectedStudentIDs).sorted()
            )

            if success {
                selectedStudentIDs.removeAll()
            }
        }
    }
}

struct EventParticipantRowView: View {
    let participant: EventParticipantDTO
    let statuses: [(code: String, title: String)]
    let statusTitle: String
    let onStatusChange: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.student_name)
                        .font(.headline)

                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
            }

            Picker("Статус", selection: Binding(
                get: { participant.participation_status },
                set: { newValue in
                    onStatusChange(newValue)
                }
            )) {
                ForEach(statuses, id: \.code) { status in
                    Text(status.title).tag(status.code)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch participant.participation_status {
        case "confirmed", "attended":
            return .green
        case "declined", "absent":
            return .red
        case "pending":
            return .orange
        default:
            return .secondary
        }
    }
}

struct EventStatCard: View {
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