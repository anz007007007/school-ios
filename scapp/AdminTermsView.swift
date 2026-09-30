import SwiftUI

struct AdminTermsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminTermsViewModel()

    @State private var showCreateTerm = false
    @State private var selectedTerm: AdminTermDTO?

    var body: some View {
        List {
            if !viewModel.terms.isEmpty {
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
                    ForEach(AdminTermsViewModel.TermFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            contentSection
        }
        .appThemedList()
        .navigationTitle("Учебные периоды")
        .searchable(text: $viewModel.searchText, prompt: "Поиск периода")
        .refreshable {
            await viewModel.loadTerms(api: appState.api)
        }
        .task {
            if viewModel.terms.isEmpty {
                await viewModel.loadTerms(api: appState.api)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateTerm = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadTerms(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateTerm) {
            AdminCreateTermView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedTerm) { term in
            AdminEditTermView(viewModel: viewModel, term: term)
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
                            await viewModel.loadTerms(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredTerms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Периоды не найдены")
                        .font(.headline)

                    Text("Создайте период или измените фильтр.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredTerms) { term in
                    Button {
                        selectedTerm = term
                    } label: {
                        AdminTermRowView(
                            term: term,
                            termTypeTitle: viewModel.termTypeTitle(term.term_type)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.terms.filter { $0.is_active }.count

        return HStack(spacing: 12) {
            AdminTermStatCard(
                title: "Всего",
                value: "\(viewModel.terms.count)",
                color: .blue,
                systemImage: "calendar.badge.clock"
            )

            AdminTermStatCard(
                title: "Активные",
                value: "\(activeCount)",
                color: .green,
                systemImage: "checkmark.circle.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct AdminTermRowView: View {
    let term: AdminTermDTO
    let termTypeTitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(term.is_active ? Color.green.opacity(0.16) : AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 44, height: 44)

                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(term.is_active ? .green : AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(term.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text("\(term.academic_year) · \(termTypeTitle)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text("\(term.starts_at) — \(term.ends_at)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Text(term.is_active ? "Активен" : "Неактивен")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(term.is_active ? .green.opacity(0.15) : AppTheme.primarySoft.opacity(0.55))
                    .foregroundStyle(term.is_active ? .green : AppTheme.muted)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdminTermStatCard: View {
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

struct AdminCreateTermView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminTermsViewModel
    @State private var formData = AdminTermFormData()

    var body: some View {
        NavigationStack {
            AdminTermFormView(formData: $formData)
                .appThemedForm()
                .navigationTitle("Новый период")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                let success = await viewModel.createTerm(
                                    api: appState.api,
                                    name: formData.name,
                                    academicYear: formData.academicYear,
                                    termType: formData.termType,
                                    startsAt: formData.startsAt,
                                    endsAt: formData.endsAt,
                                    isActive: formData.isActive
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
        && !formData.startsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.endsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AdminEditTermView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminTermsViewModel
    let term: AdminTermDTO

    @State private var formData: AdminTermFormData
    @State private var showDeleteAlert = false

    init(viewModel: AdminTermsViewModel, term: AdminTermDTO) {
        self.viewModel = viewModel
        self.term = term

        _formData = State(
            initialValue: AdminTermFormData(
                name: term.name,
                academicYear: term.academic_year,
                termType: term.term_type,
                startsAt: term.starts_at,
                endsAt: term.ends_at,
                isActive: term.is_active
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ID") {
                    LabeledContent("ID периода", value: "\(term.id)")
                }

                AdminTermFormFieldsView(formData: $formData)

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить период", systemImage: "trash.fill")
                    }

                    Text("Не удаляйте период, если он уже используется в оценках или отчётах.")
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
                            let success = await viewModel.updateTerm(
                                api: appState.api,
                                termID: term.id,
                                name: formData.name,
                                academicYear: formData.academicYear,
                                termType: formData.termType,
                                startsAt: formData.startsAt,
                                endsAt: formData.endsAt,
                                isActive: formData.isActive
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
            .alert("Удалить период?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Удалить", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteTerm(
                            api: appState.api,
                            termID: term.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Период \(term.name) будет удалён.")
            }
        }
    }

    private var isFormValid: Bool {
        !formData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.startsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.endsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}