import SwiftUI

struct AdminGradeTypesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AdminGradeTypesViewModel()

    @State private var showCreate = false
    @State private var selectedItem: AdminGradeTypeDTO?

    var body: some View {
        List {
            if !viewModel.items.isEmpty {
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
                    ForEach(AdminGradeTypesViewModel.GradeTypeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

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
                                await viewModel.loadItems(api: appState.api)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical)
                } else if viewModel.filteredItems.isEmpty {
                    ContentUnavailableView(
                        "Типы оценок не найдены",
                        systemImage: "star.circle.fill",
                        description: Text("Создайте тип оценки или измените фильтр.")
                    )
                } else {
                    ForEach(viewModel.filteredItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            AdminGradeTypeRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appThemedList()
        .navigationTitle("Типы оценок")
        .searchable(text: $viewModel.searchText, prompt: "Поиск типа оценки")
        .refreshable {
            await viewModel.loadItems(api: appState.api)
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadItems(api: appState.api)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadItems(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            AdminGradeTypeFormScreen(
                mode: .create,
                item: nil,
                viewModel: viewModel
            )
            .environmentObject(appState)
        }
        .sheet(item: $selectedItem) { item in
            AdminGradeTypeFormScreen(
                mode: .edit,
                item: item,
                viewModel: viewModel
            )
            .environmentObject(appState)
        }
    }

    private var statsView: some View {
        let activeCount = viewModel.items.filter { $0.is_active }.count

        return HStack(spacing: 12) {
            AdminGradeTypeStatCard(
                title: "Всего",
                value: "\(viewModel.items.count)",
                color: .blue,
                systemImage: "star.circle.fill"
            )

            AdminGradeTypeStatCard(
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

struct AdminGradeTypeRowView: View {
    let item: AdminGradeTypeDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.is_active ? Color.green.opacity(0.16) : AppTheme.iconSoft.opacity(0.70))
                    .frame(width: 44, height: 44)

                Image(systemName: "star.circle.fill")
                    .foregroundStyle(item.is_active ? .green : AppTheme.icon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(item.code)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                Text("Вес: \(item.weightText) · порядок: \(item.sort_order ?? 0)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.control)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Text(item.is_active ? "Активен" : "Отключен")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.is_active ? .green.opacity(0.15) : AppTheme.primarySoft.opacity(0.55))
                    .foregroundStyle(item.is_active ? .green : AppTheme.muted)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdminGradeTypeStatCard: View {
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

struct AdminGradeTypeFormScreen: View {
    enum Mode {
        case create
        case edit
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let item: AdminGradeTypeDTO?
    @ObservedObject var viewModel: AdminGradeTypesViewModel

    @State private var formData: AdminGradeTypeFormData
    @State private var validationMessage: String?
    @State private var showDeactivateAlert = false

    init(
        mode: Mode,
        item: AdminGradeTypeDTO?,
        viewModel: AdminGradeTypesViewModel
    ) {
        self.mode = mode
        self.item = item
        self.viewModel = viewModel

        _formData = State(
            initialValue: AdminGradeTypeFormData(
                code: item?.code ?? "",
                name: item?.name ?? "",
                description: item?.description ?? "",
                weight: item?.weight ?? "1.00",
                isActive: item?.is_active ?? true,
                sortOrder: item?.sort_order ?? 10
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основные данные") {
                    TextField("Код, например regular", text: $formData.code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(mode == .edit)

                    TextField("Название", text: $formData.name)

                    TextField("Описание", text: $formData.description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Параметры") {
                    TextField("Вес, например 1.00", text: $formData.weight)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Stepper(
                        "Порядок сортировки: \(formData.sortOrder)",
                        value: $formData.sortOrder,
                        in: 0...999
                    )

                    Toggle("Активен", isOn: $formData.isActive)
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

                if mode == .edit {
                    Section("Опасная зона") {
                        Button(role: .destructive) {
                            showDeactivateAlert = true
                        } label: {
                            Label("Отключить тип оценки", systemImage: "xmark.circle.fill")
                        }

                        Text("Отключение не удаляет тип физически, а делает его неактивным.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle(mode == .create ? "Новый тип" : "Тип оценки")
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
                        save()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Отключить тип оценки?", isPresented: $showDeactivateAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Отключить", role: .destructive) {
                    guard let item else {
                        return
                    }

                    Task {
                        let success = await viewModel.deactivateItem(
                            api: appState.api,
                            code: item.code
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Тип оценки \(item?.name ?? "") будет отключён.")
            }
        }
    }

    private func save() {
        validationMessage = nil

        let cleanCode = formData.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWeight = formData.weight.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCode.isEmpty else {
            validationMessage = "Введите код типа оценки"
            return
        }

        guard !cleanName.isEmpty else {
            validationMessage = "Введите название типа оценки"
            return
        }

        guard !cleanWeight.isEmpty else {
            validationMessage = "Введите вес"
            return
        }

        formData.code = cleanCode
        formData.name = cleanName
        formData.weight = cleanWeight

        Task {
            let success: Bool

            switch mode {
            case .create:
                success = await viewModel.createItem(
                    api: appState.api,
                    formData: formData
                )

            case .edit:
                success = await viewModel.updateItem(
                    api: appState.api,
                    code: item?.code ?? cleanCode,
                    formData: formData
                )
            }

            if success {
                dismiss()
            }
        }
    }
}