import SwiftUI

struct TeacherFinalGradeFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TeacherCabinetViewModel
    let draft: TeacherFinalGradeDraft

    @State private var manualGrade: String
    @State private var useRecommended = false
    @State private var comment: String
    @State private var validationMessage: String?

    private let gradeValues = ["5", "4.5", "4", "3.5", "3", "2.5", "2", "1"]

    init(
        viewModel: TeacherCabinetViewModel,
        draft: TeacherFinalGradeDraft
    ) {
        self.viewModel = viewModel
        self.draft = draft

        let initialGrade = draft.currentManualGrade?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        _manualGrade = State(initialValue: initialGrade.isEmpty ? draft.recommendedGrade : initialGrade)
        _useRecommended = State(initialValue: initialGrade.isEmpty)
        _comment = State(initialValue: draft.currentComment ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(draft.gradeScope == .term ? "Итоговая за период" : "Годовая итоговая")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(draft.studentName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Text("\(draft.className) · \(draft.subjectName)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if draft.gradeScope == .term {
                        Text(draft.termName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.control)
                    }
                }

                Section("Расчёт") {
                    LabeledContent("Средний балл", value: draft.average)
                    LabeledContent("Рекомендованная", value: draft.recommendedGrade)

                    Toggle("Поставить рекомендованную автоматически", isOn: $useRecommended)

                    Text("Если включено, приложение отправит manual_grade = null, и сервер сам выставит рекомендованную итоговую.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !useRecommended {
                    Section("Ручная итоговая") {
                        Picker("Оценка", selection: $manualGrade) {
                            ForEach(gradeValues, id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Или введите оценку от 1 до 5", text: $manualGrade)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Комментарий") {
                    TextField("Комментарий", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
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
                                Text("Сохранить итоговую")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .appThemedForm()
            .navigationTitle("Итоговая")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard draft.classID != 0 else {
            validationMessage = "Не выбран класс"
            return
        }

        guard draft.subjectID != 0 else {
            validationMessage = "Не выбран предмет"
            return
        }

        if draft.gradeScope == .term && draft.termID == nil {
            validationMessage = "Для итоговой за период выберите период"
            return
        }

        let cleanManualGrade = manualGrade
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        if !useRecommended {
            guard let value = Double(cleanManualGrade), value >= 1, value <= 5 else {
                validationMessage = "Итоговая оценка должна быть числом от 1 до 5"
                return
            }
        }

        Task {
            let success = await viewModel.saveFinalGrade(
                api: appState.api,
                studentID: draft.studentID,
                classID: draft.classID,
                subjectID: draft.subjectID,
                termID: draft.termID,
                gradeScope: draft.gradeScope,
                manualGrade: useRecommended ? nil : cleanManualGrade,
                comment: comment
            )

            if success {
                dismiss()
            }
        }
    }
}