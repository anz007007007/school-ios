import SwiftUI

struct AdminSubjectsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminSubjectsViewModel()

    @State private var showCreateSubject = false
    @State private var selectedSubject: AdminSubjectDTO?

    var body: some View {
        List {
            if !viewModel.subjects.isEmpty {
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
        .navigationTitle("Предметы")
        .searchable(text: $viewModel.searchText, prompt: "Поиск предмета")
        .refreshable {
            await viewModel.loadSubjects(api: appState.api)
        }
        .task {
            await viewModel.loadSubjects(api: appState.api)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSubject = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadSubjects(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateSubject) {
            AdminCreateSubjectView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedSubject) { subject in
            AdminEditSubjectView(viewModel: viewModel, subject: subject)
                .environmentObject(appState)
        }
    }

    private var contentSection: some View {
        Section("Список") {
            if viewModel.isLoading && viewModel.subjects.isEmpty {
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
                            await viewModel.loadSubjects(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredSubjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Предметы не найдены")
                        .font(.headline)

                    Text("Создайте предмет или измените поиск.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredSubjects) { subject in
                    Button {
                        selectedSubject = subject
                    } label: {
                        AdminSubjectRowView(subject: subject)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            AdminSubjectStatCard(
                title: "Предметов",
                value: "\(viewModel.subjects.count)",
                color: .blue,
                systemImage: "books.vertical.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminSubjectRowView: View {
    let subject: AdminSubjectDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 44, height: 44)

                Image(systemName: "book.fill")
                    .foregroundStyle(AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 4)
    }
}

struct AdminSubjectStatCard: View {
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

struct AdminCreateSubjectView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminSubjectsViewModel
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый предмет") {
                    TextField("Название", text: $name)
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
            .navigationTitle("Создать предмет")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createSubject(
                                api: appState.api,
                                name: name
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditSubjectView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminSubjectsViewModel
    let subject: AdminSubjectDTO

    @State private var name: String
    @State private var showDeleteAlert = false

    init(viewModel: AdminSubjectsViewModel, subject: AdminSubjectDTO) {
        self.viewModel = viewModel
        self.subject = subject
        _name = State(initialValue: subject.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Предмет") {
                    TextField("Название", text: $name)
                }

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить предмет", systemImage: "trash.fill")
                    }

                    Text("Не удаляйте предмет, если он используется в расписании, оценках или домашних заданиях.")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.updateSubject(
                                api: appState.api,
                                subjectID: subject.id,
                                name: name
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
            .alert("Удалить предмет?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteSubject(
                            api: appState.api,
                            subjectID: subject.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Запись «\(subject.name)» будет удалена. Если предмет уже используется, сервер не даст удалить его.")
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}