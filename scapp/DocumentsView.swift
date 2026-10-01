import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DocumentsViewModel()

    @State private var selectedProfile: DocumentProfileDTO?
    @State private var selectedGeneratedDocument: GeneratedDocumentDTO?
    @State private var selectedPublicDocument: PublicDocumentDTO?

    @State private var editingProfile: DocumentProfileDTO?
    @State private var editingPublicDocument: PublicDocumentDTO?
    @State private var publicDocumentToDelete: PublicDocumentDTO?

    @State private var isShowingCreateProfile = false
    @State private var isShowingCreatePublicDocument = false
    @State private var isShowingGenerateDocument = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                statsSection
                profilesSection
                generatedDocumentsSection
                publicDocumentsSection
            }
            .appThemedList()
            .navigationTitle("Документы")
            .searchable(text: $viewModel.searchText, prompt: "Поиск документов")
            .refreshable {
                await viewModel.loadInitialData(api: appState.api)
            }
            .task {
                await viewModel.loadInitialData(api: appState.api)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if appState.canManageDocuments {
                        Menu {
                            Button {
                                isShowingCreateProfile = true
                            } label: {
                                Label("Профиль ученика", systemImage: "person.text.rectangle")
                            }

                            Button {
                                isShowingGenerateDocument = true
                            } label: {
                                Label("Сгенерировать", systemImage: "doc.badge.gearshape")
                            }

                            Button {
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
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedProfile) { profile in
                DocumentProfileDetailView(
                    profile: profile,
                    canManage: appState.canManageDocuments,
                    onEdit: {
                        selectedProfile = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            editingProfile = profile
                        }
                    },
                    onGenerate: {
                        selectedProfile = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isShowingGenerateDocument = true
                        }
                    }
                )
            }
            .sheet(item: $selectedGeneratedDocument) { document in
                GeneratedDocumentDetailView(
                    document: document,
                    documentTypeTitle: viewModel.documentTypeTitle(document.document_type)
                )
            }
            .sheet(item: $selectedPublicDocument) { document in
                PublicDocumentDetailView(
                    document: document,
                    documentTypeTitle: viewModel.documentTypeTitle(document.document_type),
                    canManage: appState.canManageDocuments,
                    onEdit: {
                        selectedPublicDocument = nil

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = DocumentProfileFormData(
                            profileID: formData.profileID,
                            studentID: formData.studentID,
                            passportSeries: String(formData.passportSeries),
                            passportNumber: String(formData.passportNumber),
                            birthCertificate: String(formData.birthCertificate),
                            registrationAddress: String(formData.registrationAddress),
                            residentialAddress: String(formData.residentialAddress),
                            snils: String(formData.snils),
                            medicalPolicy: String(formData.medicalPolicy),
                            parentFullName: String(formData.parentFullName),
                            parentPhone: String(formData.parentPhone),
                            notes: String(formData.notes)
                        )

                        Task { @MainActor in
                            _ = await viewModel.saveProfile(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingProfile) { profile in
                DocumentProfileFormView(
                    profile: profile,
                    students: viewModel.students,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = DocumentProfileFormData(
                            profileID: formData.profileID,
                            studentID: formData.studentID,
                            passportSeries: String(formData.passportSeries),
                            passportNumber: String(formData.passportNumber),
                            birthCertificate: String(formData.birthCertificate),
                            registrationAddress: String(formData.registrationAddress),
                            residentialAddress: String(formData.residentialAddress),
                            snils: String(formData.snils),
                            medicalPolicy: String(formData.medicalPolicy),
                            parentFullName: String(formData.parentFullName),
                            parentPhone: String(formData.parentPhone),
                            notes: String(formData.notes)
                        )

                        Task { @MainActor in
                            _ = await viewModel.saveProfile(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingCreatePublicDocument) {
                PublicDocumentFormView(
                    mode: .create,
                    document: nil,
                    documentTypes: viewModel.documentTypes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = PublicDocumentFormData(
                            title: String(formData.title),
                            documentType: String(formData.documentType),
                            isPublic: formData.isPublic,
                            content: String(formData.content),
                            fileURL: String(formData.fileURL)
                        )

                        Task { @MainActor in
                            _ = await viewModel.createPublicDocument(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingPublicDocument) { document in
                PublicDocumentFormView(
                    mode: .edit,
                    document: document,
                    documentTypes: viewModel.documentTypes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = PublicDocumentFormData(
                            title: String(formData.title),
                            documentType: String(formData.documentType),
                            isPublic: formData.isPublic,
                            content: String(formData.content),
                            fileURL: String(formData.fileURL)
                        )

                        Task { @MainActor in
                            _ = await viewModel.updatePublicDocument(
                                api: appState.api,
                                documentID: document.id,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingGenerateDocument) {
                DocumentGenerateFormView(
                    profiles: viewModel.profiles,
                    students: viewModel.students,
                    documentTypes: viewModel.documentTypes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = DocumentGenerateFormData(
                            profileID: formData.profileID,
                            documentType: String(formData.documentType),
                            titlePrefix: String(formData.titlePrefix),
                            studentIDs: Array(formData.studentIDs)
                        )

                        Task { @MainActor in
                            _ = await viewModel.generateDocument(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
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
                        Text(student.student_name).tag(student.id)
                    }
                }
                .onChange(of: viewModel.selectedStudentID) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }
            }

            Picker("Тип документа", selection: $viewModel.selectedDocumentType) {
                Text("Все типы").tag("all")

                ForEach(viewModel.documentTypes, id: \.code) { item in
                    Text(item.title).tag(item.code)
                }
            }
            .onChange(of: viewModel.selectedDocumentType) {
                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
            }

            Button {
                viewModel.searchText = ""
                viewModel.selectedStudentID = 0
                viewModel.selectedDocumentType = "all"

                Task {
                    await viewModel.reloadForFilters(api: appState.api)
                }
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
                    title: "Готово",
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
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.filteredProfiles.isEmpty {
                emptyView(
                    title: "Профилей нет",
                    subtitle: "Создайте профиль документов ученика.",
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
                        if appState.canManageDocuments {
                            Button {
                                editingProfile = profile
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if appState.canManageDocuments {
                Button {
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

            if appState.canManageDocuments {
                Button {
                    isShowingGenerateDocument = true
                } label: {
                    Label("Сгенерировать документ", systemImage: "doc.badge.gearshape")
                }
            }
        }
    }

    private var publicDocumentsSection: some View {
        Section("Публичные документы") {
            if viewModel.filteredPublicDocuments.isEmpty {
                Text("Публичных документов нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.filteredPublicDocuments) { document in
                    Button {
                        selectedPublicDocument = document
                    } label: {
                        PublicDocumentRowView(
                            document: document,
                            documentTypeTitle: viewModel.documentTypeTitle(document.document_type)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if appState.canManageDocuments {
                            Button(role: .destructive) {
                                publicDocumentToDelete = document
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                editingPublicDocument = document
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if appState.canManageDocuments {
                Button {
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
                    await viewModel.loadInitialData(api: appState.api)
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
            Text(profile.student_name ?? "Ученик \(profile.student_id)")
                .font(.headline)

            if let className = profile.class_name, !className.isEmpty {
                Text(className)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if !(profile.passport_number ?? "").isEmpty {
                    Label("Паспорт", systemImage: "person.text.rectangle")
                }

                if !(profile.birth_certificate ?? "").isEmpty {
                    Label("Свидетельство", systemImage: "doc.text")
                }

                if !(profile.snils ?? "").isEmpty {
                    Label("СНИЛС", systemImage: "checkmark.seal")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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

                if let studentName = document.student_name {
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
    let documentTypeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(document.title)
                    .font(.headline)

                Spacer()

                if document.is_public {
                    Image(systemName: "globe")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(documentTypeTitle)
                    .font(.caption)
                    .foregroundStyle(.blue)

                if let createdAt = document.created_at {
                    Text(AppDateFormatter.dateTime(createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let content = document.content, !content.isEmpty {
                Text(content)
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
                        Text(profile.student_name ?? "Ученик \(profile.student_id)")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let className = profile.class_name, !className.isEmpty {
                            Label(className, systemImage: "person.3.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                detailSection("Паспорт", values: [
                    ("Серия", profile.passport_series),
                    ("Номер", profile.passport_number)
                ])

                detailSection("Свидетельство", values: [
                    ("Номер", profile.birth_certificate)
                ])

                detailSection("Адреса", values: [
                    ("Регистрация", profile.registration_address),
                    ("Проживание", profile.residential_address)
                ])

                detailSection("Документы", values: [
                    ("СНИЛС", profile.snils),
                    ("Медицинский полис", profile.medical_policy)
                ])

                detailSection("Родитель / представитель", values: [
                    ("ФИО", profile.parent_full_name),
                    ("Телефон", profile.parent_phone)
                ])

                detailSection("Заметки", values: [
                    ("", profile.notes)
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

                Section("Система") {
                    LabeledContent("ID профиля", value: "\(profile.id)")
                    LabeledContent("ID ученика", value: "\(profile.student_id)")
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
                    if item.0.isEmpty {
                        Text(item.1 ?? "")
                    } else {
                        LabeledContent(item.0, value: item.1 ?? "")
                    }
                }
            }
        }
    }
}

struct GeneratedDocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let document: GeneratedDocumentDTO
    let documentTypeTitle: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(documentTypeTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())

                        Text(document.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let studentName = document.student_name {
                            Label(studentName, systemImage: "person.fill")
                                .foregroundStyle(.secondary)
                        }

                        if let generatedAt = document.generated_at {
                            Label(AppDateFormatter.dateTime(generatedAt), systemImage: "calendar")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Содержимое") {
                    if let content = document.content, !content.isEmpty {
                        Text(content)
                            .textSelection(.enabled)
                    } else {
                        Text("Содержимое не загружено")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Система") {
                    LabeledContent("ID документа", value: "\(document.id)")
                    LabeledContent("ID профиля", value: "\(document.profile_id)")
                    LabeledContent("Тип", value: document.document_type)
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

struct PublicDocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let document: PublicDocumentDTO
    let documentTypeTitle: String
    let canManage: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(documentTypeTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            Spacer()

                            Text(document.is_public ? "Публичный" : "Закрытый")
                                .font(.caption)
                                .foregroundStyle(document.is_public ? .green : .secondary)
                        }

                        Text(document.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let createdAt = document.created_at {
                            Label(AppDateFormatter.dateTime(createdAt), systemImage: "calendar")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical)
                }

                Section("Содержимое") {
                    if let content = document.content, !content.isEmpty {
                        Text(content)
                            .textSelection(.enabled)
                    } else {
                        Text("Содержимое не указано")
                            .foregroundStyle(.secondary)
                    }
                }

                if let fileURL = document.file_url, !fileURL.isEmpty {
                    Section("Файл") {
                        LabeledContent("Ссылка", value: fileURL)
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

                Section("Система") {
                    LabeledContent("ID документа", value: "\(document.id)")
                    LabeledContent("Тип", value: document.document_type)
                    LabeledContent("Публичный", value: document.is_public ? "Да" : "Нет")
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
    let students: [DocumentStudentDTO]
    let documentTypes: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (DocumentGenerateFormData) -> Void

    @State private var profileID: Int
    @State private var documentType: String
    @State private var titlePrefix: String
    @State private var selectedStudentIDs: Set<Int> = []
    @State private var validationMessage: String?

    init(
        profiles: [DocumentProfileDTO],
        students: [DocumentStudentDTO],
        documentTypes: [(code: String, title: String)],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (DocumentGenerateFormData) -> Void
    ) {
        self.profiles = profiles
        self.students = students
        self.documentTypes = documentTypes
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _profileID = State(initialValue: profiles.first?.id ?? 0)
        _documentType = State(initialValue: documentTypes.first?.code ?? "statement")
        _titlePrefix = State(initialValue: "")
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
                                Text(profile.student_name ?? "Ученик \(profile.student_id)").tag(profile.id)
                            }
                        }
                    }
                }

                Section("Документ") {
                    Picker("Тип", selection: $documentType) {
                        ForEach(documentTypes, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }

                    TextField("Префикс названия", text: $titlePrefix)
                }

                Section {
                    if students.isEmpty {
                        Text("Список учеников не загружен.")
                            .foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("Ученики: \(selectedStudentIDs.count)") {
                            ForEach(students) { student in
                                Toggle(
                                    student.student_name,
                                    isOn: bindingForStudent(student.id)
                                )
                            }
                        }

                        Button {
                            selectedStudentIDs.removeAll()
                        } label: {
                            Label("Очистить выбор", systemImage: "xmark.circle")
                        }
                        .disabled(selectedStudentIDs.isEmpty)
                    }
                } header: {
                    Text("Дополнительные ученики")
                } footer: {
                    Text("Если никого не выбрать, документ будет создан только по выбранному профилю либо по логике сервера.")
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
                    .disabled(isSaving)
                }
            }
        }
    }

    private func bindingForStudent(_ id: Int) -> Binding<Bool> {
        Binding(
            get: {
                selectedStudentIDs.contains(id)
            },
            set: { isSelected in
                if isSelected {
                    selectedStudentIDs.insert(id)
                } else {
                    selectedStudentIDs.remove(id)
                }
            }
        )
    }

    private func save() {
        validationMessage = nil

        guard profileID != 0 else {
            validationMessage = "Выберите профиль"
            return
        }

        let formData = DocumentGenerateFormData(
            profileID: profileID,
            documentType: documentType,
            titlePrefix: titlePrefix,
            studentIDs: Array(selectedStudentIDs).sorted()
        )

        onSave(formData)
        dismiss()
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