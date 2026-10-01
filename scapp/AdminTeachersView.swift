import SwiftUI

struct AdminTeachersView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminTeachersViewModel()

    @State private var showCreateTeacher = false
    @State private var selectedTeacher: AdminTeacherDTO?

    var body: some View {
        List {
            if !viewModel.teachers.isEmpty {
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
                Picker("Фильтр", selection: $viewModel.selectedFilter) {
                    ForEach(AdminTeachersViewModel.TeacherFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Учителя")
        .searchable(text: $viewModel.searchText, prompt: "Поиск учителя")
        .refreshable {
            await viewModel.loadTeachers(api: appState.api)
        }
        .task {
            await viewModel.loadTeachers(api: appState.api)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateTeacher = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadTeachers(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateTeacher) {
            AdminCreateTeacherView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedTeacher) { teacher in
            AdminEditTeacherView(viewModel: viewModel, teacher: teacher)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
            if viewModel.isLoading && viewModel.teachers.isEmpty {
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
                            await viewModel.loadTeachers(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredTeachers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Учителя не найдены")
                        .font(.headline)

                    Text("Создайте учителя или измените поиск.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredTeachers) { teacher in
                    Button {
                        selectedTeacher = teacher
                    } label: {
                        AdminTeacherRowView(teacher: teacher)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.teachers.filter { $0.is_active }.count
        let inactiveCount = viewModel.teachers.filter { !$0.is_active }.count

        return HStack(spacing: 12) {
            AdminTeacherStatCard(
                title: "Всего",
                value: "\(viewModel.teachers.count)",
                color: .blue,
                systemImage: "person.badge.key.fill"
            )

            AdminTeacherStatCard(
                title: "Активные",
                value: "\(activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )

            AdminTeacherStatCard(
                title: "Неактивные",
                value: "\(inactiveCount)",
                color: .red,
                systemImage: "xmark.circle.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminTeacherRowView: View {
    let teacher: AdminTeacherDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(teacher.is_active ? Color.green.opacity(0.16) : Color.red.opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: "person.badge.key.fill")
                    .foregroundStyle(teacher.is_active ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.full_name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text("@\(teacher.login)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text(teacher.assignmentsText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Text(teacher.is_active ? "Активен" : "Отключен")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(teacher.is_active ? .green.opacity(0.15) : .red.opacity(0.15))
                    .foregroundStyle(teacher.is_active ? .green : .red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdminTeacherStatCard: View {
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

struct AdminCreateTeacherView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminTeachersViewModel
    @State private var formData = AdminTeacherFormData()

    var body: some View {
        NavigationStack {
            AdminTeacherFormView(
                mode: .create,
                formData: $formData
            )
            .appThemedForm()
            .navigationTitle("Новый учитель")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createTeacher(
                                api: appState.api,
                                login: formData.login,
                                password: formData.password,
                                fullName: formData.fullName
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
        !formData.login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditTeacherView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminTeachersViewModel
    let teacher: AdminTeacherDTO

    @State private var formData: AdminTeacherFormData
    @State private var showAttachClass = false
    @State private var classToDetach: AdminTeacherAssignmentDTO?
    @State private var protectedAssignment: AdminTeacherAssignmentDTO?

    private var currentTeacher: AdminTeacherDTO {
        viewModel.teachers.first { $0.id == teacher.id } ?? teacher
    }

    init(viewModel: AdminTeachersViewModel, teacher: AdminTeacherDTO) {
        self.viewModel = viewModel
        self.teacher = teacher

        _formData = State(
            initialValue: AdminTeacherFormData(
                login: teacher.login,
                password: "",
                fullName: teacher.full_name,
                isActive: teacher.is_active
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Данные учителя") {
                    LabeledContent("ID учителя", value: "\(currentTeacher.id)")
                    LabeledContent("ID пользователя", value: "\(currentTeacher.user_id)")
                    LabeledContent("Логин", value: currentTeacher.login)

                    TextField("ФИО", text: $formData.fullName)

                    Toggle("Активен", isOn: $formData.isActive)
                }

                Section("Классы и назначения") {
                    if currentTeacher.assignments_list.isEmpty {
                        Text("Нет назначений")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentTeacher.assignments_list) { assignment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(assignment.label)
                                        .font(.headline)

                                    Text("Класс: \(assignment.class_name)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("class_id: \(assignment.class_id)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)

                                    if isSubjectOrExtraAssignment(assignment) {
                                        Text("Назначение связано с предметом или доп. занятием")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    if isSubjectOrExtraAssignment(assignment) {
                                        protectedAssignment = assignment
                                    } else {
                                        classToDetach = assignment
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        showAttachClass = true
                    } label: {
                        Label("Привязать класс", systemImage: "plus.circle.fill")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            _ = await viewModel.updateTeacher(
                                api: appState.api,
                                teacherID: currentTeacher.id,
                                fullName: formData.fullName,
                                isActive: formData.isActive
                            )
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
            .sheet(isPresented: $showAttachClass) {
                AttachClassToTeacherView(
                    viewModel: viewModel,
                    teacherID: currentTeacher.id
                )
                .environmentObject(appState)
            }
            .alert("Отвязать класс?", isPresented: Binding(
                get: {
                    classToDetach != nil
                },
                set: { newValue in
                    if !newValue {
                        classToDetach = nil
                    }
                }
            )) {
                Button("Отмена", role: .cancel) {
                    classToDetach = nil
                }

                Button("Отвязать", role: .destructive) {
                    guard let assignment = classToDetach else {
                        return
                    }

                    Task {
                        let success = await viewModel.detachClass(
                            api: appState.api,
                            teacherID: currentTeacher.id,
                            classID: assignment.class_id
                        )

                        if success {
                            classToDetach = nil
                        }
                    }
                }
            } message: {
                if let assignment = classToDetach {
                    Text("Класс \(assignment.class_name) будет отвязан от учителя.")
                }
            }
            .alert("Это не простая привязка класса", isPresented: Binding(
                get: {
                    protectedAssignment != nil
                },
                set: { newValue in
                    if !newValue {
                        protectedAssignment = nil
                    }
                }
            )) {
                Button("Понятно", role: .cancel) {
                    protectedAssignment = nil
                }
            } message: {
                if let assignment = protectedAssignment {
                    Text("Назначение «\(assignment.label)» связано с предметом или дополнительным занятием. Его нужно удалять в разделе предметов, расписания или кружков, а не через простую отвязку класса.")
                }
            }
        }
    }

    private func isSubjectOrExtraAssignment(_ assignment: AdminTeacherAssignmentDTO) -> Bool {
        assignment.label.contains("/")
    }

    private var isFormValid: Bool {
        !formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AttachClassToTeacherView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminTeachersViewModel
    let teacherID: Int

    @State private var searchText = ""

    private var currentTeacher: AdminTeacherDTO? {
        viewModel.teachers.first { $0.id == teacherID }
    }

    private var availableClasses: [AdminClassDTO] {
        let attachedIDs = Set(currentTeacher?.assignments_list.map { $0.class_id } ?? [])

        var result = viewModel.classes.filter { item in
            !attachedIDs.contains(item.id)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(query)
                || item.academic_year.localizedCaseInsensitiveContains(query)
                || item.education_level.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Учитель") {
                    if let currentTeacher {
                        LabeledContent("ФИО", value: currentTeacher.full_name)
                        LabeledContent("Логин", value: currentTeacher.login)
                    } else {
                        Text("Учитель не найден")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Классы") {
                    if viewModel.classes.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Загрузка классов...")
                            Spacer()
                        }
                        .padding(.vertical)
                    } else if availableClasses.isEmpty {
                        Text("Нет доступных классов для привязки")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableClasses) { item in
                            Button {
                                Task {
                                    let success = await viewModel.attachClass(
                                        api: appState.api,
                                        teacherID: teacherID,
                                        classID: item.id
                                    )

                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.text)

                                        Text("\(item.academic_year) · \(item.students_count) уч.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.muted)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
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
            .appThemedList()
            .navigationTitle("Привязать класс")
            .searchable(text: $searchText, prompt: "Поиск класса")
            .task {
                if viewModel.classes.isEmpty {
                    await viewModel.loadClasses(api: appState.api)
                }
            }
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