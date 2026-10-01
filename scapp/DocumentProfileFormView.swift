import SwiftUI

/// Форма профиля документов (DocumentProfileSaveRequest): данные для договора и согласия.
struct DocumentProfileFormView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: DocumentProfileDTO?
    let students: [DocumentStudentDTO]
    /// Родители для выбора аккаунта (admin/manager). Пусто — выбор не показывается.
    let parents: [AdminParentDTO]
    /// admin/manager: без parent_user_id сервер записал бы родителем сохраняющего.
    let requiresParent: Bool
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (DocumentProfileFormData) async -> Bool

    @State private var form: DocumentProfileFormData
    @State private var validationMessage: String?

    init(
        profile: DocumentProfileDTO?,
        students: [DocumentStudentDTO],
        parents: [AdminParentDTO],
        requiresParent: Bool,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (DocumentProfileFormData) async -> Bool
    ) {
        self.profile = profile
        self.students = students
        self.parents = parents
        self.requiresParent = requiresParent
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        if let profile {
            _form = State(initialValue: DocumentProfileFormData(profile: profile))
        } else {
            var initial = DocumentProfileFormData(student: students.first)
            initial.applyParent(for: initial.studentID, parents: parents)
            _form = State(initialValue: initial)
        }
    }

    private var isEditing: Bool {
        profile != nil
    }

    /// Родители выбранного ученика; если связей нет — все родители.
    private var parentChoices: [AdminParentDTO] {
        let studentParents = parents.filter { parent in
            parent.students.contains { $0.id == form.studentID }
        }

        return studentParents.isEmpty ? parents : studentParents
    }

    private var studentSelection: Binding<Int> {
        Binding(
            get: { form.studentID },
            set: { studentID in
                let student = students.first { $0.id == studentID }
                let prefilled = DocumentProfileFormData(student: student)

                form.studentID = studentID
                form.studentFullName = prefilled.studentFullName
                form.studentBirthDate = prefilled.studentBirthDate
                form.studentGender = prefilled.studentGender
                form.applyParent(for: studentID, parents: parents)
                validationMessage = nil
            }
        )
    }

    private var parentSelection: Binding<Int> {
        Binding(
            get: { form.parentUserID ?? 0 },
            set: { parentUserID in
                form.parentUserID = parentUserID == 0 ? nil : parentUserID

                if let parent = parents.first(where: { $0.user_id == parentUserID }),
                   form.parentFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    form.parentFullName = parent.full_name
                }

                validationMessage = nil
            }
        )
    }

    private var selectedParentName: String {
        if let parent = parents.first(where: { $0.user_id == form.parentUserID }) {
            return parent.full_name
        }

        return profile?.db_parent_name ?? profile?.displayParentName ?? "Не выбран"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("ФИО ученика и родителя обязательны. Даты — в формате ДД.ММ.ГГГГ.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Ученик") {
                    if isEditing {
                        LabeledContent(
                            "Ученик",
                            value: students.first { $0.id == form.studentID }?.displayTitle
                                ?? profile?.displayStudentName
                                ?? "Ученик"
                        )
                    } else if students.isEmpty {
                        Text("Список учеников не загружен.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Ученик", selection: studentSelection) {
                            Text("Выберите ученика").tag(0)

                            ForEach(students) { student in
                                Text(student.displayTitle).tag(student.id)
                            }
                        }
                    }

                    TextField("ФИО ученика *", text: $form.studentFullName)
                    TextField("Дата рождения (ДД.ММ.ГГГГ)", text: $form.studentBirthDate)
                        .keyboardType(.numbersAndPunctuation)

                    Picker("Пол", selection: $form.studentGender) {
                        ForEach(DocumentGender.options, id: \.code) { option in
                            Text(option.title).tag(option.code)
                        }
                    }

                    TextField("Свидетельство о рождении", text: $form.studentBirthCertificate)
                    TextField("Адрес регистрации ученика", text: $form.studentRegistrationAddress, axis: .vertical)
                    TextField("Адрес проживания ученика", text: $form.studentLivingAddress, axis: .vertical)
                }

                Section {
                    // Профиль привязан к паре родитель–ученик, поэтому родителя
                    // выбираем только при создании.
                    if isEditing {
                        if !parents.isEmpty || profile?.db_parent_name != nil {
                            LabeledContent("Аккаунт родителя", value: selectedParentName)
                        }
                    } else if requiresParent && parents.isEmpty {
                        Text("Список родителей не загружен. Обновите экран документов.")
                            .foregroundStyle(.secondary)
                    } else if !parents.isEmpty {
                        Picker("Аккаунт родителя *", selection: parentSelection) {
                            Text("Выберите родителя").tag(0)

                            ForEach(parentChoices) { parent in
                                Text(parent.full_name).tag(parent.user_id)
                            }
                        }
                    }

                    TextField("ФИО родителя *", text: $form.parentFullName)
                    TextField("Дата рождения (ДД.ММ.ГГГГ)", text: $form.parentBirthDate)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Телефон", text: $form.parentPhone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $form.parentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Родитель / представитель")
                }

                Section("Паспорт родителя") {
                    TextField("Серия", text: $form.parentPassportSeries)
                    TextField("Номер", text: $form.parentPassportNumber)
                    TextField("Кем выдан", text: $form.parentPassportIssuedBy, axis: .vertical)
                    TextField("Дата выдачи (ДД.ММ.ГГГГ)", text: $form.parentPassportIssuedAt)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Код подразделения", text: $form.parentPassportDepartmentCode)
                    TextField("Адрес регистрации родителя", text: $form.parentRegistrationAddress, axis: .vertical)
                    TextField("Адрес проживания родителя", text: $form.parentLivingAddress, axis: .vertical)
                }

                Section {
                    TextField("Название организации", text: $form.organizationName, axis: .vertical)
                    TextField("Руководитель", text: $form.organizationDirector)
                    TextField("Адрес организации", text: $form.organizationAddress, axis: .vertical)
                    TextField("ИНН", text: $form.organizationInn)
                        .keyboardType(.numberPad)
                    TextField("ОГРН", text: $form.organizationOgrn)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Организация")
                } footer: {
                    Text("Если название организации не заполнено, сервер подставит его по умолчанию.")
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
            .navigationTitle(isEditing ? "Профиль документов" : "Новый профиль")
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

        if let error = form.validationError() {
            validationMessage = error
            return
        }

        // Без parent_user_id сервер записал бы родителем администратора.
        if !isEditing && (requiresParent || !parents.isEmpty) && form.parentUserID == nil {
            validationMessage = parents.isEmpty
                ? "Список родителей не загружен. Обновите экран и выберите родителя."
                : "Выберите родителя"
            return
        }

        let formData = form

        Task {
            if await onSave(formData) {
                dismiss()
            }
        }
    }
}
