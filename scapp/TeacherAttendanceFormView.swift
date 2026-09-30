import SwiftUI

struct TeacherAttendanceFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TeacherCabinetViewModel

    @State private var selectedClassID = 0
    @State private var selectedLessonID = 0
    @State private var selectedDate = Date()
    @State private var statuses: [Int: String] = [:]
    @State private var comments: [Int: String] = [:]
    @State private var validationMessage: String?

    private let statusItems: [(title: String, value: String, color: Color, icon: String)] = [
        ("Был", "present", .green, "checkmark.circle.fill"),
        ("Не был", "absent", .red, "xmark.circle.fill"),
        ("Опоздал", "late", .orange, "clock.fill"),
        ("Болеет", "sick", .purple, "cross.case.fill"),
        ("Уваж.", "excused", .blue, "doc.text.fill")
    ]

    private var students: [TeacherStudentDTO] {
        viewModel.students
            .filter { student in
                guard selectedClassID != 0 else {
                    return true
                }

                if let classID = student.class_id {
                    return classID == selectedClassID
                }

                return true
            }
            .sorted { $0.full_name < $1.full_name }
    }

    private var selectedLesson: TeacherScheduleLessonDTO? {
        viewModel.attendanceLessons.first { $0.id == selectedLessonID }
    }

    private var canEditStudents: Bool {
        selectedClassID != 0
        && selectedLessonID != 0
        && !students.isEmpty
        && !viewModel.attendanceLessons.isEmpty
        && !viewModel.isLoadingAttendance
    }

    var body: some View {
        Form {
            Section {
                Text("Посещаемость")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Выберите класс и дату. Затем приложение покажет только уроки из расписания на выбранный день.")
                    .foregroundStyle(.secondary)
            }

            classAndDateSection
            lessonSection

            if viewModel.isLoadingAttendance {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка...")
                        Spacer()
                    }
                }
            }

            if let warning = viewModel.attendanceWarningMessage {
                Section {
                    Label(warning, systemImage: "info.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if canEditStudents {
                quickActionsSection
                studentsSection
            } else {
                helpSection
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
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

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()

                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить посещаемость")
                                .font(.headline)
                        }

                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving || !canEditStudents)
            }
        }
        .appThemedForm()
        .navigationTitle("Посещаемость")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupInitialState()
        }
    }

    private var classAndDateSection: some View {
        Section {
            Picker("Класс", selection: $selectedClassID) {
                Text("Выберите класс").tag(0)

                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: selectedClassID) {
                Task {
                    validationMessage = nil
                    selectedLessonID = 0
                    statuses = [:]
                    comments = [:]

                    await viewModel.selectAttendanceClass(
                        api: appState.api,
                        classID: selectedClassID
                    )

                    selectedLessonID = viewModel.attendanceSelectedLessonID
                    resetDraftsFromLoadedAttendance()
                }
            }

            DatePicker(
                "Дата",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .onChange(of: selectedDate) {
                Task {
                    validationMessage = nil
                    selectedLessonID = 0
                    statuses = [:]
                    comments = [:]

                    await viewModel.selectAttendanceDate(
                        api: appState.api,
                        date: selectedDate
                    )

                    selectedLessonID = viewModel.attendanceSelectedLessonID
                    resetDraftsFromLoadedAttendance()
                }
            }

            LabeledContent("День недели", value: weekdayTitle(selectedDate))
        } header: {
            Text("1. Класс и дата")
        } footer: {
            Text("Уроки ниже будут показаны только для выбранного дня недели.")
        }
    }

    private var lessonSection: some View {
        Section {
            if selectedClassID == 0 {
                Label("Сначала выберите класс", systemImage: "person.3.fill")
                    .foregroundStyle(.secondary)
            } else if viewModel.isLoadingAttendance {
                ProgressView("Загружаем уроки...")
            } else if viewModel.attendanceLessons.isEmpty {
                Label("На эту дату уроков нет", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Урок", selection: $selectedLessonID) {
                    Text("Выберите урок").tag(0)

                    ForEach(viewModel.attendanceLessons) { lesson in
                        Text(lesson.displayTitle).tag(lesson.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedLessonID) {
                    Task {
                        validationMessage = nil

                        await viewModel.selectAttendanceLesson(
                            api: appState.api,
                            lessonID: selectedLessonID
                        )

                        resetDraftsFromLoadedAttendance()
                    }
                }

                if let selectedLesson {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedLesson.displayTitle)
                            .font(.headline)

                        Text("Дата: \(fullDateTitle(selectedDate))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("2. Урок")
        } footer: {
            Text("Можно выбрать только урок из расписания выбранного класса на выбранную дату.")
        }
    }

    private var helpSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if selectedClassID == 0 {
                    Label("Выберите класс", systemImage: "1.circle.fill")
                } else if viewModel.attendanceLessons.isEmpty {
                    Label("Для выбранной даты нет уроков", systemImage: "calendar.badge.exclamationmark")
                } else if selectedLessonID == 0 {
                    Label("Выберите урок", systemImage: "2.circle.fill")
                } else if students.isEmpty {
                    Label("В выбранном классе нет учеников", systemImage: "person.3.fill")
                }

                Text("После выбора класса, даты и урока появится список учеников для отметки посещаемости.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActionsSection: some View {
        Section("Быстрые действия") {
            Button {
                markAll("present")
            } label: {
                Label("Все присутствуют", systemImage: "checkmark.circle.fill")
            }

            Button {
                markAll("absent")
            } label: {
                Label("Все отсутствуют", systemImage: "xmark.circle.fill")
            }
            .foregroundStyle(.red)
        }
    }

    private var studentsSection: some View {
        Section {
            ForEach(students) { student in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(student.full_name)
                            .font(.headline)

                        Spacer()

                        Text(statusTitle(statuses[student.id] ?? "present"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor(statuses[student.id] ?? "present"))
                    }

                    Picker("Статус", selection: statusBinding(for: student.id)) {
                        ForEach(statusItems, id: \.value) { item in
                            Text(item.title).tag(item.value)
                        }
                    }
                    .pickerStyle(.segmented)

                    if (statuses[student.id] ?? "present") != "present" {
                        TextField(
                            "Комментарий",
                            text: commentBinding(for: student.id)
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("3. Ученики")
        } footer: {
            Text("По умолчанию все ученики отмечены как присутствующие.")
        }
    }

    private func setupInitialState() async {
        if viewModel.classes.isEmpty {
            await viewModel.loadClasses(api: appState.api)
        }

        selectedClassID = viewModel.attendanceSelectedClassID != 0
            ? viewModel.attendanceSelectedClassID
            : (viewModel.selectedClassID != 0 ? viewModel.selectedClassID : (viewModel.classes.first?.id ?? 0))

        selectedDate = viewModel.attendanceSelectedDate

        if selectedClassID != 0 {
            await viewModel.selectAttendanceClass(
                api: appState.api,
                classID: selectedClassID
            )
        } else {
            await viewModel.loadAttendanceScreen(api: appState.api)
            selectedClassID = viewModel.attendanceSelectedClassID
        }

        selectedLessonID = viewModel.attendanceSelectedLessonID
        resetDraftsFromLoadedAttendance()
    }

    private func resetDraftsFromLoadedAttendance() {
        var newStatuses: [Int: String] = [:]
        var newComments: [Int: String] = [:]

        let existing = viewModel.attendanceByStudentID

        for student in students {
            if let item = existing[student.id] {
                newStatuses[student.id] = item.status
                newComments[student.id] = item.comment ?? ""
            } else {
                newStatuses[student.id] = "present"
                newComments[student.id] = ""
            }
        }

        statuses = newStatuses
        comments = newComments
    }

    private func markAll(_ status: String) {
        for student in students {
            statuses[student.id] = status

            if status == "present" {
                comments[student.id] = ""
            }
        }
    }

    private func statusBinding(for studentID: Int) -> Binding<String> {
        Binding(
            get: {
                statuses[studentID] ?? "present"
            },
            set: { newValue in
                statuses[studentID] = newValue

                if newValue == "present" {
                    comments[studentID] = ""
                }
            }
        )
    }

    private func commentBinding(for studentID: Int) -> Binding<String> {
        Binding(
            get: {
                comments[studentID] ?? ""
            },
            set: { newValue in
                comments[studentID] = newValue
            }
        )
    }

    private func save() {
        validationMessage = nil

        guard selectedClassID != 0 else {
            validationMessage = "Выберите класс"
            return
        }

        guard !viewModel.attendanceLessons.isEmpty else {
            validationMessage = "На выбранную дату уроков нет"
            return
        }

        guard selectedLessonID != 0 else {
            validationMessage = "Выберите урок"
            return
        }

        guard viewModel.attendanceLessons.contains(where: { $0.id == selectedLessonID }) else {
            validationMessage = "Выбранный урок не относится к выбранной дате"
            return
        }

        guard !students.isEmpty else {
            validationMessage = "Список учеников пуст"
            return
        }

        let items = students.map { student in
            let status = statuses[student.id] ?? "present"
            let comment = comments[student.id]?.trimmingCharacters(in: .whitespacesAndNewlines)

            return TeacherLessonAttendanceItemDraft(
                studentID: student.id,
                status: status,
                comment: comment?.isEmpty == true ? nil : comment
            )
        }

        Task {
            let saved = await viewModel.saveLessonAttendance(
                api: appState.api,
                classID: selectedClassID,
                lessonID: selectedLessonID,
                attendanceDate: Self.dateFormatter.string(from: selectedDate),
                items: items
            )

            if saved {
                dismiss()
            }
        }
    }

    private func statusTitle(_ value: String) -> String {
        switch value {
        case "present":
            return "Был"
        case "absent":
            return "Не был"
        case "late":
            return "Опоздал"
        case "sick":
            return "Болеет"
        case "excused":
            return "Уваж."
        default:
            return value
        }
    }

    private func statusColor(_ value: String) -> Color {
        switch value {
        case "present":
            return .green
        case "absent":
            return .red
        case "late":
            return .orange
        case "sick":
            return .purple
        case "excused":
            return .blue
        default:
            return .secondary
        }
    }

    private func weekdayTitle(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }

    private func fullDateTitle(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}