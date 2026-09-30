import SwiftUI

struct HealthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HealthViewModel()

    @State private var selectedCard: HealthCardDTO?
    @State private var editingCard: HealthCardDTO?

    var body: some View {
        NavigationStack {
            Group {
                if !appState.canViewHealth {
                    VStack(spacing: 18) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(AppTheme.muted)

                        Text("Здоровье недоступно")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.heading)

                        Text("У вашей роли нет доступа к просмотру медицинских данных.")
                            .font(.body)
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
                } else {
                    List {
                        filtersSection

                        if let successMessage = viewModel.successMessage {
                            Section {
                                Label(successMessage, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        if !viewModel.cards.isEmpty {
                            Section {
                                statsView
                            }
                        }

                        cardsSection
                    }
                    .appThemedList()
                }
            }
            .navigationTitle("Здоровье")
            .searchable(text: $viewModel.searchText, prompt: "Поиск по медкартам")
            .refreshable {
                if appState.canViewHealth {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .task {
                if appState.canViewHealth && viewModel.cards.isEmpty {
                    await viewModel.loadInitialData(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.canViewHealth {
                        Button {
                            Task {
                                await viewModel.loadInitialData(api: appState.api)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $selectedCard) { card in
                HealthCardDetailView(
                    card: card,
                    canManage: appState.canManageHealth,
                    onEdit: {
                        selectedCard = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            editingCard = card
                        }
                    }
                )
            }
            .sheet(item: $editingCard) { card in
                HealthCardFormView(
                    card: card,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        Task { @MainActor in
                            let saved = await viewModel.saveCard(
                                api: appState.api,
                                formData: formData
                            )

                            if saved {
                                editingCard = nil
                            }
                        }
                    }
                )
            }
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            if viewModel.isLoadingFilters {
                HStack {
                    Spacer()
                    ProgressView("Загрузка фильтров...")
                    Spacer()
                }
            }

            if !viewModel.students.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    Text("Все ученики").tag(0)

                    ForEach(viewModel.students) { student in
                        Text(student.student_name).tag(student.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }
            }

            Button {
                viewModel.searchText = ""
                viewModel.selectedStudentID = 0

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            } label: {
                Label("Сбросить фильтры", systemImage: "xmark.circle")
            }
            .disabled(viewModel.searchText.isEmpty && viewModel.selectedStudentID == 0)
        }
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            HealthStatCard(
                title: "Медкарт",
                value: "\(viewModel.filteredCards.count)",
                color: .blue,
                systemImage: "heart.text.square.fill"
            )

            HealthStatCard(
                title: "Аллергии",
                value: "\(viewModel.allergiesCount)",
                color: .orange,
                systemImage: "exclamationmark.triangle.fill"
            )

            HealthStatCard(
                title: "Важно",
                value: "\(viewModel.importantCount)",
                color: .red,
                systemImage: "cross.case.fill"
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var cardsSection: some View {
        Section("Медкарты") {
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
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Медкарт нет")
                        .font(.headline)

                    Text("По выбранным фильтрам медкарты не найдены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredCards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        HealthCardRowView(card: card)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if appState.canManageHealth {
                            Button {
                                editingCard = card
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
    }
}

struct HealthCardRowView: View {
    let card: HealthCardDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.student_name)
                        .font(.headline)

                    if let className = card.class_name, !className.isEmpty {
                        Text(className)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if card.hasImportantNotes {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                if let bloodType = card.blood_type, !bloodType.isEmpty {
                    Label(bloodType, systemImage: "drop.fill")
                }

                if card.hasAllergies {
                    Label("Аллергии", systemImage: "allergens.fill")
                        .foregroundStyle(.orange)
                }

                if card.hasChronicDiseases {
                    Label("Хроника", systemImage: "cross.case.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct HealthCardDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let card: HealthCardDTO
    let canManage: Bool
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(card.hasImportantNotes ? "Есть важные отметки" : "Без особых отметок")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(card.hasImportantNotes ? .orange.opacity(0.12) : .green.opacity(0.12))
                                .foregroundStyle(card.hasImportantNotes ? .orange : .green)
                                .clipShape(Capsule())

                            Spacer()
                        }

                        Text(card.student_name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let className = card.class_name, !className.isEmpty {
                            Label(className, systemImage: "person.3.fill")
                                .foregroundStyle(.secondary)
                        }

                        if let bloodType = card.blood_type, !bloodType.isEmpty {
                            Label("Группа крови: \(bloodType)", systemImage: "drop.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                healthTextSection(
                    "Аллергии",
                    value: card.allergies,
                    systemImage: "allergens.fill",
                    color: .orange
                )

                healthTextSection(
                    "Хронические заболевания",
                    value: card.chronic_diseases,
                    systemImage: "cross.case.fill",
                    color: .red
                )

                healthTextSection(
                    "Противопоказания",
                    value: card.contraindications,
                    systemImage: "nosign",
                    color: .purple
                )

                healthTextSection(
                    "Прививки",
                    value: card.vaccinations,
                    systemImage: "syringe.fill",
                    color: .blue
                )

                healthTextSection(
                    "Медицинские заметки",
                    value: card.medical_notes,
                    systemImage: "note.text",
                    color: .teal
                )

                healthTextSection(
                    "Экстренный контакт",
                    value: card.emergency_contact,
                    systemImage: "phone.fill",
                    color: .green
                )

                if canManage {
                    Section("Управление") {
                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать медкарту", systemImage: "pencil")
                        }
                    }
                }

                Section("Система") {
                    LabeledContent("ID ученика", value: "\(card.student_id)")
                }
            }
            .appThemedList()
            .navigationTitle("Медкарта")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func healthTextSection(
        _ title: String,
        value: String?,
        systemImage: String,
        color: Color
    ) -> some View {
        Section {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)

                Text(value)
                    .font(.body)
            } else {
                Label("Не указано", systemImage: systemImage)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(title)
        }
    }
}

struct HealthStatCard: View {
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