import SwiftUI

struct AnnouncementFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let audiences: [(code: String, title: String)]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (AnnouncementFormData) -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var targetAudience: String = "all"
    @State private var isImportant = false
    @State private var validationMessage: String?
    @State private var divisionAudience = DivisionAudience()

    var body: some View {
        NavigationStack {
            Form {
                Section("Объявление") {
                    TextField("Заголовок", text: $title)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Текст")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $bodyText)
                            .frame(minHeight: 160)
                    }
                }

                Section("Аудитория") {
                    Picker("Кому", selection: $targetAudience) {
                        ForEach(audiences, id: \.code) { item in
                            Text(item.title).tag(item.code)
                        }
                    }

                    Toggle("Важное", isOn: $isImportant)
                }

                DivisionAudienceSection(audience: $divisionAudience)

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка создания", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .loadsDivisionAudience()
            .navigationTitle("Новое объявление")
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

    private func save() {
        validationMessage = nil

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            validationMessage = "Введите заголовок"
            return
        }

        guard !cleanBody.isEmpty else {
            validationMessage = "Введите текст объявления"
            return
        }

        let formData = AnnouncementFormData(
            title: cleanTitle,
            body: cleanBody,
            targetAudience: targetAudience,
            isImportant: isImportant,
            divisionIDs: divisionAudience.payload(appState: appState)
        )

        onSave(formData)
        dismiss()
    }
}