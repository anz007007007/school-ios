import SwiftUI
import WebKit

struct DocumentsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DocumentsViewModel()

    @State private var selectedProfile: DocumentProfileDTO?
    @State private var selectedGeneratedDocument: GeneratedDocumentDTO?
    @State private var selectedPublicDocument: PublicDocumentDTO?

    @State private var editingProfile: DocumentProfileDTO?
    @State private var editingPublicDocument: PublicDocumentDTO?
    @State private var publicDocumentToDelete: PublicDocumentDTO?
    @State private var generateProfileID: Int?

    @State private var isShowingCreateProfile = false
    @State private var isShowingCreatePublicDocument = false
    @State private var isShowingGenerateDocument = false
    @State private var isShowingDeleteConfirmation = false

    private var canReadProfiles: Bool {
        appState.canReadDocumentProfiles
    }

    private var canManage: Bool {
        appState.canManageDocuments
    }

    var body: some View {
        NavigationStack {
            List {
                if canReadProfiles {
                    filtersSection
                }

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage = viewModel.errorMessage,
                   !isShowingCreateProfile,
                   editingProfile == nil,
                   !isShowingCreatePublicDocument,
                   editingPublicDocument == nil,
                   !isShowingGenerateDocument {
                    Section {
                        errorView(errorMessage)
                    }
                }

                if canReadProfiles {
                    statsSection
                    profilesSection
                    generatedDocumentsSection
                }

                publicDocumentsSection
            }
            .appThemedList()
            .navigationTitle("Документы")
            .searchable(text: $viewModel.searchText, prompt: "Поиск документов")
            .refreshable {
                await reload()
            }
            .task {
                await reload()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if canManage {
                        Menu {
                            Button {
                                viewModel.errorMessage = nil
                                isShowingCreateProfile = true
                            } label: {
                                Label("Профиль ученика", systemImage: "person.text.rectangle")
                            }

                            Button {
                                openGenerate(profileID: nil)
                            } label: {
                                Label("Сгенерировать", systemImage: "doc.badge.gearshape")
                            }

                            Button {
                                viewModel.errorMessage = nil
                                isShowingCreatePublicDocument = true
                            } label: {
                                Label("Публичный документ", systemImage: "doc.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    Button {
                        Task {
                            await reload()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedProfile) { profile in
                DocumentProfileDetailView(
                    profile: profile,
                    canManage: canManage,
                    onEdit: {
                        selectedProfile = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            viewModel.errorMessage = nil
                            editingProfile = profile
                        }
                    },
                    onGenerate: {
                        selectedProfile = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            openGenerate(profileID: profile.id)
                        }
                    }
                )
            }
            .sheet(item: $selectedGeneratedDocument) { document in
                GeneratedDocumentDetailView(
                    document: document,
                    documentTypeTitle: viewModel.documentTypeTitle(document.document_type),
                    loadHTML: {
                        try await viewModel.loadGeneratedDocumentHTML(
                            api: appState.api,
                            documentID: document.id
                        )
                    }
                )
            }
            .sheet(item: $selectedPublicDocument) { document in
                PublicDocumentDetailView(
                    document: document,
                    canManage: canManage,
                    onEdit: {
                        selectedPublicDocument = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            viewModel.errorMessage = nil
                            editingPublicDocument = document
                        }
                    },
                    onDelete: {
                        selectedPublicDocument = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            publicDocumentToDelete = document
                            isShowingDeleteConfirmation = true
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingCreateProfile) {
                DocumentProfileFormView(
                    profile: nil,
                    students: viewModel.students,
                    parents: viewModel.parents,
                    requiresParent: canManage,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        await viewModel.saveProfile(
                            api: appState.api,
                            formData: formData
                        )
                    }
                )
            }
            .sheet(item: $editingProfile) { profile in
                DocumentProfileFormView(
                    profile: profile,
                    students: viewModel.students,
                    parents: viewModel.parents,
                    requiresParent: canManage,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        await viewModel.saveProfile(
                            api: appState.api,
                            formData: formData
                        )
                    }
                )
            }
            .sheet(isPresented: $isShowingCreatePublicDocument) {
                PublicDocumentFormView(
                    mode: .create,
                    document: nil,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        await viewModel.createPublicDocument(
                            api: appState.api,
                            formData: formData
                        )
                    }
                )
            }
            .sheet(item: $editingPublicDocument) { document in
                PublicDocumentFormView(
                    mode: .edit,
                    document: document,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        await viewModel.updatePublicDocument(
                            api: appState.api,
                            document: document,
                            formData: formData
                        )
                    }
                )
            }
            .sheet(isPresented: $isShowingGenerateDocument) {
                DocumentGenerateFormView(
                    profiles: viewModel.profiles,
                    initialProfileID: generateProfileID,
                    documentTypes: viewModel.documentTypes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        await viewModel.generateDocument(
                            api: appState.api,
                            formData: formData
                        )
                    }
                )
            }
            .confirmationDialog(
                "Удалить публичный документ?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let publicDocumentToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deletePublicDocument(
                            api: appState.api,
                            document: publicDocumentToDelete
                        )

                        self.publicDocumentToDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    publicDocumentToDelete = nil
                }
            } message: {
                if let publicDocumentToDelete {
                    Text("Документ «\(publicDocumentToDelete.title)» будет удалён.")
                }
            }
        }
    }

    private func reload() async {
        await viewModel.loadInitialData(
            api: appState.api,
            canReadProfiles: canReadProfiles,
            canManageProfiles: canManage
        )
    }

    private func openGenerate(profileID: Int?) {
        viewModel.errorMessage = nil
        generateProfileID = profileID
        isShowingGenerateDocument = true
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            if viewModel.isLoadingStudents {
                HStack {
                    Spacer()
                    ProgressView("Загрузка учеников...")
                    Spacer()
                }
            }

            if !viewModel.students.isEmpty {
                Picker("Ученик", selection: $viewModel.selectedStudentID) {
                    Text("Все ученики").tag(0)

                    ForEach(viewModel.students) { student in
                        Text(student.displayTitle).tag(student.id)
                    }
                }
            }

            Picker("Тип документа", selection: $viewModel.selectedDocumentType) {
                Text("Все типы").tag("all")

                ForEach(viewModel.documentTypes, id: \.code) { item in
                    Text(item.title).tag(item.code)
                }
            }

            Button {
                viewModel.searchText = ""
                viewModel.selectedStudentID = 0
                viewModel.selectedDocumentType = "all"
            } label: {
                Label("Сбросить фильтры", systemImage: "xmark.circle")
            }
            .disabled(
                viewModel.searchText.isEmpty
                && viewModel.selectedStudentID == 0
                && viewModel.selectedDocumentType == "all"
            )
        }
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 12) {
                DocumentStatCard(
                    title: "Профилей",
                    value: "\(viewModel.filteredProfiles.count)",
                    color: .blue,
                    systemImage: "person.text.rectangle"
                )

                DocumentStatCard(
                    title: "Заполнено",
                    value: "\(viewModel.completedProfilesCount)",
                    color: .green,
                    systemImage: "checkmark.seal.fill"
                )

                DocumentStatCard(
                    title: "Документов",
                    value: "\(viewModel.filteredGeneratedDocuments.count + viewModel.filteredPublicDocuments.count)",
                    color: .purple,
                    systemImage: "doc.text.fill"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var profilesSection: some View {
        Section("Профили учеников") {
            if viewModel.isLoading && viewModel.profiles.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
                .padding(.vertical)
            } else if viewModel.filteredProfiles.isEmpty {
                emptyView(
                    title: "Профилей нет",
                    subtitle: canManage
                        ? "Создайте профиль документов ученика."
                        : "Профили документов пока не заполнены.",
                    systemImage: "person.text.rectangle"
                )
            } else {
                ForEach(viewModel.filteredProfiles) { profile in
                    Button {
                        selectedProfile = profile
                    } label: {
                        DocumentProfileRowView(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canManage {
                            Button {
                                viewModel.errorMessage = nil
                                editingProfile = profile
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if canManage {
                Button {
                    viewModel.errorMessage = nil
                    isShowingCreateProfile = true
                } label: {
                    Label("Добавить профиль", systemImage: "plus")
                }
            }
        }
    }

    private var generatedDocumentsSection: some View {
        Section("Сгенерированные документы") {
            if viewModel.filteredGeneratedDocuments.isEmpty {
                Text("Сгенерированных документов нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.filteredGeneratedDocuments) { document in
                    Button {
                        selectedGeneratedDocument = document
                    } label: {
                        GeneratedDocumentRowView(
                            document: document,
                            documentTypeTitle: viewModel.documentTypeTitle(document.document_type)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if canManage {
                Button {
                    openGenerate(profileID: nil)
                } label: {
                    Label("Сгенерировать документ", systemImage: "doc.badge.gearshape")
                }
            }
        }
    }

    private var publicDocumentsSection: some View {
        Section("Публичные документы") {
            if viewModel.isLoading && viewModel.publicDocuments.isEmpty && !canReadProfiles {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
                .padding(.vertical)
            } else if viewModel.filteredPublicDocuments.isEmpty {
                Text("Публичных документов нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.filteredPublicDocuments) { document in
                    Button {
                        selectedPublicDocument = document
                    } label: {
                        PublicDocumentRowView(document: document)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canManage {
                            Button(role: .destructive) {
                                publicDocumentToDelete = document
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                viewModel.errorMessage = nil
                                editingPublicDocument = document
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if canManage {
                Button {
                    viewModel.errorMessage = nil
                    isShowingCreatePublicDocument = true
                } label: {
                    Label("Добавить публичный документ", systemImage: "plus")
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Повторить") {
                Task {
                    await reload()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical)
    }

    private func emptyView(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

struct DocumentProfileRowView: View {
    let profile: DocumentProfileDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.displayStudentName)
                    .font(.headline)

                Spacer()

                if profile.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            if let className = profile.class_name, !className.isEmpty {
                Text(className)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !profile.displayParentName.isEmpty {
                Label(profile.displayParentName, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !profile.isCompleted {
                Text("Не все данные для договора заполнены")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GeneratedDocumentRowView: View {
    let document: GeneratedDocumentDTO
    let documentTypeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.title)
                .font(.headline)

            HStack {
                Text(documentTypeTitle)
                    .font(.caption)
                    .foregroundStyle(.blue)

                if let studentName = document.student_full_name, !studentName.isEmpty {
                    Text(studentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let generatedAt = document.generated_at {
                    Text(AppDateFormatter.dateTime(generatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PublicDocumentRowView: View {
    let document: PublicDocumentDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(document.title)
                    .font(.headline)

                Spacer()

                if document.isPublic {
                    Image(systemName: "globe")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if let audience = DocumentTypes.roleTitle(document.target_role_code) {
                    Text(audience)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if let className = document.class_name, !className.isEmpty {
                    Text(className)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if let createdAt = document.created_at {
                    Text(AppDateFormatter.dateTime(createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = document.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DocumentProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: DocumentProfileDTO
    let canManage: Bool
    let onEdit: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(profile.displayStudentName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let className = profile.class_name, !className.isEmpty {
                            Label(className, systemImage: "person.3.fill")
                                .foregroundStyle(.secondary)
                        }

                        Text(profile.isCompleted ? "Данные для договора заполнены" : "Не все данные для договора заполнены")
                            .font(.caption)
                            .foregroundStyle(profile.isCompleted ? .green : .orange)
                    }
                    .padding(.vertical)
                }

                detailSection("Ученик", values: [
                    ("ФИО", profile.student_full_name),
                    ("Дата рождения", DocumentDate.display(profile.student_birth_date)),
                    ("Пол", DocumentGender.title(profile.student_gender)),
                    ("Свидетельство о рождении", profile.student_birth_certificate),
                    ("Адрес регистрации", profile.student_registration_address),
                    ("Адрес проживания", profile.student_living_address)
                ])

                detailSection("Родитель / представитель", values: [
                    ("ФИО", profile.parent_full_name),
                    ("Аккаунт", profile.db_parent_name),
                    ("Дата рождения", DocumentDate.display(profile.parent_birth_date)),
                    ("Телефон", profile.parent_phone),
                    ("Email", profile.parent_email)
                ])

                detailSection("Паспорт родителя", values: [
                    ("Серия", profile.parent_passport_series),
                    ("Номер", profile.parent_passport_number),
                    ("Кем выдан", profile.parent_passport_issued_by),
                    ("Дата выдачи", DocumentDate.display(profile.parent_passport_issued_at)),
                    ("Код подразделения", profile.parent_passport_department_code),
                    ("Адрес регистрации", profile.parent_registration_address),
                    ("Адрес проживания", profile.parent_living_address)
                ])

                detailSection("Организация", values: [
                    ("Название", profile.organization_name),
                    ("Руководитель", profile.organization_director),
                    ("Адрес", profile.organization_address),
                    ("ИНН", profile.organization_inn),
                    ("ОГРН", profile.organization_ogrn)
                ])

                if canManage {
                    Section("Управление") {
                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать профиль", systemImage: "pencil")
                        }

                        Button {
                            onGenerate()
                        } label: {
                            Label("Сгенерировать документ", systemImage: "doc.badge.gearshape")
                        }
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func detailSection(
        _ title: String,
        values: [(String, String?)]
    ) -> some View {
        Section(title) {
            let notEmpty = values.filter { _, value in
                !(value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            if notEmpty.isEmpty {
                Text("Не указано")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(notEmpty.enumerated()), id: \.offset) { _, item in
                    LabeledContent(item.0, value: item.1 ?? "")
                }
            }
        }
    }
}

struct GeneratedDocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let document: GeneratedDocumentDTO
    let documentTypeTitle: String
    let loadHTML: () async throws -> String

    @State private var html: String?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(documentTypeTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text(document.title)
                        .font(.headline)

                    if let studentName = document.student_full_name, !studentName.isEmpty {
                        Label(studentName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let generatedAt = document.generated_at {
                        Label(AppDateFormatter.dateTime(generatedAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()

                if let html {
                    DocumentHTMLView(html: html)
                } else if let loadError {
                    VStack(spacing: 12) {
                        Label("Не удалось открыть документ", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)

                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Повторить") {
                            Task {
                                await load()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView("Загрузка документа...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .appScreenBackground()
            .navigationTitle("Документ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        loadError = nil

        do {
            html = try await loadHTML()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Показ HTML сгенерированного документа (сервер отдаёт готовую страницу).
private struct DocumentHTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: URL(string: "https://sc.it-status.ru"))
    }
}

struct PublicDocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let document: PublicDocumentDTO
    let canManage: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var resolvedFileURL: URL? {
        guard let value = document.file_url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return URL(string: value)
        }

        let path = value.hasPrefix("/") ? value : "/\(value)"
        return URL(string: "https://sc.it-status.ru\(path)")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if let audience = DocumentTypes.roleTitle(document.target_role_code) {
                                Text(audience)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            Text(document.isPublic ? "Опубликован" : "Скрыт")
                                .font(.caption)
                                .foregroundStyle(document.isPublic ? .green : .secondary)
                        }

                        Text(document.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let createdAt = document.created_at {
                            Label(AppDateFormatter.dateTime(createdAt), systemImage: "calendar")
                                .foregroundStyle(.secondary)
                        }

                        if let author = document.author_name, !author.isEmpty {
                            Label(author, systemImage: "person.fill")
                                .foregroundStyle(.secondary)
                        }

                        if let className = document.class_name, !className.isEmpty {
                            Label(className, systemImage: "person.3.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Описание") {
                    if let description = document.description, !description.isEmpty {
                        Text(description)
                            .textSelection(.enabled)
                    } else {
                        Text("Описание не указано")
                            .foregroundStyle(.secondary)
                    }
                }

                if let fileURL = resolvedFileURL {
                    Section("Файл") {
                        Button {
                            openURL(fileURL)
                        } label: {
                            Label("Открыть файл", systemImage: "arrow.up.right.square")
                        }
                    }
                }

                if canManage {
                    Section("Управление") {
                        Button {
                            onEdit()
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Документ")
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

struct DocumentGenerateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let profiles: [DocumentProfileDTO]
    let documentTypes: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (DocumentGenerateFormData) async -> Bool

    @State private var profileID: Int
    @State private var documentType: String
    @State private var validationMessage: String?

    init(
        profiles: [DocumentProfileDTO],
        initialProfileID: Int?,
        documentTypes: [(code: String, title: String)],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (DocumentGenerateFormData) async -> Bool
    ) {
        self.profiles = profiles
        self.documentTypes = documentTypes
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _profileID = State(initialValue: initialProfileID ?? profiles.first?.id ?? 0)
        _documentType = State(initialValue: documentTypes.first?.code ?? "contract")
    }

    private func profileTitle(_ profile: DocumentProfileDTO) -> String {
        let parent = profile.displayParentName
        return parent.isEmpty ? profile.displayStudentName : "\(profile.displayStudentName) · \(parent)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Профиль") {
                    if profiles.isEmpty {
                        Text("Сначала создайте профиль документов.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Профиль", selection: $profileID) {
                            Text("Выберите профиль").tag(0)

                            ForEach(profiles) { profile in
                                Text(profileTitle(profile)).tag(profile.id)
                            }
                        }
                    }
                }

                Section {
                    Picker("Тип", selection: $documentType) {
                        ForEach(documentTypes, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }
                } header: {
                    Text("Документ")
                } footer: {
                    Text("Документ заполняется данными выбранного профиля.")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка генерации", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Генерация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Создать")
                        }
                    }
                    .disabled(isSaving || profiles.isEmpty)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard profileID != 0 else {
            validationMessage = "Выберите профиль"
            return
        }

        let formData = DocumentGenerateFormData(
            profileID: profileID,
            documentType: documentType
        )

        Task {
            if await onSave(formData) {
                dismiss()
            }
        }
    }
}

struct DocumentStatCard: View {
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
