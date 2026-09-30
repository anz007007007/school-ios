import SwiftUI

struct HomeworkView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeworkViewModel()

    @State private var selectedHomework: HomeworkDTO?
    @State private var showCreateHomework = false
    @State private var isFiltersExpanded = false

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

                homeworkSection
            }
            .appThemedList()
            .navigationTitle("Домашка")
            .searchable(text: $viewModel.searchText, prompt: "Поиск задания")
            .refreshable {
                await viewModel.loadInitialData(api: appState.api)
            }
            .task {
                await appState.markNotificationsReadForRoute(.homework(notificationID: nil))

                if viewModel.items.isEmpty {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.canManageHomework {
                        Button {
                            showCreateHomework = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedHomework) { homework in
                HomeworkDetailView(
                    homework: homework,
                    deadlineTitle: viewModel.deadlineStatusTitle(homework.due_date),
                    isOverdue: viewModel.isHomeworkOverdue(homework),
                    isToday: viewModel.isToday(homework.due_date),
                    canManage: appState.canManageHomework,
                    canUpdateCompletion: canUpdateCompletion(for: homework),
                    isUpdatingCompletion: viewModel.updatingCompletionIDs.contains(homework.id),
                    completionStudentID: completionStudentID(for: homework),
                    onCompletionChange: { isCompleted in
                        Task {
                            let success = await viewModel.updateCompletion(
                                api: appState.api,
                                homework: homework,
                                studentID: completionStudentID(for: homework),
                                isCompleted: isCompleted
                            )

                            if success {
                                selectedHomework = viewModel.items.first { $0.id == homework.id }
                            }
                        }
                    },
                    onDelete: {
                        Task {
                            let success = await viewModel.deleteHomework(
                                api: appState.api,
                                homeworkID: homework.id
                            )

                            if success {
                                selectedHomework = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showCreateHomework) {
                CreateHomeworkView(viewModel: viewModel)
                    .environmentObject(appState)
            }
        }
    }

    private func completionStudentID(for homework: HomeworkDTO) -> Int {
        viewModel.selectedStudentID
    }

    private func canUpdateCompletion(for homework: HomeworkDTO) -> Bool {
        guard appState.isParent || appState.isStudent else {
            return false
        }

        return viewModel.selectedStudentID != 0
    }

    private var filtersSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFiltersExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Фильтры")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(homeworkFiltersSummaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: isFiltersExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !viewModel.items.isEmpty {
                    homeworkHeaderStatsView
                }
            }

            if isFiltersExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Период")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            homeworkScopeButton(.today)
                            homeworkScopeButton(.tomorrow)
                            homeworkScopeButton(.week)
                        }

                        HStack(spacing: 8) {
                            homeworkScopeButton(.overdue)
                            homeworkScopeButton(.all)
                        }
                    }
                }

                if viewModel.isLoadingFilters {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка фильтров...")
                        Spacer()
                    }
                }

                if !viewModel.students.isEmpty {
                    Picker("Ученик", selection: $viewModel.selectedStudentID) {
                        ForEach(viewModel.students) { student in
                            Text(student.student_name).tag(student.id)
                        }
                    }
                    .onChange(of: viewModel.selectedStudentID) {
                        Task {
                            await viewModel.selectStudent(
                                api: appState.api,
                                studentID: viewModel.selectedStudentID
                            )
                        }
                    }
                }

                if !viewModel.subjects.isEmpty {
                    Picker("Предмет", selection: $viewModel.selectedSubjectID) {
                        Text("Все предметы").tag(0)

                        ForEach(viewModel.subjects) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                    .onChange(of: viewModel.selectedSubjectID) {
                        Task {
                            await viewModel.reloadForFilters(api: appState.api)
                        }
                    }
                }
            }
        }
    }

    private var homeworkFiltersSummaryText: String {
        var parts: [String] = [
            viewModel.selectedScope.rawValue
        ]

        if let student = viewModel.students.first(where: { $0.id == viewModel.selectedStudentID }) {
            parts.append(student.student_name)
        }

        if viewModel.selectedSubjectID != 0,
           let subject = viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectID }) {
            parts.append(subject.name)
        } else {
            parts.append("Все предметы")
        }

        return parts.joined(separator: " · ")
    }

    private var homeworkHeaderStatsView: some View {
        HStack(spacing: 8) {
            homeworkHeaderStatItem(
                title: "Всего",
                value: "\(viewModel.badgeCount(for: .all))",
                color: .blue,
                systemImage: "checklist",
                scope: .all
            )

            homeworkHeaderStatItem(
                title: "Сегодня",
                value: "\(viewModel.badgeCount(for: .today))",
                color: .orange,
                systemImage: "calendar.badge.clock",
                scope: .today
            )

            homeworkHeaderStatItem(
                title: "Проср.",
                value: "\(viewModel.badgeCount(for: .overdue))",
                color: .red,
                systemImage: "exclamationmark.triangle.fill",
                scope: .overdue
            )
        }
    }

    private func homeworkHeaderStatItem(
        title: String,
        value: String,
        color: Color,
        systemImage: String,
        scope: HomeworkViewModel.HomeworkScope
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isFiltersExpanded = true
            }

            guard viewModel.selectedScope != scope else {
                return
            }

            viewModel.selectedScope = scope

            Task {
                await viewModel.reloadForFilters(api: appState.api)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                viewModel.selectedScope == scope
                    ? color.opacity(0.16)
                    : color.opacity(0.09)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        viewModel.selectedScope == scope
                            ? color.opacity(0.55)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(value)")
    }

    private func homeworkScopeButton(_ scope: HomeworkViewModel.HomeworkScope) -> some View {
        HomeworkScopeBadgeButton(
            title: scope.rawValue,
            count: viewModel.badgeCount(for: scope),
            isSelected: viewModel.selectedScope == scope
        ) {
            guard viewModel.selectedScope != scope else {
                return
            }

            viewModel.selectedScope = scope

            Task {
                await viewModel.reloadForFilters(api: appState.api)
            }
        }
    }

    private var homeworkSection: some View {
        Section("Задания") {
            if viewModel.isLoading || !viewModel.hasLoadedInitialData {
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
            } else if viewModel.selectedStudentID == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Выберите ученика")
                        .font(.headline)

                    Text("Домашние задания показываются только для конкретного ученика.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else if viewModel.groupedByDate.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Заданий нет")
                        .font(.headline)

                    Text("За выбранный период домашние задания не найдены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.groupedByDate) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.dateTitle(group.date))
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)

                        ForEach(group.items) { item in
                            Button {
                                selectedHomework = item
                            } label: {
                                HomeworkRowView(
                                    item: item,
                                    deadlineTitle: viewModel.deadlineStatusTitle(item.due_date),
                                    isOverdue: viewModel.isHomeworkOverdue(item),
                                    isToday: viewModel.isToday(item.due_date),
                                    canUpdateCompletion: canUpdateCompletion(for: item),
                                    isUpdatingCompletion: viewModel.updatingCompletionIDs.contains(item.id),
                                    onCompletionChange: { isCompleted in
                                        Task {
                                            _ = await viewModel.updateCompletion(
                                                api: appState.api,
                                                homework: item,
                                                studentID: completionStudentID(for: item),
                                                isCompleted: isCompleted
                                            )
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)

                            if item.id != group.items.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct CreateHomeworkView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: HomeworkViewModel
    @State private var formData = HomeworkFormData()

    var body: some View {
        NavigationStack {
            Form {
                Section("Класс и предмет") {
                    Picker("Класс", selection: $formData.classID) {
                        Text("Выберите класс").tag(0)

                        ForEach(viewModel.classes) { item in
                            Text(item.name).tag(item.id)
                        }
                    }

                    Picker("Предмет", selection: $formData.subjectID) {
                        Text("Выберите предмет").tag(0)

                        ForEach(viewModel.subjects) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                }

                Section("Задание") {
                    TextField("Тема", text: $formData.title)

                    TextField("Описание", text: $formData.description, axis: .vertical)
                        .lineLimit(3...8)

                    TextField("Дата сдачи, например 2026-05-22", text: $formData.dueDate)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Новое ДЗ")
            .onAppear {
                if formData.classID == 0 {
                    formData.classID = viewModel.classes.first?.id ?? 0
                }

                if formData.subjectID == 0 {
                    formData.subjectID = viewModel.subjects.first?.id ?? 0
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createHomework(
                                api: appState.api,
                                formData: formData
                            )

                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Создать")
                        }
                    }
                    .disabled(!isValid || viewModel.isSaving)
                }
            }
        }
    }

    private var isValid: Bool {
        formData.classID != 0
        && formData.subjectID != 0
        && !formData.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.dueDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct HomeworkRowView: View {
    let item: HomeworkDTO
    let deadlineTitle: String
    let isOverdue: Bool
    let isToday: Bool
    let canUpdateCompletion: Bool
    let isUpdatingCompletion: Bool
    let onCompletionChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.subject_name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(item.isCompleted ? "Выполнено" : deadlineTitle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                Text(item.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Label(item.class_name, systemImage: "rectangle.3.group.fill")
                    Spacer()
                    Label(item.due_date, systemImage: "calendar")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let teacherName = item.teacher_name, !teacherName.isEmpty {
                    Label(teacherName, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    completionLabel

                    Spacer()

                    if canUpdateCompletion {
                        Button {
                            onCompletionChange(!item.isCompleted)
                        } label: {
                            if isUpdatingCompletion {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(
                                    item.isCompleted ? "Снять выполнение" : "Отметить выполненным",
                                    systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill"
                                )
                                .font(.caption)
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isUpdatingCompletion)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var completionLabel: some View {
        Label(
            item.isCompleted ? "Выполнено" : "Не выполнено",
            systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle"
        )
        .font(.caption2)
        .foregroundStyle(item.isCompleted ? .green : .secondary)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: statusSystemImage)
                .foregroundStyle(statusColor)
        }
    }

    private var statusSystemImage: String {
        if item.isCompleted {
            return "checkmark.circle.fill"
        }

        return isOverdue ? "exclamationmark.triangle.fill" : "doc.text.fill"
    }

    private var statusColor: Color {
        if item.isCompleted {
            return .green
        }

        if isOverdue {
            return .red
        }

        if isToday {
            return .orange
        }

        return .blue
    }
}

struct HomeworkDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let homework: HomeworkDTO
    let deadlineTitle: String
    let isOverdue: Bool
    let isToday: Bool
    let canManage: Bool
    let canUpdateCompletion: Bool
    let isUpdatingCompletion: Bool
    let completionStudentID: Int
    let onCompletionChange: (Bool) -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(homework.subject_name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()

                            Text(homework.isCompleted ? "Выполнено" : deadlineTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.15))
                                .foregroundStyle(statusColor)
                                .clipShape(Capsule())
                        }

                        Text(homework.title)
                            .font(.headline)

                        if !homework.description.isEmpty {
                            Text(homework.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Информация") {
                    LabeledContent("Класс", value: homework.class_name)
                    LabeledContent("Предмет", value: homework.subject_name)
                    LabeledContent("Срок", value: homework.due_date)
                    LabeledContent("Статус срока", value: deadlineTitle)
                    LabeledContent("Выполнение", value: homework.isCompleted ? "Выполнено" : "Не выполнено")

                    if let teacherName = homework.teacher_name, !teacherName.isEmpty {
                        LabeledContent("Учитель", value: teacherName)
                    }

                    if let completedAt = homework.completed_at, homework.isCompleted {
                        LabeledContent("Выполнено в", value: completedAt)
                    }

                    LabeledContent("ID задания", value: "\(homework.id)")
                }

                Section("Выполнение") {
                    if canUpdateCompletion {
                        Button {
                            onCompletionChange(!homework.isCompleted)
                        } label: {
                            HStack {
                                Label(
                                    homework.isCompleted ? "Снять выполнение" : "Отметить выполненным",
                                    systemImage: homework.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill"
                                )

                                Spacer()

                                if isUpdatingCompletion {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(isUpdatingCompletion || completionStudentID == 0)
                    } else {
                        Label(
                            homework.isCompleted ? "Ученик отметил домашку выполненной" : "Домашка пока не отмечена выполненной",
                            systemImage: homework.isCompleted ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(homework.isCompleted ? .green : .secondary)

                        Text("Менять отметку могут только родитель или ученик при выбранном ученике.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if canManage {
                    Section("Управление") {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить домашнее задание", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Домашнее задание")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Удалить ДЗ?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    onDelete()
                }
            } message: {
                Text("Домашнее задание будет удалено.")
            }
        }
    }

    private var statusColor: Color {
        if homework.isCompleted {
            return .green
        }

        if isOverdue {
            return .red
        }

        if isToday {
            return .orange
        }

        return .blue
    }
}

struct HomeworkScopeBadgeButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.black)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? AppTheme.primaryDark : Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white : AppTheme.primaryDark)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? Color.white : AppTheme.heading)
            .padding(.vertical, 7)
            .padding(.horizontal, 7)
            .background(isSelected ? AppTheme.primaryDark : AppTheme.primarySoft.opacity(0.70))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}