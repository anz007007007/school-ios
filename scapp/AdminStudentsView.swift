import SwiftUI

struct AdminStudentsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminStudentsViewModel()

    @State private var showCreateStudent = false
    @State private var selectedStudent: AdminStudentDTO?

    var body: some View {
        List {
            if !viewModel.students.isEmpty {
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
                Picker("Статус", selection: $viewModel.selectedStatus) {
                    ForEach(AdminStudentsViewModel.StudentStatusFilter.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Ученики")
        .searchable(text: $viewModel.searchText, prompt: "Поиск ученика")
        .refreshable {
            await viewModel.loadInitialData(api: appState.api)
        }
        .task {
            await viewModel.loadInitialData(api: appState.api)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateStudent = true
                } label: {
                    Image(systemName: "plus")
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
        .sheet(isPresented: $showCreateStudent) {
            AdminCreateStudentView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedStudent) { student in
            AdminEditStudentView(viewModel: viewModel, student: student)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
            if viewModel.isLoading && viewModel.students.isEmpty {
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
            } else if viewModel.filteredStudents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Ученики не найдены")
                        .font(.headline)

                    Text("Создайте ученика или измените поиск.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredStudents) { student in
                    Button {
                        selectedStudent = student
                    } label: {
                        AdminStudentRowView(student: student)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.students.filter { $0.status == "active" }.count
        let withoutClassCount = viewModel.students.filter { $0.class_id == nil }.count

        return HStack(spacing: 12) {
            AdminStudentStatCard(
                title: "Всего",
                value: "\(viewModel.students.count)",
                color: .blue,
                systemImage: "graduationcap.fill"
            )

            AdminStudentStatCard(
                title: "Активные",
                value: "\(activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )

            AdminStudentStatCard(
                title: "Без класса",
                value: "\(withoutClassCount)",
                color: .orange,
                systemImage: "person.crop.circle.badge.questionmark"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminStudentRowView: View {
    let student: AdminStudentDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(student.fullName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(student.classTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.control)

                Text("\(genderTitle) · \(statusTitle)")
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 4)
    }

    private var genderTitle: String {
        switch student.gender {
        case "male":
            return "Мальчик"
        case "female":
            return "Девочка"
        case "unknown":
            return "Пол не указан"
        default:
            return student.gender
        }
    }

    private var statusTitle: String {
        switch student.status {
        case "active":
            return "Активен"
        case "inactive":
            return "Неактивен"
        case "graduated":
            return "Выпускник"
        default:
            return student.status
        }
    }

    private var statusColor: Color {
        switch student.status {
        case "active":
            return .green
        case "inactive":
            return .red
        case "graduated":
            return AppTheme.control
        default:
            return AppTheme.muted
        }
    }
}

struct AdminStudentStatCard: View {
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

struct AdminCreateStudentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminStudentsViewModel
    @State private var formData = AdminStudentFormData()

    var body: some View {
        NavigationStack {
            Form {
                AdminStudentFormView(
                    formData: $formData,
                    classes: viewModel.classes
                )
            }
            .appThemedForm()
            .navigationTitle("Новый ученик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createStudent(
                                api: appState.api,
                                firstName: formData.firstName,
                                lastName: formData.lastName,
                                gender: formData.gender,
                                status: formData.status,
                                classID: formData.classID
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
        !formData.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditStudentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminStudentsViewModel
    let student: AdminStudentDTO

    @State private var formData: AdminStudentFormData
    @State private var showDeleteAlert = false

    init(viewModel: AdminStudentsViewModel, student: AdminStudentDTO) {
        self.viewModel = viewModel
        self.student = student

        _formData = State(
            initialValue: AdminStudentFormData(
                firstName: student.first_name,
                lastName: student.last_name,
                gender: student.gender,
                status: student.status,
                classID: student.class_id ?? 0
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                AdminStudentFormView(
                    formData: $formData,
                    classes: viewModel.classes
                )

                Section("Информация") {
                    LabeledContent("ID ученика", value: "\(student.id)")
                    LabeledContent("Текущий класс", value: student.classTitle)

                    Text("Логин и пароль ученику создаёт родитель в своём профиле. Сервер не разрешает администратору создавать учётные данные ученика через этот endpoint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить ученика", systemImage: "trash.fill")
                    }

                    Text("Не удаляйте ученика, если к нему уже привязаны оценки, родители, финансы или документы.")
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
            }
            .appThemedForm()
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
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
                            let success = await viewModel.updateStudent(
                                api: appState.api,
                                studentID: student.id,
                                firstName: formData.firstName,
                                lastName: formData.lastName,
                                gender: formData.gender,
                                status: formData.status,
                                classID: formData.classID
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
            .alert("Удалить ученика?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteStudent(
                            api: appState.api,
                            studentID: student.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Ученик \(student.fullName) будет удалён. Это действие может быть невозможно, если к ученику привязаны данные.")
            }
        }
    }

    private var isFormValid: Bool {
        !formData.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}