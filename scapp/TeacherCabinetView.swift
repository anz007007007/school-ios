import SwiftUI

struct TeacherCabinetView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TeacherCabinetViewModel()

    @State private var selectedSection: TeacherSection = .journal
    @State private var filterClassID: Int = 0
    @State private var filterSubjectID: Int = 0
    @State private var filterDate: Date = Date()
    @State private var gradeDraft: TeacherGradeCellDraft?
    @State private var editingGrade: TeacherGradeDTO?
    @State private var homeworkTemplate: TeacherHomeworkDTO?
    @State private var homeworkForDelete: TeacherHomeworkDTO?
    @State private var showError = false
    @State private var finalGradeDraft: TeacherFinalGradeDraft?
    @State private var showFinalGradeStudentPicker = false
    @State private var finalGradeScopeForSelection: TeacherCabinetViewModel.FinalGradeScope = .term

    enum TeacherSection: String, CaseIterable, Identifiable {
        case journal = "Журнал"
        case today = "Сегодня"
        case classes = "Классы"
        case grades = "Оценки"
        case homework = "Домашка"
        case attendance = "Посещаемость"
        case finalGrades = "Итоговые"
        case terms = "Периоды"

        var id: String {
            rawValue
        }

        var icon: String {
            switch self {
            case .journal:
                return "tablecells.fill"
            case .today:
                return "calendar"
            case .classes:
                return "person.3.fill"
            case .grades:
                return "star.fill"
            case .homework:
                return "pencil.and.list.clipboard"
            case .attendance:
                return "checkmark.circle.fill"
            case .finalGrades:
                return "graduationcap.fill"
            case .terms:
                return "calendar.badge.clock"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()

                        Text("Загружаем кабинет учителя...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerView
                            sectionPicker

                            if selectedSection == .journal
                                || selectedSection == .classes {
                                filtersView
                            }

                            contentView
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(appState.isAdmin ? "Журнал школы" : "Кабинет учителя")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadInitialDataIfNeeded(api: appState.api)

                filterClassID = viewModel.selectedClassID != 0
                    ? viewModel.selectedClassID
                    : (viewModel.classes.first?.id ?? 0)

                filterSubjectID = viewModel.selectedSubjectID != 0
                    ? viewModel.selectedSubjectID
                    : (viewModel.subjects.first?.id ?? 0)

                filterDate = viewModel.selectedJournalDate
            }
            .refreshable {
                await viewModel.loadAll(api: appState.api)

                filterClassID = viewModel.selectedClassID != 0
                    ? viewModel.selectedClassID
                    : (viewModel.classes.first?.id ?? 0)

                filterSubjectID = viewModel.selectedSubjectID != 0
                    ? viewModel.selectedSubjectID
                    : (viewModel.subjects.first?.id ?? 0)

                filterDate = viewModel.selectedJournalDate
            }
            .onChange(of: viewModel.errorMessage) {
                showError = viewModel.errorMessage != nil
            }
            .sheet(item: $gradeDraft) { draft in
                TeacherQuickGradeSheet(
                    draft: draft,
                    viewModel: viewModel
                )
                .environmentObject(appState)
            }
            .sheet(item: $editingGrade) { grade in
                NavigationStack {
                    TeacherGradeFormView(
                        viewModel: viewModel,
                        gradeToEdit: grade
                    )
                    .environmentObject(appState)
                }
            }
            .sheet(item: $homeworkTemplate) { item in
                NavigationStack {
                    TeacherHomeworkFormView(
                        viewModel: viewModel,
                        template: item
                    )
                    .environmentObject(appState)
                }
            }
            .sheet(item: $finalGradeDraft) { draft in
                TeacherFinalGradeFormView(
                    viewModel: viewModel,
                    draft: draft
                )
                .environmentObject(appState)
            }
            .confirmationDialog(
                "Выберите ученика",
                isPresented: $showFinalGradeStudentPicker,
                titleVisibility: .visible
            ) {
                ForEach(viewModel.gradebook) { student in
                    Button(student.student_name) {
                        openFinalGradeForm(
                            student: student,
                            scope: finalGradeScopeForSelection
                        )
                    }
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                Text(finalGradeScopeForSelection == .term ? "Выставление итоговой за период" : "Выставление годовой итоговой")
            }
            .confirmationDialog(
                "Удалить домашнее задание?",
                isPresented: Binding(
                    get: { homeworkForDelete != nil },
                    set: { value in
                        if !value {
                            homeworkForDelete = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let item = homeworkForDelete else {
                        return
                    }

                    Task {
                        await viewModel.deleteHomework(
                            api: appState.api,
                            homeworkID: item.id
                        )
                        homeworkForDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    homeworkForDelete = nil
                }
            } message: {
                Text(homeworkForDelete?.title ?? "")
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("Понятно", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: appState.isAdmin ? "tablecells.fill" : "person.text.rectangle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.isAdmin ? "Общий журнал" : "Кабинет учителя")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.heading)

                Text("Класс, предмет, оценки, ДЗ и посещаемость")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primarySoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
    }

    private var sectionPicker: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(TeacherSection.allCases) { section in
                let isSelected = selectedSection == section

                Button {
                    selectedSection = section

                    Task {
                        await viewModel.loadSectionData(
                            api: appState.api,
                            sectionRawValue: section.rawValue
                        )
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .font(.system(size: 28, weight: .bold))

                        Text(section.rawValue)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .foregroundStyle(isSelected ? Color.white : AppTheme.heading)
                    .background(isSelected ? AppTheme.buttonGradient : LinearGradient(
                        colors: [
                            AppTheme.card,
                            AppTheme.cardSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? AppTheme.primaryDark.opacity(0.45) : AppTheme.border.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(
                        color: isSelected ? AppTheme.primaryDark.opacity(0.22) : AppTheme.accentDark.opacity(0.08),
                        radius: isSelected ? 12 : 8,
                        x: 0,
                        y: isSelected ? 7 : 4
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filtersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Фильтр")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Picker("Класс", selection: $filterClassID) {
                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            Picker("Предмет", selection: $filterSubjectID) {
                ForEach(viewModel.subjects) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            DatePicker(
                "Дата",
                selection: $filterDate,
                displayedComponents: .date
            )
            .tint(AppTheme.control)

            Button {
                Task {
                    await viewModel.applyJournalFilters(
                        api: appState.api,
                        classID: filterClassID,
                        subjectID: filterSubjectID,
                        date: filterDate
                    )
                }
            } label: {
                Label("Показать журнал", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .controlSize(.large)
            .disabled(filterClassID == 0 || filterSubjectID == 0)
            .opacity((filterClassID == 0 || filterSubjectID == 0) ? 0.55 : 1)
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .journal:
            journalTableView
        case .today:
            todayView
        case .classes:
            classesView
        case .grades:
            gradesView
        case .homework:
            homeworkView
        case .attendance:
            attendanceView
        case .finalGrades:
            finalGradesView
        case .terms:
            termsView
        }
    }

    private var journalTableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Таблица оценок")
                .font(.title3)
                .fontWeight(.bold)

            Text("\(viewModel.selectedClassName) · \(viewModel.selectedSubjectName)")
                .foregroundStyle(.secondary)

            if viewModel.filteredStudents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ученики не найдены", systemImage: "person.3")
                        .font(.headline)

                    Text("Выберите другой класс или нажмите «Показать журнал».")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        journalHeaderRow

                        ForEach(viewModel.filteredStudents) { student in
                            journalStudentRow(student)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var journalHeaderRow: some View {
        HStack(spacing: 0) {
            Text("Ученик")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)
                .frame(width: 180, height: 52, alignment: .leading)
                .padding(.horizontal, 8)
                .background(AppTheme.primarySoft.opacity(0.65))

            ForEach(viewModel.journalDates(), id: \.self) { date in
                Text(shortDate(date))
                    .font(.headline)
                    .foregroundStyle(AppTheme.heading)
                    .frame(width: 82, height: 52)
                    .background(AppTheme.primarySoft.opacity(0.65))
            }
        }
    }

    private func journalStudentRow(_ student: TeacherStudentDTO) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(student.full_name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(student.class_name ?? selectedClassNameForStudent(student))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 180, height: 64, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemBackground))

            ForEach(viewModel.journalDates(), id: \.self) { date in
                journalCell(student: student, date: date)
            }
        }
    }

    private func journalCell(student: TeacherStudentDTO, date: String) -> some View {
        Button {
            let classID = resolvedClassID(for: student)
            let subjectID = filterSubjectID != 0
                ? filterSubjectID
                : (viewModel.selectedSubjectID != 0 ? viewModel.selectedSubjectID : (viewModel.subjects.first?.id ?? 0))

            let subjectName = viewModel.subjects.first { $0.id == subjectID }?.name ?? "Предмет"

            gradeDraft = TeacherGradeCellDraft(
                studentID: student.id,
                studentName: student.full_name,
                classID: classID,
                subjectID: subjectID,
                subjectName: subjectName,
                date: date
            )
        } label: {
            let grades = viewModel.gradesFor(studentID: student.id, date: date)

            if grades.isEmpty {
                Text("+")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.control)
                    .frame(width: 82, height: 64)
            } else {
                VStack(spacing: 4) {
                    ForEach(grades.prefix(2)) { grade in
                        Text(grade.grade_value)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 28)
                            .background(AppTheme.buttonGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(width: 82, height: 64)
            }
        }
        .buttonStyle(.plain)
        .background(AppTheme.card)
        .overlay(
            Rectangle()
                .stroke(AppTheme.border.opacity(0.45), lineWidth: 0.5)
        )
    }

    private var todayView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сегодня")
                .font(.title3)
                .fontWeight(.bold)

            Text(todayWeekdayTitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)

            if viewModel.schedule.isEmpty {
                TeacherEmptyStateView(
                    title: "Расписание не загружено",
                    subtitle: "Нажмите обновление или проверьте расписание в админке.",
                    icon: "calendar"
                )
            } else if todayScheduleLessons.isEmpty {
                TeacherEmptyStateView(
                    title: "Сегодня уроков нет",
                    subtitle: "В расписании нет уроков на \(todayWeekdayTitle.lowercased()).",
                    icon: "calendar.badge.exclamationmark"
                )
            } else {
                ForEach(todayScheduleLessons) { lesson in
                    TeacherInfoCard(
                        title: lesson.subject_name ?? "Урок",
                        subtitle: "\(lessonTimeTitle(lesson)) · \(lesson.class_name ?? "Класс") · кабинет \(lesson.room ?? "не указан")",
                        icon: "clock.fill"
                    )
                }
            }

            TeacherActionButton(title: "Открыть журнал оценок", icon: "tablecells.fill", color: .orange) {
                selectedSection = .journal
            }
        }
    }

    private var todayWeekdayTitle: String {
        switch todayBackendWeekday {
        case 1:
            return "Понедельник"
        case 2:
            return "Вторник"
        case 3:
            return "Среда"
        case 4:
            return "Четверг"
        case 5:
            return "Пятница"
        case 6:
            return "Суббота"
        case 7:
            return "Воскресенье"
        default:
            return "Сегодня"
        }
    }

    private var classesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Классы и ученики")
                .font(.title3)
                .fontWeight(.bold)

            if viewModel.classes.isEmpty {
                Text("Классы не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.classes) { item in
                    TeacherInfoCard(
                        title: item.name,
                        subtitle: "Класс доступен в журнале",
                        icon: "person.3.fill"
                    )
                }
            }

            Text("Ученики")
                .font(.headline)
                .padding(.top, 8)

            if viewModel.filteredStudents.isEmpty {
                Text("Ученики не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.filteredStudents) { student in
                    TeacherInfoCard(
                        title: student.full_name,
                        subtitle: student.class_name ?? selectedClassNameForStudent(student),
                        icon: "person.fill"
                    )
                }
            }
        }
    }

    // MARK: - Updated Grades View
    private var gradesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Оценки")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.heading)

                    Text("\(viewModel.selectedClassName) · \(viewModel.selectedSubjectName)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.loadGrades(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            gradesFiltersView
            gradesStatsView

            if let successMessage = viewModel.successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if viewModel.canManageGrades || appState.canTeacherManageGrades {
                NavigationLink {
                    TeacherGradeFormView(viewModel: viewModel)
                        .environmentObject(appState)
                } label: {
                    TeacherActionButtonContent(
                        title: "Поставить оценку",
                        icon: "plus.circle.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.filteredTeacherGrades.isEmpty {
                TeacherEmptyStateView(
                    title: "Оценок нет",
                    subtitle: "По выбранным фильтрам оценки не найдены.",
                    icon: "star.fill"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.teacherGradesGroupedByStudent) { group in
                        TeacherGradesStudentGroupCardView(
                            group: group,
                            gradeTypeTitle: gradeTypeTitle,
                            canManage: viewModel.canManageGrades || appState.canTeacherManageGrades,
                            onEdit: { grade in
                                editingGrade = grade
                            },
                            onDelete: { grade in
                                Task {
                                    await viewModel.deleteGrade(
                                        api: appState.api,
                                        gradeID: grade.id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .task {
            if viewModel.grades.isEmpty {
                await viewModel.loadGrades(api: appState.api)
            }

            if viewModel.gradeTypes.isEmpty {
                await viewModel.loadGradeTypes(api: appState.api)
            }
        }
    }

    // MARK: - Grades Filters View
    private var gradesFiltersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Фильтры оценок")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Picker("Класс", selection: $viewModel.gradesSelectedClassID) {
                Text("Текущий класс").tag(0)

                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)
            .onChange(of: viewModel.gradesSelectedClassID) {
                if viewModel.gradesSelectedClassID != 0 {
                    viewModel.selectedClassID = viewModel.gradesSelectedClassID
                }

                Task {
                    await viewModel.loadStudents(api: appState.api)
                    await viewModel.loadGrades(api: appState.api)
                }
            }

            Picker("Предмет", selection: $viewModel.gradesSelectedSubjectID) {
                Text("Текущий предмет").tag(0)

                ForEach(viewModel.subjects) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)
            .onChange(of: viewModel.gradesSelectedSubjectID) {
                if viewModel.gradesSelectedSubjectID != 0 {
                    viewModel.selectedSubjectID = viewModel.gradesSelectedSubjectID
                }

                Task {
                    await viewModel.loadGrades(api: appState.api)
                }
            }

            Picker("Ученик", selection: $viewModel.gradesSelectedStudentID) {
                Text("Все ученики").tag(0)

                ForEach(viewModel.filteredStudents) { student in
                    Text(student.full_name).tag(student.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            Picker("Тип оценки", selection: $viewModel.gradesSelectedType) {
                Text("Все типы").tag("all")

                ForEach(viewModel.availableGradeTypesForFilter) { type in
                    Text(type.name).tag(type.code)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            Picker("Период", selection: $viewModel.gradesDateFilter) {
                ForEach(TeacherCabinetViewModel.GradesDateFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            TextField("Поиск по ученику, классу, оценке, дате", text: $viewModel.gradesSearchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    viewModel.gradesSelectedClassID = viewModel.selectedClassID
                    viewModel.gradesSelectedSubjectID = viewModel.selectedSubjectID
                    viewModel.gradesSelectedStudentID = 0
                    viewModel.gradesSelectedType = "all"
                    viewModel.gradesDateFilter = .currentWeek
                    viewModel.gradesSearchText = ""

                    Task {
                        await viewModel.loadGrades(api: appState.api)
                    }
                } label: {
                    Label("Сбросить", systemImage: "xmark.circle")
                }

                Spacer()

                Text("\(viewModel.filteredTeacherGrades.count) оценок")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    // MARK: - Grades Stats View
    private var gradesStatsView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TeacherMiniStatView(
                    title: "Оценок",
                    value: "\(viewModel.filteredTeacherGrades.count)",
                    color: .blue,
                    icon: "star.fill"
                )

                TeacherMiniStatView(
                    title: "Средний",
                    value: viewModel.teacherGradesAverageText,
                    color: .orange,
                    icon: "chart.line.uptrend.xyaxis"
                )

                TeacherMiniStatView(
                    title: "Двоек",
                    value: "\(viewModel.teacherGradesBadCount)",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
            }

            HStack(spacing: 10) {
                TeacherMiniStatView(
                    title: "Пятёрок",
                    value: "\(viewModel.teacherGradesFiveCount)",
                    color: .green,
                    icon: "5.circle.fill"
                )

                TeacherMiniStatView(
                    title: "Четвёрок",
                    value: "\(viewModel.teacherGradesFourCount)",
                    color: .blue,
                    icon: "4.circle.fill"
                )

                TeacherMiniStatView(
                    title: "Троек",
                    value: "\(viewModel.teacherGradesThreeCount)",
                    color: .orange,
                    icon: "3.circle.fill"
                )
            }
        }
    }

    private var homeworkView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Домашние задания")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("\(viewModel.selectedHomeworkClassName) · \(viewModel.selectedHomeworkSubjectName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.refreshHomeworkScreen(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingHomework)
            }

            homeworkFiltersView

            homeworkStatsView

            if let successMessage = viewModel.successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if viewModel.canManageHomework {
                NavigationLink {
                    TeacherHomeworkFormView(viewModel: viewModel)
                        .environmentObject(appState)
                } label: {
                    TeacherActionButtonContent(
                        title: "Добавить домашнее задание",
                        icon: "plus.circle.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.isLoadingHomework {
                ProgressView("Загружаем домашние задания...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if viewModel.homeworkSelectedClassID == 0 {
                TeacherEmptyStateView(
                    title: "Нет доступных классов",
                    subtitle: "Backend не вернул классы для текущего учителя.",
                    icon: "person.3.fill"
                )
            } else if viewModel.filteredHomework.isEmpty {
                TeacherEmptyStateView(
                    title: "Домашних заданий нет",
                    subtitle: "По выбранному классу и предмету задания не найдены.",
                    icon: "pencil.and.list.clipboard"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredHomework) { item in
                        TeacherHomeworkCardView(
                            item: item,
                            canManage: viewModel.canManageHomework,
                            onCopy: {
                                homeworkTemplate = item
                            },
                            onDelete: {
                                homeworkForDelete = item
                            }
                        )
                    }
                }
            }
        }
        .task {
            if viewModel.homework.isEmpty {
                await viewModel.loadHomeworkScreen(api: appState.api)
            }
        }
    }

    private var homeworkStatsView: some View {
        HStack(spacing: 10) {
            TeacherMiniStatView(
                title: "Показано",
                value: "\(viewModel.homeworkVisibleCount)",
                color: .blue,
                icon: "list.bullet.clipboard"
            )

            TeacherMiniStatView(
                title: "Сегодня",
                value: "\(viewModel.homeworkTodayCount)",
                color: .orange,
                icon: "calendar"
            )

            TeacherMiniStatView(
                title: "Просрочено",
                value: "\(viewModel.homeworkOverdueCount)",
                color: .red,
                icon: "exclamationmark.triangle.fill"
            )
        }
    }

    private var homeworkFiltersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Фильтр домашки")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Picker("Класс", selection: $viewModel.homeworkSelectedClassID) {
                Text("Выберите класс").tag(0)

                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)
            .onChange(of: viewModel.homeworkSelectedClassID) {
                Task {
                    await viewModel.selectHomeworkClass(
                        api: appState.api,
                        classID: viewModel.homeworkSelectedClassID
                    )
                }
            }

            Picker("Предмет", selection: $viewModel.homeworkSelectedSubjectID) {
                Text("Все мои предметы").tag(0)

                ForEach(viewModel.homeworkSubjects) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)
            .disabled(viewModel.homeworkSelectedClassID == 0 || viewModel.homeworkSubjects.isEmpty)
            .onChange(of: viewModel.homeworkSelectedSubjectID) {
                Task {
                    await viewModel.selectHomeworkSubject(
                        api: appState.api,
                        subjectID: viewModel.homeworkSelectedSubjectID
                    )
                }
            }

            Picker("Период", selection: $viewModel.homeworkDateFilter) {
                ForEach(TeacherCabinetViewModel.HomeworkDateFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.homeworkDateFilter) {
                viewModel.selectHomeworkDateFilter(viewModel.homeworkDateFilter)
            }

            TextField("Поиск по заголовку, описанию, предмету", text: $viewModel.homeworkSearchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    viewModel.homeworkSearchText = ""
                    viewModel.homeworkSelectedSubjectID = 0
                    viewModel.homeworkDateFilter = .currentWeek

                    Task {
                        await viewModel.selectHomeworkSubject(
                            api: appState.api,
                            subjectID: 0
                        )
                    }
                } label: {
                    Label("Сбросить", systemImage: "xmark.circle")
                }
                .disabled(
                    viewModel.homeworkSearchText.isEmpty
                    && viewModel.homeworkSelectedSubjectID == 0
                    && viewModel.homeworkDateFilter == .currentWeek
                )

                Spacer()

                Text("\(viewModel.filteredHomework.count) из \(viewModel.homeworkTotalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    private var attendanceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Посещаемость")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("\(viewModel.selectedAttendanceClassName) · \(viewModel.attendanceDateTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.loadAttendanceScreen(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            attendanceSummaryView

            NavigationLink {
                TeacherAttendanceFormView(viewModel: viewModel)
                    .environmentObject(appState)
            } label: {
                TeacherActionButtonContent(
                    title: viewModel.attendance.isEmpty ? "Заполнить посещаемость" : "Изменить посещаемость",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
            .buttonStyle(.plain)

            if viewModel.isLoadingAttendance {
                ProgressView("Загружаем посещаемость...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let warning = viewModel.attendanceWarningMessage {
                TeacherEmptyStateView(
                    title: "Нет данных",
                    subtitle: warning,
                    icon: "calendar.badge.exclamationmark"
                )
            } else if viewModel.attendance.isEmpty {
                TeacherEmptyStateView(
                    title: "Посещаемость не заполнена",
                    subtitle: "Нажмите «Заполнить посещаемость», затем выберите класс, дату и урок.",
                    icon: "person.crop.circle.badge.questionmark"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.attendance) { item in
                        TeacherInfoCard(
                            title: item.student_name,
                            subtitle: "\(item.class_name) · \(item.attendance_date) · \(attendanceStatusTitle(item.status))",
                            icon: attendanceIcon(item.status)
                        )
                    }
                }
            }
        }
        .task {
            if viewModel.attendanceLessons.isEmpty && !viewModel.isLoadingAttendance {
                await viewModel.loadAttendanceScreen(api: appState.api)
            }
        }
    }

    private var attendanceSummaryView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppTheme.control)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.attendanceDateTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Text(viewModel.attendanceWeekdayTitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(AppTheme.control)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.selectedAttendanceClassName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.heading)

                    Text(viewModel.selectedAttendanceLessonTitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()
            }

            Text("Класс, дату и урок можно выбрать в форме заполнения посещаемости.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            if viewModel.attendanceLessons.isEmpty {
                Label("Для текущей выбранной даты уроков нет или они ещё не выбраны", systemImage: "calendar.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                Text("\(viewModel.attendance.count) записей посещаемости")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    // MARK: - Final Grades View
    private var finalGradesView: some View {
        let canManageFinalGrades = appState.canTeacherManageFinalGrades || viewModel.canManageFinalGrades

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Итоговые оценки")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.heading)

                    Text("\(viewModel.selectedClassName) · \(viewModel.selectedSubjectName)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    Text(viewModel.selectedFinalGradesPeriodTitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.control)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.loadGradebook(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingGradebook)
            }

            finalGradesFiltersView

            if canManageFinalGrades {
                Button {
                    finalGradeScopeForSelection = viewModel.finalGradesGradeScope
                    showFinalGradeStudentPicker = true
                } label: {
                    Label(
                        viewModel.finalGradesGradeScope == .term ? "Выставить итоговую за период" : "Выставить годовую итоговую",
                        systemImage: "graduationcap.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(viewModel.gradebook.isEmpty || viewModel.selectedClassID == 0 || viewModel.selectedSubjectID == 0)
                .opacity((viewModel.gradebook.isEmpty || viewModel.selectedClassID == 0 || viewModel.selectedSubjectID == 0) ? 0.55 : 1)
            } else {
                Label("Если у вас есть право grades.manage, но кнопка недоступна — обновите журнал итоговых. Сервер дополнительно проверит доступ к выбранному классу и предмету.", systemImage: "info.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let successMessage = viewModel.successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if viewModel.isLoadingGradebook {
                ProgressView("Загружаем итоговые...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if viewModel.gradebook.isEmpty {
                TeacherEmptyStateView(
                    title: "Итоговые не загружены",
                    subtitle: "Выберите класс, предмет, период и нажмите «Показать итоговые».",
                    icon: "graduationcap.fill"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.gradebook) { student in
                        TeacherFinalGradeStudentCardView(
                                student: student,
                                canManage: canManageFinalGrades,
                                onEditTerm: {
                                    openFinalGradeForm(
                                        student: student,
                                        scope: .term
                                    )
                                },
                                onEditYear: {
                                    openFinalGradeForm(
                                        student: student,
                                        scope: .year
                                    )
                                }
                            )
                    }
                }
            }
        }
        .task {
            if viewModel.terms.isEmpty {
                await viewModel.loadTerms(api: appState.api)
            }

            if viewModel.gradebook.isEmpty {
                await viewModel.loadGradebook(api: appState.api)
            }
        }
    }

    private var finalGradesFiltersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Параметры итоговых")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Picker("Класс", selection: $viewModel.selectedClassID) {
                Text("Выберите класс").tag(0)

                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            Picker("Предмет", selection: $viewModel.selectedSubjectID) {
                Text("Выберите предмет").tag(0)

                ForEach(viewModel.subjects) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            TextField("Учебный год, например 2025-2026", text: $viewModel.finalGradesAcademicYear)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Picker("Период", selection: $viewModel.finalGradesSelectedTermID) {
                Text("Выберите период").tag(0)

                ForEach(viewModel.terms) { term in
                    Text("\(term.name) · \(term.academic_year ?? "")").tag(term.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.control)

            Text("Средний балл и рекомендованная оценка считаются по обычным оценкам внутри выбранного периода. Если выбран «Учебный год» или в датах периода нет оценок, значения могут быть пустыми.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            Picker("Тип итоговой", selection: $viewModel.finalGradesGradeScope) {
                ForEach(TeacherCabinetViewModel.FinalGradeScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    Task {
                        await viewModel.loadTerms(api: appState.api)
                    }
                } label: {
                    Label("Обновить периоды", systemImage: "calendar.badge.clock")
                }

                Spacer()

                Text("\(viewModel.gradebook.count) учеников")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Button {
                Task {
                    await viewModel.loadGradebook(api: appState.api)
                }
            } label: {
                Label("Показать итоговые", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .controlSize(.large)
            .disabled(
                viewModel.selectedClassID == 0
                || viewModel.selectedSubjectID == 0
                || viewModel.finalGradesSelectedTermID == 0
                || viewModel.isLoadingGradebook
            )
            .opacity(
                (
                    viewModel.selectedClassID == 0
                    || viewModel.selectedSubjectID == 0
                    || viewModel.finalGradesSelectedTermID == 0
                    || viewModel.isLoadingGradebook
                ) ? 0.55 : 1
            )
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    private var termsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Учебные периоды")
                .font(.title3)
                .fontWeight(.bold)

            if viewModel.terms.isEmpty {
                Text("Периоды не найдены.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.terms) { term in
                    TeacherInfoCard(
                        title: term.name,
                        subtitle: "\(term.starts_on ?? "дата начала не указана") — \(term.ends_on ?? "дата окончания не указана")",
                        icon: "calendar.badge.clock"
                    )
                }
            }
        }
    }

    private func resolvedClassID(for student: TeacherStudentDTO) -> Int {
        if let classID = student.class_id, classID != 0 {
            return classID
        }

        if filterClassID != 0 {
            return filterClassID
        }

        if viewModel.selectedClassID != 0 {
            return viewModel.selectedClassID
        }

        return viewModel.classes.first?.id ?? 0
    }

    private func selectedClassNameForStudent(_ student: TeacherStudentDTO) -> String {
        if let className = student.class_name, !className.isEmpty {
            return className
        }

        if let classID = student.class_id,
           let classItem = viewModel.classes.first(where: { $0.id == classID }) {
            return classItem.name
        }

        if filterClassID != 0,
           let classItem = viewModel.classes.first(where: { $0.id == filterClassID }) {
            return classItem.name
        }

        if viewModel.selectedClassID != 0,
           let classItem = viewModel.classes.first(where: { $0.id == viewModel.selectedClassID }) {
            return classItem.name
        }

        return "Класс не указан"
    }

    private func shortDate(_ value: String) -> String {
        let parts = value.split(separator: "-")

        if parts.count == 3 {
            return "\(parts[2]).\(parts[1])"
        }

        return value
    }

    private var todayBackendWeekday: Int {
        let appleWeekday = Calendar.current.component(.weekday, from: Date())
        return ((appleWeekday + 5) % 7) + 1
    }

    private var todayScheduleLessons: [TeacherScheduleLessonDTO] {
        viewModel.schedule
            .filter { lesson in
                lesson.weekday == todayBackendWeekday
            }
            .sorted(by: sortScheduleLessons)
    }

    private func sortScheduleLessons(_ first: TeacherScheduleLessonDTO, _ second: TeacherScheduleLessonDTO) -> Bool {
        let firstWeekday = first.weekday ?? 0
        let secondWeekday = second.weekday ?? 0

        if firstWeekday != secondWeekday {
            return firstWeekday < secondWeekday
        }

        let firstNumber = first.lesson_number ?? 0
        let secondNumber = second.lesson_number ?? 0

        if firstNumber != secondNumber {
            return firstNumber < secondNumber
        }

        return (first.starts_at ?? "") < (second.starts_at ?? "")
    }

    private func lessonTimeTitle(_ lesson: TeacherScheduleLessonDTO) -> String {
        let number = lesson.lesson_number.map { "\($0) урок" } ?? "Урок"
        let startsAt = lesson.starts_at ?? ""
        let endsAt = lesson.ends_at ?? ""

        if !startsAt.isEmpty, !endsAt.isEmpty {
            return "\(number), \(startsAt)–\(endsAt)"
        }

        if !startsAt.isEmpty {
            return "\(number), \(startsAt)"
        }

        return number
    }

    private func attendanceStatusTitle(_ status: String) -> String {
        switch status {
        case "present":
            return "присутствует"
        case "absent":
            return "отсутствует"
        case "late":
            return "опоздал"
        case "sick":
            return "болеет"
        case "excused":
            return "уважительная причина"
        default:
            return status
        }
    }

    private func attendanceIcon(_ status: String) -> String {
        switch status {
        case "present":
            return "checkmark.circle.fill"
        case "absent":
            return "xmark.circle.fill"
        case "late":
            return "clock.fill"
        case "sick":
            return "cross.case.fill"
        case "excused":
            return "doc.text.fill"
        default:
            return "checkmark.circle.fill"
        }
    }

    // MARK: - Grade Type Helper
    private func gradeTypeTitle(_ code: String?) -> String {
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Тип не указан"
        }

        return viewModel.gradeTypes.first { $0.code == code }?.name ?? code
    }

    // MARK: - Final Grade Helpers
    private func openFinalGradeForm(
        student: TeacherGradebookStudentDTO,
        scope: TeacherCabinetViewModel.FinalGradeScope
    ) {
        let term = viewModel.selectedFinalGradesTerm

        finalGradeDraft = TeacherFinalGradeDraft(
            studentID: student.student_id,
            studentName: student.student_name,
            classID: viewModel.selectedClassID,
            className: viewModel.selectedClassName,
            subjectID: viewModel.selectedSubjectID,
            subjectName: viewModel.selectedSubjectName,
            termID: term?.id,
            termName: term?.name ?? "Период",
            gradeScope: scope,
            recommendedGrade: student.recommendedGradeDisplay,
            average: student.averageDisplay,
            currentManualGrade: scope == .term
                ? student.term_final?.manualGradeForForm
                : student.year_final?.manualGradeForForm,
            currentComment: scope == .term
                ? student.term_final?.comment
                : student.year_final?.comment
        )
    }
}

struct TeacherGradeCellDraft: Identifiable {
    let id = UUID()
    let studentID: Int
    let studentName: String
    let classID: Int
    let subjectID: Int
    let subjectName: String
    let date: String
}

struct TeacherQuickGradeSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let draft: TeacherGradeCellDraft
    @ObservedObject var viewModel: TeacherCabinetViewModel

    @State private var gradeValue = "5"
    @State private var gradeType = TeacherGradeTypeDTO.fallback.code
    @State private var validationMessage: String?

    private let gradeValues = ["5", "4", "3", "2", "1"]

    private var availableGradeTypes: [TeacherGradeTypeDTO] {
        viewModel.gradeTypes.isEmpty ? [TeacherGradeTypeDTO.fallback] : viewModel.gradeTypes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(draft.studentName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(draft.subjectName) · \(draft.date)")
                        .foregroundStyle(.secondary)
                }

                Section("Оценка") {
                    Picker("Оценка", selection: $gradeValue) {
                        ForEach(gradeValues, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Тип оценки") {
                    Picker("Тип оценки", selection: $gradeType) {
                        ForEach(availableGradeTypes) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
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
                                Text("Поставить оценку")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .appThemedForm()
            .navigationTitle("Оценка")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if viewModel.gradeTypes.isEmpty {
                    await viewModel.loadGradeTypes(api: appState.api)
                }

                if !availableGradeTypes.contains(where: { $0.code == gradeType }) {
                    gradeType = availableGradeTypes.first?.code ?? TeacherGradeTypeDTO.fallback.code
                }
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

    private func save() {
        validationMessage = nil

        guard draft.classID != 0 else {
            validationMessage = "Сначала выберите класс в фильтре"
            return
        }

        guard draft.subjectID != 0 else {
            validationMessage = "Сначала выберите предмет в фильтре"
            return
        }

        let resolvedGradeType = gradeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? TeacherGradeTypeDTO.fallback.code
            : gradeType.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await viewModel.createGrade(
                api: appState.api,
                studentID: draft.studentID,
                classID: draft.classID,
                subjectID: draft.subjectID,
                gradeValue: gradeValue,
                gradeType: resolvedGradeType,
                gradeDate: draft.date
            )

            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}

struct TeacherInfoCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppTheme.accentDark.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct TeacherActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TeacherActionButtonContent(title: title, icon: icon, color: color)
        }
        .buttonStyle(.plain)
    }
}

struct TeacherActionButtonContent: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)

            Text(title)
                .font(.headline)

            Spacer()

            Image(systemName: "chevron.right")
        }
        .foregroundStyle(.white)
        .padding()
        .background(AppTheme.buttonGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppTheme.primaryDark.opacity(0.20), radius: 12, x: 0, y: 6)
    }
}

struct TeacherHomeworkCardView: View {
    let item: TeacherHomeworkDTO
    let canManage: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(item.subject_name) · \(item.class_name)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.control)

                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Сдать до")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(shortDateTitle(item.due_date))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(dueDateColor(item.due_date))
                }
            }

            Text(item.description)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                if let teacherName = item.teacher_name, !teacherName.isEmpty {
                    Label(teacherName, systemImage: "person.text.rectangle.fill")
                }

                if let createdAt = item.created_at, !createdAt.isEmpty {
                    Label("Создано: \(createdAt)", systemImage: "clock")
                }

                Label("ID: \(item.id)", systemImage: "number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if canManage {
                Divider()

                HStack {
                    Button {
                        onCopy()
                    } label: {
                        Label("Создать похожее", systemImage: "doc.on.doc.fill")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Удалить", systemImage: "trash.fill")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppTheme.accentDark.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    private func shortDateTitle(_ value: String) -> String {
        let parts = value.split(separator: "-")

        if parts.count == 3 {
            return "\(parts[2]).\(parts[1]).\(parts[0])"
        }

        return value
    }

    private func dueDateColor(_ value: String) -> Color {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")

        guard let date = formatter.date(from: value) else {
            return AppTheme.text
        }

        if Calendar.current.isDateInToday(date) {
            return .orange
        }

        if date < Calendar.current.startOfDay(for: Date()) {
            return .red
        }

        return .green
    }
}

struct TeacherMiniStatView: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.heading)

            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
    }
}

struct TeacherEmptyStateView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.muted)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
    }
}

struct TeacherFinalGradeStudentCardView: View {
    let student: TeacherGradebookStudentDTO
    let canManage: Bool
    let onEditTerm: () -> Void
    let onEditYear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.student_name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Text("Оценки: \(student.gradesSummary)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)

                    Text(student.attendanceSummary)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Средний")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)

                    Text(student.averageDisplay)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.control)
                }
            }

            HStack(spacing: 10) {
                TeacherFinalGradeMiniValue(
                    title: "Реком.",
                    value: student.recommendedGradeDisplay,
                    color: .orange
                )

                TeacherFinalGradeMiniValue(
                    title: "Период",
                    value: student.finalGradeDisplay,
                    color: .green
                )

                TeacherFinalGradeMiniValue(
                    title: "Годовая",
                    value: student.yearFinalGradeDisplay,
                    color: .purple
                )
            }

            if student.averageDisplay == "—" || student.recommendedGradeDisplay == "—" {
                Label("Нет расчёта: в выбранном периоде может не быть обычных оценок.", systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            if canManage {
                Divider()

                HStack {
                    Button {
                        onEditTerm()
                    } label: {
                        Label("Итог за период", systemImage: "pencil.circle.fill")
                    }

                    Spacer()

                    Button {
                        onEditYear()
                    } label: {
                        Label("Годовая", systemImage: "graduationcap.fill")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppTheme.accentDark.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct TeacherFinalGradeMiniValue: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.primarySoft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TeacherFinalGradeDraft: Identifiable, Hashable {
    let id = UUID()
    let studentID: Int
    let studentName: String
    let classID: Int
    let className: String
    let subjectID: Int
    let subjectName: String
    let termID: Int?
    let termName: String
    let gradeScope: TeacherCabinetViewModel.FinalGradeScope
    let recommendedGrade: String
    let average: String
    let currentManualGrade: String?
    let currentComment: String?
}

struct TeacherGradesStudentGroupCardView: View {
    let group: TeacherGradesStudentGroup
    let gradeTypeTitle: (String?) -> String
    let canManage: Bool
    let onEdit: (TeacherGradeDTO) -> Void
    let onDelete: (TeacherGradeDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.studentName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Text(group.className)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Средний")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)

                    Text(group.averageText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.control)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(group.grades) { grade in
                    TeacherGradeCompactRowView(
                        grade: grade,
                        gradeTypeTitle: gradeTypeTitle(grade.grade_type),
                        canManage: canManage,
                        onEdit: {
                            onEdit(grade)
                        },
                        onDelete: {
                            onDelete(grade)
                        }
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppTheme.accentDark.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct TeacherGradeCompactRowView: View {
    let grade: TeacherGradeDTO
    let gradeTypeTitle: String
    let canManage: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(grade.grade_value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(gradeColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(gradeTypeTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.text)

                Text("\(grade.subject_name) · \(grade.grade_date)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                if let comment = grade.comment,
                   !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
            }

            Spacer()

            if canManage {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.control)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppTheme.primarySoft.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            if canManage {
                onEdit()
            }
        }
    }

    private var gradeColor: Color {
        guard let value = Double(grade.grade_value.replacingOccurrences(of: ",", with: ".")) else {
            return AppTheme.control
        }

        if value >= 5 {
            return .green
        }

        if value >= 4 {
            return .blue
        }

        if value >= 3 {
            return .orange
        }

        return .red
    }
}