import SwiftUI

struct TeacherGradeFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TeacherCabinetViewModel
    let gradeToEdit: TeacherGradeDTO?

    @State private var selectedClassID = 0
    @State private var selectedStudentID = 0
    @State private var selectedSubjectID = 0
    @State private var gradeValue = "5"
    @State private var gradeType = TeacherGradeTypeDTO.fallback.code
    @State private var gradeDate = Date()
    @State private var validationMessage: String?
    @State private var isLoadingClassData = false

    private let gradeValues = ["5", "4", "3", "2", "1"]

    init(
        viewModel: TeacherCabinetViewModel,
        gradeToEdit: TeacherGradeDTO? = nil
    ) {
        self.viewModel = viewModel
        self.gradeToEdit = gradeToEdit
    }

    var body: some View {
        Form {
            Section {
                Text(gradeToEdit == nil ? "Поставить оценку" : "Редактировать оценку")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(gradeToEdit == nil ? "Выберите класс, ученика, предмет и оценку." : "Измените оценку, тип или дату. Технически приложение создаст новую оценку и удалит старую.")
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
                    Task {
                        await classChanged()
                    }
                }

                if isLoadingClassData {
                    ProgressView("Загружаем учеников...")
                }
            }

            Section("Ученик") {
                if availableStudents.isEmpty {
                    Text("Ученики для выбранного класса не найдены.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Ученик", selection: $selectedStudentID) {
                        Text("Выберите ученика").tag(0)

                        ForEach(availableStudents) { student in
                            Text(student.full_name).tag(student.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section("Предмет") {
                Picker("Предмет", selection: $selectedSubjectID) {
                    Text("Выберите предмет").tag(0)

                    ForEach(viewModel.subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("Оценка") {
                Picker("Оценка", selection: $gradeValue) {
                    ForEach(gradeValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Тип оценки", selection: $gradeType) {
                    ForEach(availableGradeTypes) { item in
                        Text(item.name).tag(item.code)
                    }
                }

                DatePicker(
                    "Дата",
                    selection: $gradeDate,
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
                            Text("Сохранить оценку")
                                .font(.headline)
                        }

                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving || isLoadingClassData)
            }
        }
        .navigationTitle(gradeToEdit == nil ? "Новая оценка" : "Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupInitialState()
        }
    }

    private var availableGradeTypes: [TeacherGradeTypeDTO] {
        viewModel.gradeTypes.isEmpty ? [TeacherGradeTypeDTO.fallback] : viewModel.gradeTypes
    }

    private var availableStudents: [TeacherStudentDTO] {
        if selectedClassID == 0 {
            return viewModel.students.sorted { $0.full_name < $1.full_name }
        }

        return viewModel.students
            .filter { student in
                guard let classID = student.class_id else {
                    return true
                }

                return classID == selectedClassID
            }
            .sorted { $0.full_name < $1.full_name }
    }

    private func setupInitialState() async {
        validationMessage = nil

        if let gradeToEdit {
            selectedClassID = gradeToEdit.class_id
            selectedStudentID = gradeToEdit.student_id
            selectedSubjectID = gradeToEdit.subject_id
            gradeValue = gradeToEdit.grade_value
            gradeType = gradeToEdit.grade_type ?? TeacherGradeTypeDTO.fallback.code
            gradeDate = Self.dateFormatter.date(from: gradeToEdit.grade_date) ?? Date()

            if viewModel.classes.isEmpty {
                await viewModel.loadClasses(api: appState.api)
            }

            await viewModel.ensureJournalSubjects(api: appState.api)

            if viewModel.gradeTypes.isEmpty {
                await viewModel.loadGradeTypes(api: appState.api)
            }

            await reloadStudentsForSelectedClass()

            if !availableGradeTypes.contains(where: { $0.code == gradeType }) {
                gradeType = availableGradeTypes.first?.code ?? TeacherGradeTypeDTO.fallback.code
            }

            return
        }

        if viewModel.classes.isEmpty {
            await viewModel.loadClasses(api: appState.api)
        }

        await viewModel.ensureJournalSubjects(api: appState.api)

        if viewModel.gradeTypes.isEmpty {
            await viewModel.loadGradeTypes(api: appState.api)
        }

        selectedClassID = viewModel.selectedClassID != 0
            ? viewModel.selectedClassID
            : (viewModel.classes.first?.id ?? 0)

        selectedSubjectID = viewModel.selectedSubjectID != 0
            ? viewModel.selectedSubjectID
            : (viewModel.subjects.first?.id ?? 0)

        if selectedClassID != 0 {
            await reloadStudentsForSelectedClass()
        }

        selectedStudentID = availableStudents.first?.id ?? 0

        if !availableGradeTypes.contains(where: { $0.code == gradeType }) {
            gradeType = availableGradeTypes.first?.code ?? TeacherGradeTypeDTO.fallback.code
        }
    }

    private func classChanged() async {
        validationMessage = nil
        selectedStudentID = 0

        guard selectedClassID != 0 else {
            return
        }

        await reloadStudentsForSelectedClass()
        selectedStudentID = availableStudents.first?.id ?? 0
    }

    private func reloadStudentsForSelectedClass() async {
        isLoadingClassData = true

        let previousSelectedClassID = viewModel.selectedClassID
        viewModel.selectedClassID = selectedClassID

        await viewModel.loadAccess(api: appState.api)
        await viewModel.loadStudents(api: appState.api)

        viewModel.selectedClassID = selectedClassID != 0 ? selectedClassID : previousSelectedClassID

        isLoadingClassData = false
    }

    private func save() {
        validationMessage = nil

        guard selectedClassID != 0 else {
            validationMessage = "Выберите класс"
            return
        }

        guard selectedStudentID != 0 else {
            validationMessage = "Выберите ученика"
            return
        }

        guard selectedSubjectID != 0 else {
            validationMessage = "Выберите предмет"
            return
        }

        let resolvedGradeType = gradeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? TeacherGradeTypeDTO.fallback.code
            : gradeType.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let success: Bool

            if let gradeToEdit {
                success = await viewModel.replaceGrade(
                    api: appState.api,
                    originalGradeID: gradeToEdit.id,
                    studentID: selectedStudentID,
                    classID: selectedClassID,
                    subjectID: selectedSubjectID,
                    gradeValue: gradeValue,
                    gradeType: resolvedGradeType,
                    gradeDate: Self.dateFormatter.string(from: gradeDate)
                )
            } else {
                await viewModel.createGrade(
                    api: appState.api,
                    studentID: selectedStudentID,
                    classID: selectedClassID,
                    subjectID: selectedSubjectID,
                    gradeValue: gradeValue,
                    gradeType: resolvedGradeType,
                    gradeDate: Self.dateFormatter.string(from: gradeDate)
                )

                success = viewModel.errorMessage == nil
            }

            if success {
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