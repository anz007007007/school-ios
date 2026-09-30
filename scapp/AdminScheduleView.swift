import SwiftUI

struct AdminScheduleView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminScheduleViewModel()

    @State private var showCreateLesson = false
    @State private var selectedLesson: AdminScheduleLessonDTO?

    var body: some View {
        List {
            if !viewModel.lessons.isEmpty {
                Section {
                    statsView
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Picker("День", selection: $viewModel.selectedWeekday) {
                    ForEach(AdminScheduleViewModel.WeekdayFilter.allCases) { day in
                        Text(day.rawValue).tag(day)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Расписание")
        .searchable(text: $viewModel.searchText, prompt: "Поиск")
        .refreshable {
            await viewModel.loadInitialData(api: appState.api)
        }
        .task {
            if viewModel.lessons.isEmpty {
                await viewModel.loadInitialData(api: appState.api)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateLesson = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.classes.isEmpty || viewModel.subjects.isEmpty)
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
        .sheet(isPresented: $showCreateLesson) {
            AdminCreateScheduleLessonView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedLesson) { lesson in
            AdminEditScheduleLessonView(viewModel: viewModel, lesson: lesson)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Уроки") {
            if viewModel.isLoading {
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
            } else if viewModel.filteredLessons.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Расписание пустое")
                        .font(.headline)

                    Text("Создайте урок или измените фильтр.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredLessons) { lesson in
                    Button {
                        selectedLesson = lesson
                    } label: {
                        AdminScheduleLessonRowView(
                            lesson: lesson,
                            weekdayTitle: viewModel.weekdayTitle(lesson.weekday)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            AdminScheduleStatCard(
                title: "Уроков",
                value: "\(viewModel.lessons.count)",
                color: .blue,
                systemImage: "calendar"
            )

            AdminScheduleStatCard(
                title: "Классов",
                value: "\(Set(viewModel.lessons.map { $0.class_id }).count)",
                color: .green,
                systemImage: "rectangle.3.group.fill"
            )

            AdminScheduleStatCard(
                title: "Предметов",
                value: "\(Set(viewModel.lessons.map { $0.subject_id }).count)",
                color: .orange,
                systemImage: "book.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminScheduleLessonRowView: View {
    let lesson: AdminScheduleLessonDTO
    let weekdayTitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 48, height: 48)

                Text("\(lesson.lesson_number)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(lesson.class_name) / \(lesson.subject_name)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(weekdayTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text("\(lesson.starts_at) – \(lesson.ends_at)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)

                if let teacherName = lesson.teacher_name, !teacherName.isEmpty {
                    Text(teacherName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 4)
    }
}

struct AdminScheduleStatCard: View {
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
                .foregroundStyle(AppTheme.heading)

            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: AppTheme.accentDark.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct AdminCreateScheduleLessonView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminScheduleViewModel
    @State private var formData = AdminScheduleFormData()

    var body: some View {
        NavigationStack {
            Form {
                AdminScheduleFormView(
                    formData: $formData,
                    classes: viewModel.classes,
                    subjects: viewModel.subjects,
                    teachers: viewModel.teachers
                )
            }
            .appThemedForm()
            .navigationTitle("Новый урок")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if formData.classID == 0 {
                    formData.classID = viewModel.classes.first?.id ?? 0
                }

                if formData.subjectID == 0 {
                    formData.subjectID = viewModel.subjects.first?.id ?? 0
                }

                if formData.teacherID == 0 {
                    formData.teacherID = viewModel.teachers.first?.id ?? 0
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
                            let success = await viewModel.createLesson(
                                api: appState.api,
                                classID: formData.classID,
                                subjectID: formData.subjectID,
                                teacherID: formData.teacherID,
                                weekday: formData.weekday,
                                lessonNumber: formData.lessonNumber,
                                startsAt: formData.startsAt,
                                endsAt: formData.endsAt
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
                    .disabled(!isFormValid || viewModel.isSaving)
                }
            }
        }
    }

    private var isFormValid: Bool {
        formData.classID != 0
        && formData.subjectID != 0
        && formData.teacherID != 0
        && !formData.startsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.endsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditScheduleLessonView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminScheduleViewModel
    let lesson: AdminScheduleLessonDTO

    @State private var formData: AdminScheduleFormData
    @State private var showDeleteAlert = false

    init(viewModel: AdminScheduleViewModel, lesson: AdminScheduleLessonDTO) {
        self.viewModel = viewModel
        self.lesson = lesson

        _formData = State(
            initialValue: AdminScheduleFormData(
                classID: lesson.class_id,
                subjectID: lesson.subject_id,
                teacherID: lesson.teacher_id ?? 0,
                weekday: lesson.weekday,
                lessonNumber: lesson.lesson_number,
                startsAt: lesson.starts_at,
                endsAt: lesson.ends_at
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ID") {
                    LabeledContent("ID урока", value: "\(lesson.id)")
                }

                AdminScheduleFormView(
                    formData: $formData,
                    classes: viewModel.classes,
                    subjects: viewModel.subjects,
                    teachers: viewModel.teachers
                )

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить урок", systemImage: "trash.fill")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.updateLesson(
                                api: appState.api,
                                lessonID: lesson.id,
                                classID: formData.classID,
                                subjectID: formData.subjectID,
                                teacherID: formData.teacherID,
                                weekday: formData.weekday,
                                lessonNumber: formData.lessonNumber,
                                startsAt: formData.startsAt,
                                endsAt: formData.endsAt
                            )

                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(!isFormValid || viewModel.isSaving)
                }
            }
            .alert("Удалить урок?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteLesson(
                            api: appState.api,
                            lessonID: lesson.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Урок \(lesson.class_name) / \(lesson.subject_name) будет удалён из расписания.")
            }
        }
    }

    private var isFormValid: Bool {
        formData.classID != 0
        && formData.subjectID != 0
        && formData.teacherID != 0
        && !formData.startsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.endsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}