import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TextbooksView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TextbooksViewModel()

    @State private var showCreate = false
    @State private var selectedItem: TextbookDTO?
    @State private var openedURL: URL?

    private var canManage: Bool {
        appState.isAdmin || appState.isManager
    }

    var body: some View {
        List {
            headerSection

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.danger)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            filtersSection

            Section("Материалы") {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Загрузка учебников...")
                        Spacer()
                    }
                    .padding(.vertical)
                } else if viewModel.filteredItems.isEmpty {
                    ContentUnavailableView(
                        "Учебники не найдены",
                        systemImage: "books.vertical.fill",
                        description: Text("Измените фильтры или поисковый запрос.")
                    )
                } else {
                    ForEach(viewModel.filteredItems) { item in
                        TextbookRowView(
                            item: item,
                            canManage: canManage,
                            onOpen: {
                                openFile(item)
                            },
                            onEdit: {
                                selectedItem = item
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteItem(
                                        api: appState.api,
                                        itemID: item.id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .appThemedList()
        .navigationTitle("Учебники")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Поиск по названию")
        .refreshable {
            await viewModel.refresh(api: appState.api)
        }
        .task {
            await viewModel.loadInitialData(api: appState.api)
        }
        .toolbar {
            if canManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.refresh(api: appState.api)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showCreate) {
            TextbookFormView(
                mode: .create,
                item: nil,
                viewModel: viewModel
            )
            .environmentObject(appState)
        }
        .sheet(item: $selectedItem) { item in
            TextbookFormView(
                mode: .edit,
                item: item,
                viewModel: viewModel
            )
            .environmentObject(appState)
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.blue.opacity(0.14))
                        .frame(width: 58, height: 58)

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.blue)
                }

                Text("Учебники и материалы")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.heading)

                Text(canManage ? "Просматривайте, скачивайте и управляйте учебными материалами." : "Просматривайте и скачивайте доступные учебные материалы.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)

                if !viewModel.items.isEmpty {
                    HStack(spacing: 10) {
                        Text("Всего: \(viewModel.items.count)")
                        Text("Активные: \(viewModel.activeCount)")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.control)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            Picker("Класс", selection: $viewModel.selectedClassID) {
                Text("Все классы").tag(0)

                ForEach(viewModel.classes) { item in
                    Text(item.name).tag(item.id)
                }
            }

            Picker("Предмет", selection: $viewModel.selectedSubjectID) {
                Text("Все предметы").tag(0)

                ForEach(viewModel.subjects) { item in
                    Text(item.name).tag(item.id)
                }
            }

            Picker("Тип", selection: $viewModel.selectedMaterialType) {
                Text("Все типы").tag("all")

                ForEach(viewModel.materialTypes) { item in
                    Text(item.name).tag(item.code)
                }
            }

            Button {
                Task {
                    await viewModel.loadItems(api: appState.api)
                }
            } label: {
                Label("Применить фильтры", systemImage: "line.3.horizontal.decrease.circle.fill")
            }
            .tint(AppTheme.control)
        }
    }

    private func openFile(_ item: TextbookDTO) {
        guard let url = item.fullFileURL else {
            viewModel.errorMessage = "Файл для этого материала не указан."
            return
        }

        UIApplication.shared.open(url)
    }
}

struct TextbookRowView: View {
    let item: TextbookDTO
    let canManage: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if !item.is_active {
                            Text("Отключён")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.primarySoft.opacity(0.75))
                                .foregroundStyle(AppTheme.muted)
                                .clipShape(Capsule())
                        }
                    }

                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if let description = item.description,
                       !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()
            }

            HStack {
                Button {
                    onOpen()
                } label: {
                    Label("Открыть / скачать", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.control)
                .disabled(item.fullFileURL == nil)

                if canManage {
                    Spacer()

                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                    }
                    .tint(AppTheme.muted)
                }
            }
        }
        .padding(.vertical, 6)
        .alert("Удалить учебник?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}

            Button("Удалить", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Материал «\(item.title)» будет удалён.")
        }
    }

    private var iconName: String {
        switch item.material_type {
        case "textbook":
            return "book.closed.fill"
        case "workbook":
            return "pencil.and.list.clipboard"
        case "methodical":
            return "doc.text.fill"
        case "presentation":
            return "rectangle.on.rectangle.angled"
        default:
            return "books.vertical.fill"
        }
    }

    private var iconColor: Color {
        switch item.material_type {
        case "textbook":
            return .blue
        case "workbook":
            return .orange
        case "methodical":
            return .purple
        case "presentation":
            return .pink
        default:
            return .indigo
        }
    }
}

