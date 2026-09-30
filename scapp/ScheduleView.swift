import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var showsTableView = true

    private var teacherOnlySchedule: Bool {
        appState.isTeacher && !appState.isAdmin && !appState.isManager
    }

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if !viewModel.lessons.isEmpty {
                    Section {
                        statsView
                    }
                }

                scheduleSection
            }
            .appThemedList()
            .navigationTitle("Расписание")
            .searchable(text: $viewModel.searchText, prompt: "Поиск")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.reloadForFilters(
                        api: appState.api,
                        teacherOnly: teacherOnlySchedule
                    )
                }
            }
            .refreshable {
                await viewModel.loadInitialData(
                    api: appState.api,
                    teacherOnly: teacherOnlySchedule
                )
            }
            .task {
                await appState.markNotificationsReadForRoute(.schedule(notificationID: nil))

                if viewModel.lessons.isEmpty {
                    await viewModel.loadInitialData(
                        api: appState.api,
                        teacherOnly: teacherOnlySchedule
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadInitialData(
                                api: appState.api,
                                teacherOnly: teacherOnlySchedule
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            HStack(spacing: 8) {
                Picker("День", selection: $viewModel.selectedWeekday) {
                    ForEach(ScheduleViewModel.WeekdayFilter.allCases.filter { $0 != .all }) { day in
                        Text(day.rawValue).tag(day)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedWeekday) {
                    Task {
                        await viewModel.reloadForFilters(
                            api: appState.api,
                            teacherOnly: teacherOnlySchedule
                        )
                    }
                }

                Button {
                    viewModel.selectedWeekday = .all
                    showsTableView = true

                    Task {
                        await viewModel.reloadForFilters(
                            api: appState.api,
                            teacherOnly: teacherOnlySchedule
                        )
                    }
                } label: {
                    Text("Все")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(minWidth: 38)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.selectedWeekday == .all ? .blue : .secondary)
            }

            if viewModel.isLoadingStudents {
                HStack {
                    Spacer()
                    ProgressView("Загрузка учеников...")
                    Spacer()
                }
            }

            if !teacherOnlySchedule && !viewModel.students.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    ForEach(viewModel.students) { student in
                        Text(student.student_name).tag(student.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(
                            api: appState.api,
                            teacherOnly: teacherOnlySchedule
                        )
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsTableView.toggle()
                }
            } label: {
                Label(
                    showsTableView ? "Список" : "Табличная часть",
                    systemImage: showsTableView ? "list.bullet" : "tablecells"
                )
            }
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            ScheduleStatCard(
                title: "Уроков",
                value: "\(viewModel.filteredLessons.count)",
                color: .blue,
                systemImage: "calendar"
            )

            ScheduleStatCard(
                title: "Предметов",
                value: "\(viewModel.subjectsCount)",
                color: .orange,
                systemImage: "book.fill"
            )

            ScheduleStatCard(
                title: "Учеников",
                value: "\(viewModel.studentsCount)",
                color: .green,
                systemImage: "person.2.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var scheduleSection: some View {
        Section(sectionTitle) {
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
                            await viewModel.loadInitialData(
                                api: appState.api,
                                teacherOnly: teacherOnlySchedule
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.groupedByDay.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Расписание пустое")
                        .font(.headline)

                    Text("По выбранному фильтру уроки не найдены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else if showsTableView {
                if viewModel.selectedWeekday == .all {
                    weeklyScheduleTableView
                } else {
                    scheduleTableView
                }
            } else {
                ForEach(viewModel.groupedByDay) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.weekdayTitle(group.weekday))
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)

                        ForEach(Array(group.lessons.enumerated()), id: \.element.rowID) { index, lesson in
                            ScheduleLessonTimelineRow(
                                lesson: lesson,
                                showLine: index != group.lessons.count - 1,
                                showStudent: !teacherOnlySchedule && viewModel.selectedStudentID != 0
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var sectionTitle: String {
        if showsTableView {
            return viewModel.selectedWeekday == .all ? "Расписание на неделю" : "Табличная часть"
        }

        return "Уроки"
    }

    private var weeklyScheduleTableView: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.groupedByDay) { group in
                VStack(spacing: 0) {
                    HStack {
                        Text(viewModel.weekdayTitle(group.weekday))
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundStyle(.blue)

                        Spacer()

                        Text("\(group.lessons.count) \(lessonWord(group.lessons.count))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    ForEach(Array(group.lessons.enumerated()), id: \.element.rowID) { index, lesson in
                        HStack(spacing: 6) {
                            Text("\(lesson.lesson_number)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                                .frame(width: 24, alignment: .center)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(lesson.starts_at)–\(lesson.ends_at)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)

                                Text(lesson.subject_name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let room = lesson.room,
                               !room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(room)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .trailing)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            } else {
                                Text("—")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)

                        if index != group.lessons.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.separator.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private func lessonWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        if mod10 == 1 && mod100 != 11 {
            return "урок"
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "урока"
        }

        return "уроков"
    }

    private var scheduleTableView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("№")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .center)

                Text("Время")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .leading)

                Text("Предмет")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Каб.")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ForEach(Array(viewModel.filteredLessons.enumerated()), id: \.element.rowID) { index, lesson in
                HStack(spacing: 6) {
                    Text("\(lesson.lesson_number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                        .frame(width: 26, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.starts_at)
                            .font(.caption2)
                            .fontWeight(.bold)

                        Text(lesson.ends_at)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 78, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.subject_name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if let teacherName = lesson.teacher_name,
                           !teacherName.isEmpty {
                            Text(teacherName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text((lesson.room ?? "").isEmpty ? "—" : (lesson.room ?? "—"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

                if index != viewModel.filteredLessons.count - 1 {
                    Divider()
                }
            }
        }
    }
}

struct ScheduleLessonTimelineRow: View {
    let lesson: ScheduleLessonDTO
    let showLine: Bool
    let showStudent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.18))
                        .frame(width: 40, height: 40)

                    Text("\(lesson.lesson_number)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                if showLine {
                    Rectangle()
                        .fill(.blue.opacity(0.25))
                        .frame(width: 2, height: 92)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(lesson.starts_at)–\(lesson.ends_at)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)

                    Spacer()

                    Text("№ \(lesson.lesson_number)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Text(lesson.subject_name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 5) {
                    Label(lesson.class_name, systemImage: "rectangle.3.group.fill")

                    if showStudent,
                       let studentName = lesson.student_name,
                       !studentName.isEmpty {
                        Label(studentName, systemImage: "person.fill")
                    }

                    if let teacherName = lesson.teacher_name, !teacherName.isEmpty {
                        Label("Учитель: \(teacherName)", systemImage: "person.text.rectangle.fill")
                    }

                    if let room = lesson.room, !room.isEmpty {
                        Label("Кабинет \(room)", systemImage: "door.left.hand.open")
                    }

                    if let note = lesson.note, !note.isEmpty {
                        Label(note, systemImage: "note.text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.vertical, 4)
    }
}

struct ScheduleStatCard: View {
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