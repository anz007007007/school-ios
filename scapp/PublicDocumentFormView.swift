import SwiftUI

/// Форма публичного документа (PublicDocumentCreateRequest / PublicDocumentUpdateRequest).
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
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (PublicDocumentFormData) async -> Bool

    @State private var title: String
    @State private var isPublic: Bool
    @State private var descriptionText: String
    @State private var fileURL: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        document: PublicDocumentDTO?,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (PublicDocumentFormData) async -> Bool
    ) {
        self.mode = mode
        self.document = document
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _title = State(initialValue: document?.title ?? "")
        _isPublic = State(initialValue: document?.is_public ?? true)
        _descriptionText = State(initialValue: document?.description ?? "")
        _fileURL = State(initialValue: document?.file_url ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $title)

                    Toggle("Опубликован", isOn: $isPublic)
                }

                Section("Описание") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 160)
                }

                Section("Файл") {
                    TextField("Ссылка на файл", text: $fileURL)
                        .keyboardType(.URL)
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
            .appThemedForm()
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

        guard cleanTitle.count >= 2 else {
            validationMessage = "Введите название документа (не короче 2 символов)"
            return
        }

        let formData = PublicDocumentFormData(
            title: cleanTitle,
            description: descriptionText,
            fileURL: fileURL,
            isPublic: isPublic
        )

        Task {
            if await onSave(formData) {
                dismiss()
            }
        }
    }
}