struct TextbookFormView: View {
    enum Mode {
        case create
        case edit
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let item: TextbookDTO?
    @ObservedObject var viewModel: TextbooksViewModel

    @State private var formData: TextbookFormData
    @State private var validationMessage: String?
    @State private var showFileImporter = false

    init(
        mode: Mode,
        item: TextbookDTO?,
        viewModel: TextbooksViewModel
    ) {
        self.mode = mode
        self.item = item
        self.viewModel = viewModel

        _formData = State(
            initialValue: TextbookFormData(
                title: item?.title ?? "",
                description: item?.description ?? "",
                materialType: item?.material_type ?? "textbook",
                classID: item?.class_id ?? 0,
                subjectID: item?.subject_id ?? 0,
                sortOrder: item?.sort_order ?? 10,
                isActive: item?.is_active ?? true,
                fileURL: nil
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основные данные") {
                    TextField("Название", text: $formData.title)

                    TextField("Описание", text: $formData.description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Тип материала", selection: $formData.materialType) {
                        ForEach(viewModel.materialTypes) { type in
                            Text(type.name).tag(type.code)
                        }
                    }
                }

                Section("Привязка") {
                    Picker("Класс", selection: $formData.classID) {
                        Text("Без привязки к классу").tag(0)

                        ForEach(viewModel.classes) { item in
                            Text(item.name).tag(item.id)
                        }
                    }

                    Picker("Предмет", selection: $formData.subjectID) {
                        Text("Без привязки к предмету").tag(0)

                        ForEach(viewModel.subjects) { item in
                            Text(item.name).tag(item.id)
                        }
                    }

                    Text("Класс и предмет можно не выбирать. Тогда материал будет общим.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Параметры") {
                    Stepper(
                        "Порядок сортировки: \(formData.sortOrder)",
                        value: $formData.sortOrder,
                        in: 0...999
                    )

                    Toggle("Активен", isOn: $formData.isActive)
                }

                Section("Файл") {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(
                            formData.fileURL == nil ? "Выбрать файл" : "Заменить файл",
                            systemImage: "doc.badge.plus"
                        )
                    }

                    if let fileURL = formData.fileURL {
                        Label(fileURL.lastPathComponent, systemImage: "doc.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.control)
                    } else if mode == .edit, item?.file_url != nil {
                        Label("Текущий файл сохранится, если не выбрать новый.", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Text("Для нового материала файл обязателен.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.danger)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle(mode == .create ? "Новый учебник" : "Учебник")
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
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    .pdf,
                    .text,
                    .plainText,
                    .image,
                    .jpeg,
                    .png,
                    .presentation,
                    .spreadsheet,
                    .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else {
                return
            }

            do {
                formData.fileURL = try copyImportedFileToTemporaryDirectory(selectedURL)
            } catch {
                validationMessage = "Не удалось подготовить файл к загрузке: \(error.localizedDescription)"
            }

        case .failure(let error):
            validationMessage = "Не удалось выбрать файл: \(error.localizedDescription)"
        }
    }

    private func copyImportedFileToTemporaryDirectory(_ sourceURL: URL) throws -> URL {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("TextbookUploads", isDirectory: true)

        if !fileManager.fileExists(atPath: temporaryDirectory.path) {
            try fileManager.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
        }

        let safeFilename = sourceURL.lastPathComponent.isEmpty
            ? "textbook-file"
            : sourceURL.lastPathComponent

        let destinationURL = temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(safeFilename)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func save() {
        validationMessage = nil

        formData.title = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)
        formData.description = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !formData.title.isEmpty else {
            validationMessage = "Введите название учебника."
            return
        }

        guard !formData.materialType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Выберите тип материала."
            return
        }

        if mode == .create, formData.fileURL == nil {
            validationMessage = "Выберите файл учебника."
            return
        }

        Task {
            let success: Bool

            switch mode {
            case .create:
                success = await viewModel.createItem(
                    api: appState.api,
                    formData: formData
                )

            case .edit:
                guard let item else {
                    validationMessage = "Не найден учебник для редактирования."
                    return
                }

                success = await viewModel.updateItem(
                    api: appState.api,
                    itemID: item.id,
                    formData: formData
                )
            }

            if success {
                dismiss()
            }
        }
    }
}