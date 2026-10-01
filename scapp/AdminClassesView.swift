import SwiftUI

struct AdminClassesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminClassesViewModel()

    @State private var showCreateClass = false
    @State private var selectedClass: AdminClassDTO?

    var body: some View {
        List {
            if !viewModel.classes.isEmpty {
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

            contentSection
        }
        .appThemedList()
        .navigationTitle("Классы")
        .searchable(text: $viewModel.searchText, prompt: "Поиск класса")
        .refreshable {
            await viewModel.loadInitialData(api: appState.api)
        }
        .task {
            await viewModel.loadInitialData(api: appState.api)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateClass = true
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
        .sheet(isPresented: $showCreateClass) {
            AdminCreateClassView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedClass) { item in
            AdminEditClassView(viewModel: viewModel, item: item)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
            if viewModel.isLoading && viewModel.classes.isEmpty {
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
            } else if viewModel.filteredClasses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Классы не найдены")
                        .font(.headline)

                    Text("Создайте класс или измените поиск.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredClasses) { item in
                    Button {
                        selectedClass = item
                    } label: {
                        AdminClassRowView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let studentsCount = viewModel.classes.reduce(0) { $0 + $1.students_count }

        return HStack(spacing: 12) {
            AdminClassStatCard(
                title: "Классов",
                value: "\(viewModel.classes.count)",
                color: .blue,
                systemImage: "rectangle.3.group.fill"
            )

            AdminClassStatCard(
                title: "Учеников",
                value: "\(studentsCount)",
                color: .green,
                systemImage: "graduationcap.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminClassRowView: View {
    let item: AdminClassDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 44, height: 44)

                Image(systemName: "rectangle.3.group.fill")
                    .foregroundStyle(AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(educationLevelTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text("Куратор: \(item.curatorText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Text("\(item.students_count) уч.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.vertical, 4)
    }

    private var educationLevelTitle: String {
        switch item.education_level {
        case "school":
            return "Школа"
        case "kindergarten":
            return "Детский сад"
        case "additional":
            return "Дополнительное"
        default:
            return item.education_level
        }
    }
}

struct AdminClassStatCard: View {
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

struct AdminCreateClassView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminClassesViewModel
    @State private var formData = AdminClassFormData()

    var body: some View {
        NavigationStack {
            AdminClassFormView(
                formData: $formData,
                teachers: viewModel.teachers
            )
            .appThemedForm()
            .navigationTitle("Новый класс")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createClass(
                                api: appState.api,
                                name: formData.name,
                                educationLevel: formData.educationLevel,
                                academicYear: formData.academicYear,
                                curatorTeacherID: formData.curatorTeacherID
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
        !formData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditClassView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminClassesViewModel
    let item: AdminClassDTO

    @State private var formData: AdminClassFormData
    @State private var showDeleteAlert = false

    init(viewModel: AdminClassesViewModel, item: AdminClassDTO) {
        self.viewModel = viewModel
        self.item = item

        _formData = State(
            initialValue: AdminClassFormData(
                name: item.name,
                educationLevel: item.education_level,
                academicYear: item.academic_year,
                curatorTeacherID: item.curator_teacher_id ?? 0
            )
        )
    }

    var body: some View {
        NavigationStack {
            AdminClassFormView(
                formData: $formData,
                teachers: viewModel.teachers
            )
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
                            let success = await viewModel.updateClass(
                                api: appState.api,
                                classID: item.id,
                                name: formData.name,
                                educationLevel: formData.educationLevel,
                                academicYear: formData.academicYear,
                                curatorTeacherID: formData.curatorTeacherID
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
            .alert("Удалить класс?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteClass(
                            api: appState.api,
                            classID: item.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Запись «\(item.name)» будет удалена. Если в классе есть ученики, сервер не даст удалить его.")
            }
        }
    }

    private var isFormValid: Bool {
        !formData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
