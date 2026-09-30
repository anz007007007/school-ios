import SwiftUI

struct PublicDocumentFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новый документ"
            case .edit:
                return "Редактирование"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let document: PublicDocumentDTO?
    let documentTypes: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (PublicDocumentFormData) -> Void

    @State private var title: String
    @State private var documentType: String
    @State private var isPublic: Bool
    @State private var content: String
    @State private var fileURL: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        document: PublicDocumentDTO?,
        documentTypes: [(code: String, title: String)],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (PublicDocumentFormData) -> Void
    ) {
        self.mode = mode
        self.document = document
        self.documentTypes = documentTypes
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _title = State(initialValue: document?.title ?? "")
        _documentType = State(initialValue: document?.document_type ?? documentTypes.first?.code ?? "statement")
        _isPublic = State(initialValue: document?.is_public ?? true)
        _content = State(initialValue: document?.content ?? "")
        _fileURL = State(initialValue: document?.file_url ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $title)

                    Picker("Тип", selection: $documentType) {
                        ForEach(documentTypes, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }

                    Toggle("Публичный документ", isOn: $isPublic)
                }

                Section("Содержимое") {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                }

                Section("Файл") {
                    TextField("Ссылка на файл", text: $fileURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка сохранения", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
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
                            Text("Сохранить")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            validationMessage = "Введите название документа"
            return
        }

        let formData = PublicDocumentFormData(
            title: cleanTitle,
            documentType: documentType,
            isPublic: isPublic,
            content: content,
            fileURL: fileURL
        )

        onSave(formData)
        dismiss()
    }
}