import SwiftUI

struct AdminParentsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminParentsViewModel()

    @State private var showCreateParent = false
    @State private var selectedParent: AdminParentDTO?

    var body: some View {
        List {
            if !viewModel.parents.isEmpty {
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
                    ForEach(AdminParentsViewModel.ParentFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Родители")
        .searchable(text: $viewModel.searchText, prompt: "Поиск родителя")
        .refreshable {
            await viewModel.loadParents(api: appState.api)
        }
        .task {
            if viewModel.parents.isEmpty {
                await viewModel.loadParents(api: appState.api)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateParent = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadParents(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateParent) {
            AdminCreateParentView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedParent) { parent in
            AdminEditParentView(viewModel: viewModel, parent: parent)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
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
                            await viewModel.loadParents(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredParents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Родители не найдены")
                        .font(.headline)

                    Text("Создайте родителя или измените поиск.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredParents) { parent in
                    Button {
                        selectedParent = parent
                    } label: {
                        AdminParentRowView(parent: parent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.parents.filter { $0.is_active }.count
        let inactiveCount = viewModel.parents.filter { !$0.is_active }.count

        return HStack(spacing: 12) {
            AdminParentStatCard(
                title: "Всего",
                value: "\(viewModel.parents.count)",
                color: .blue,
                systemImage: "figure.2.and.child.holdinghands"
            )

            AdminParentStatCard(
                title: "Активные",
                value: "\(activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )

            AdminParentStatCard(
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

struct AdminParentRowView: View {
    let parent: AdminParentDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(parent.is_active ? Color.green.opacity(0.16) : Color.red.opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: "figure.2.and.child.holdinghands")
                    .foregroundStyle(parent.is_active ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(parent.full_name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text("@\(parent.login)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text("\(relationTitle) · \(parent.studentsText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Text(parent.is_active ? "Активен" : "Отключен")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(parent.is_active ? .green.opacity(0.15) : .red.opacity(0.15))
                    .foregroundStyle(parent.is_active ? .green : .red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var relationTitle: String {
        AdminParentRelationOption.title(for: parent.relation_type)
    }
}

struct AdminParentStatCard: View {
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

struct AdminCreateParentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminParentsViewModel
    @State private var formData = AdminParentFormData()
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AdminParentFormView(
                    mode: .create,
                    formData: $formData
                )

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card.opacity(0.96))
                }
            }
            .appThemedForm()
            .navigationTitle("Новый родитель")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
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

    private func save() {
        validationMessage = nil

        let cleanPassword = formData.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanPassword.count >= 6 else {
            validationMessage = "Пароль должен быть не короче 6 символов"
            return
        }

        Task {
            let success = await viewModel.createParent(
                api: appState.api,
                login: formData.login,
                password: cleanPassword,
                fullName: formData.fullName,
                relationType: formData.relationType
            )

            if success {
                dismiss()
            }
        }
    }
}

struct AdminEditParentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminParentsViewModel
    let parent: AdminParentDTO

    @State private var formData: AdminParentFormData
    @State private var showAttachStudent = false
    @State private var studentToDetach: AdminParentStudentShortDTO?
    @State private var showResetPasswordSheet = false
    @State private var showMessageTeachersSheet = false
    @State private var newPassword = ""

    private var currentParent: AdminParentDTO {
        viewModel.parents.first { $0.id == parent.id } ?? parent
    }

    init(viewModel: AdminParentsViewModel, parent: AdminParentDTO) {
        self.viewModel = viewModel
        self.parent = parent

        _formData = State(
            initialValue: AdminParentFormData(
                login: parent.login,
                password: "",
                fullName: parent.full_name,
                relationType: parent.relation_type,
                isActive: parent.is_active
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Данные родителя") {
                    LabeledContent("ID родителя", value: "\(currentParent.id)")
                    LabeledContent("ID пользователя", value: "\(currentParent.user_id)")
                    LabeledContent("Логин", value: currentParent.login)

                    TextField("ФИО", text: $formData.fullName)

                    Picker("Тип родства", selection: $formData.relationType) {
                        ForEach(AdminParentRelationOption.all) { option in
                            Text(option.name).tag(option.code)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Toggle("Активен", isOn: $formData.isActive)
                }

                Section("Дети") {
                    if currentParent.students.isEmpty {
                        Text("Дети не привязаны")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentParent.students) { student in
                            HStack {
                                Label(student.name, systemImage: "graduationcap.fill")

                                Spacer()

                                Button(role: .destructive) {
                                    studentToDetach = student
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        showAttachStudent = true
                    } label: {
                        Label("Привязать ученика", systemImage: "plus.circle.fill")
                    }
                }

                Section("Сообщения") {
                    Button {
                        showMessageTeachersSheet = true
                    } label: {
                        Label("Кому родитель может писать", systemImage: "message.badge.fill")
                    }

                    Text("Если выключить учителя в этом списке, родитель не увидит его в получателях сообщений. Для куратора класса правило тоже должно применяться на сервере.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Безопасность") {
                    Button {
                        showResetPasswordSheet = true
                    } label: {
                        Label("Сбросить пароль", systemImage: "key.fill")
                    }

                    Text("После сброса родитель сможет войти только с новым паролем.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                            _ = await viewModel.updateParent(
                                api: appState.api,
                                parentID: currentParent.id,
                                fullName: formData.fullName,
                                relationType: formData.relationType,
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
            .sheet(isPresented: $showAttachStudent) {
                AttachStudentToParentView(
                    viewModel: viewModel,
                    parentID: currentParent.id
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showResetPasswordSheet) {
                AdminParentResetPasswordSheet(
                    viewModel: viewModel,
                    parent: currentParent,
                    newPassword: $newPassword
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showMessageTeachersSheet) {
                AdminParentMessageTeachersView(
                    viewModel: viewModel,
                    parent: currentParent
                )
                .environmentObject(appState)
            }
            .alert("Отвязать ученика?", isPresented: Binding(
                get: {
                    studentToDetach != nil
                },
                set: { newValue in
                    if !newValue {
                        studentToDetach = nil
                    }
                }
            )) {
                Button("Отмена", role: .cancel) {
                    studentToDetach = nil
                }

                Button("Отвязать", role: .destructive) {
                    guard let student = studentToDetach else {
                        return
                    }

                    Task {
                        let success = await viewModel.detachStudent(
                            api: appState.api,
                            parentID: currentParent.id,
                            studentID: student.id
                        )

                        if success {
                            studentToDetach = nil
                        }
                    }
                }
            } message: {
                if let student = studentToDetach {
                    Text("Ученик \(student.name) будет отвязан от родителя.")
                }
            }
        }
    }

    private var isFormValid: Bool {
        !formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminParentResetPasswordSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminParentsViewModel
    let parent: AdminParentDTO

    @Binding var newPassword: String
    @State private var repeatedPassword = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Родитель") {
                    LabeledContent("ФИО", value: parent.full_name)
                    LabeledContent("Логин", value: parent.login)
                }

                Section("Новый пароль") {
                    SecureField("Введите новый пароль", text: $newPassword)
                    SecureField("Повторите пароль", text: $repeatedPassword)

                    if !newPassword.isEmpty && newPassword.count < 6 {
                        Label("Пароль должен быть не короче 6 символов", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Text("Минимальная длина пароля — 6 символов.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            }
            .appThemedForm()
            .navigationTitle("Сброс пароля")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newPassword = ""
                        repeatedPassword = ""
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сбросить")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        let cleanPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRepeatedPassword = repeatedPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanPassword.count >= 6 else {
            validationMessage = "Пароль должен быть не короче 6 символов"
            return
        }

        guard cleanPassword == cleanRepeatedPassword else {
            validationMessage = "Пароль и повтор не совпадают"
            return
        }

        Task {
            let success = await viewModel.resetPassword(
                api: appState.api,
                userID: parent.user_id,
                newPassword: cleanPassword
            )

            if success {
                newPassword = ""
                repeatedPassword = ""
                dismiss()
            }
        }
    }
}

struct AttachStudentToParentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminParentsViewModel
    let parentID: Int

    @State private var searchText = ""

    private var currentParent: AdminParentDTO? {
        viewModel.parents.first { $0.id == parentID }
    }

    private var availableStudents: [AdminStudentDTO] {
        let attachedIDs = Set(currentParent?.students.map { $0.id } ?? [])

        var result = viewModel.students.filter { student in
            !attachedIDs.contains(student.id)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { student in
                student.fullName.localizedCaseInsensitiveContains(query)
                || student.first_name.localizedCaseInsensitiveContains(query)
                || student.last_name.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Родитель") {
                    if let currentParent {
                        LabeledContent("ФИО", value: currentParent.full_name)
                        LabeledContent("Логин", value: currentParent.login)
                    } else {
                        Text("Родитель не найден")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Ученики") {
                    if viewModel.students.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Загрузка учеников...")
                            Spacer()
                        }
                        .padding(.vertical)
                    } else if availableStudents.isEmpty {
                        Text("Нет доступных учеников для привязки")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableStudents) { student in
                            Button {
                                Task {
                                    let success = await viewModel.attachStudent(
                                        api: appState.api,
                                        parentID: parentID,
                                        studentID: student.id
                                    )

                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(student.fullName)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.text)

                                        Text("ID: \(student.id)")
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
            .navigationTitle("Привязать ученика")
            .searchable(text: $searchText, prompt: "Поиск ученика")
            .task {
                if viewModel.students.isEmpty {
                    await viewModel.loadStudents(api: appState.api)
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

struct AdminParentMessageTeachersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminParentsViewModel
    let parent: AdminParentDTO

    @State private var allowedTeacherIDs: Set<Int> = []
    @State private var searchText = ""

    private var filteredTeachers: [AdminParentMessageTeacherDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return viewModel.messageTeachers
        }

        return viewModel.messageTeachers.filter {
            $0.full_name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Родитель") {
                    LabeledContent("ФИО", value: parent.full_name)
                    LabeledContent("Логин", value: parent.login)

                    Text("Отметьте учителей, которых родитель будет видеть в списке получателей сообщений.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        allowedTeacherIDs = Set(viewModel.messageTeachers.map { $0.teacher_id })
                    } label: {
                        Label("Разрешить всех", systemImage: "checkmark.circle.fill")
                    }

                    Button(role: .destructive) {
                        allowedTeacherIDs.removeAll()
                    } label: {
                        Label("Запретить всех", systemImage: "xmark.circle.fill")
                    }
                }

                Section("Учителя") {
                    if viewModel.isLoadingMessageTeachers {
                        HStack {
                            Spacer()
                            ProgressView("Загрузка учителей...")
                            Spacer()
                        }
                        .padding(.vertical)
                    } else if filteredTeachers.isEmpty {
                        Text("Учителя не найдены")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredTeachers) { teacher in
                            Toggle(isOn: Binding(
                                get: {
                                    allowedTeacherIDs.contains(teacher.teacher_id)
                                },
                                set: { isAllowed in
                                    if isAllowed {
                                        allowedTeacherIDs.insert(teacher.teacher_id)
                                    } else {
                                        allowedTeacherIDs.remove(teacher.teacher_id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(teacher.full_name)
                                        .font(.headline)

                                    Text("teacher_id: \(teacher.teacher_id), user_id: \(teacher.user_id)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(AppTheme.control)
                        }
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

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Доступ к сообщениям")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Поиск учителя")
            .task {
                await viewModel.loadMessageTeachers(
                    api: appState.api,
                    parentID: parent.id
                )

                allowedTeacherIDs = Set(
                    viewModel.messageTeachers
                        .filter { $0.is_allowed }
                        .map { $0.teacher_id }
                )
            }
            .refreshable {
                await viewModel.loadMessageTeachers(
                    api: appState.api,
                    parentID: parent.id
                )

                allowedTeacherIDs = Set(
                    viewModel.messageTeachers
                        .filter { $0.is_allowed }
                        .map { $0.teacher_id }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.saveMessageTeachers(
                                api: appState.api,
                                parentID: parent.id,
                                allowedTeacherIDs: allowedTeacherIDs
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
                    .disabled(viewModel.isSaving || viewModel.isLoadingMessageTeachers)
                }
            }
        }
    }
}