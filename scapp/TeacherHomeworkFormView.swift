import SwiftUI

struct TeacherHomeworkFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TeacherCabinetViewModel

    let template: TeacherHomeworkDTO?

    @State private var selectedClassID = 0
    @State private var selectedSubjectID = 0
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var validationMessage: String?

    init(
        viewModel: TeacherCabinetViewModel,
        template: TeacherHomeworkDTO? = nil
    ) {
        self.viewModel = viewModel
        self.template = template
    }

    private var availableSubjects: [TeacherSubjectDTO] {
        if !viewModel.homeworkSubjects.isEmpty {
            return viewModel.homeworkSubjects
        }

        return viewModel.subjects
    }

    var body: some View {
        Form {
            Section {
                Text(template == nil ? "Новое домашнее задание" : "Создать похожее задание")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Выберите класс и предмет, заполните заголовок и срок сдачи. Описание можно оставить пустым.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Section("Класс") {
                Picker("Класс", selection: $selectedClassID) {
                    Text("Выберите класс").tag(0)

                    ForEach(viewModel.classes) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedClassID) {
                    selectedSubjectID = 0

                    Task {
                        await viewModel.loadHomeworkSubjects(api: appState.api)

                        selectedSubjectID = availableSubjects.first?.id ?? 0
                    }
                }
            }

            Section("Предмет") {
                Picker("Предмет", selection: $selectedSubjectID) {
                    Text("Выберите предмет").tag(0)

                    ForEach(availableSubjects) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("Задание") {
                TextField("Краткое название", text: $title)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Описание задания")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                }

                DatePicker(
                    "Сдать до",
                    selection: $dueDate,
                    displayedComponents: .date
                )
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

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()

                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить задание")
                                .font(.headline)
                        }

                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .appThemedForm()
        .navigationTitle(template == nil ? "Новая домашка" : "Создать похожее")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupInitialState()
        }
    }

    private func setupInitialState() async {
        if let template {
            selectedClassID = template.class_id
            selectedSubjectID = template.subject_id
            title = template.title
            description = template.description
            dueDate = Self.dateFormatter.date(from: template.due_date)
                ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                ?? Date()

            await viewModel.loadHomeworkSubjects(api: appState.api)
            return
        }

        selectedClassID = viewModel.homeworkSelectedClassID != 0
            ? viewModel.homeworkSelectedClassID
            : (viewModel.selectedClassID != 0 ? viewModel.selectedClassID : (viewModel.classes.first?.id ?? 0))

        if selectedClassID != 0 {
            await viewModel.loadHomeworkSubjects(api: appState.api)
        }

        selectedSubjectID = viewModel.homeworkSelectedSubjectID != 0
            ? viewModel.homeworkSelectedSubjectID
            : (availableSubjects.first?.id ?? 0)
    }

    private func save() {
        validationMessage = nil

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard selectedClassID != 0 else {
            validationMessage = "Выберите класс"
            return
        }

        guard selectedSubjectID != 0 else {
            validationMessage = "Выберите предмет"
            return
        }

        guard cleanTitle.count >= 2 else {
            validationMessage = "Название должно быть не короче 2 символов"
            return
        }

        Task {
            await viewModel.createHomework(
                api: appState.api,
                classID: selectedClassID,
                subjectID: selectedSubjectID,
                title: cleanTitle,
                description: cleanDescription,
                dueDate: Self.dateFormatter.string(from: dueDate)
            )

            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}