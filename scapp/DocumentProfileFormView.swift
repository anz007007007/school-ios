import SwiftUI

struct DocumentProfileFormView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: DocumentProfileDTO?
    let students: [DocumentStudentDTO]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (DocumentProfileFormData) -> Void

    @State private var studentID: Int
    @State private var passportSeries: String
    @State private var passportNumber: String
    @State private var birthCertificate: String
    @State private var registrationAddress: String
    @State private var residentialAddress: String
    @State private var snils: String
    @State private var medicalPolicy: String
    @State private var parentFullName: String
    @State private var parentPhone: String
    @State private var notes: String
    @State private var validationMessage: String?

    init(
        profile: DocumentProfileDTO?,
        students: [DocumentStudentDTO],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (DocumentProfileFormData) -> Void
    ) {
        self.profile = profile
        self.students = students
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _studentID = State(initialValue: profile?.student_id ?? students.first?.id ?? 0)
        _passportSeries = State(initialValue: profile?.passport_series ?? "")
        _passportNumber = State(initialValue: profile?.passport_number ?? "")
        _birthCertificate = State(initialValue: profile?.birth_certificate ?? "")
        _registrationAddress = State(initialValue: profile?.registration_address ?? "")
        _residentialAddress = State(initialValue: profile?.residential_address ?? "")
        _snils = State(initialValue: profile?.snils ?? "")
        _medicalPolicy = State(initialValue: profile?.medical_policy ?? "")
        _parentFullName = State(initialValue: profile?.parent_full_name ?? "")
        _parentPhone = State(initialValue: profile?.parent_phone ?? "")
        _notes = State(initialValue: profile?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ученик") {
                    if students.isEmpty {
                        Text("Список учеников не загружен.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Ученик", selection: $studentID) {
                            Text("Выберите ученика").tag(0)

                            ForEach(students) { student in
                                Text(student.student_name).tag(student.id)
                            }
                        }
                    }
                }

                Section("Паспорт / свидетельство") {
                    TextField("Серия паспорта", text: $passportSeries)
                    TextField("Номер паспорта", text: $passportNumber)
                    TextField("Свидетельство о рождении", text: $birthCertificate)
                }

                Section("Адреса") {
                    TextField("Адрес регистрации", text: $registrationAddress)
                    TextField("Адрес проживания", text: $residentialAddress)
                }

                Section("Документы") {
                    TextField("СНИЛС", text: $snils)
                    TextField("Медицинский полис", text: $medicalPolicy)
                }

                Section("Родитель / представитель") {
                    TextField("ФИО", text: $parentFullName)
                    TextField("Телефон", text: $parentPhone)
                        .keyboardType(.phonePad)
                }

                Section("Заметки") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
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
            .navigationTitle(profile == nil ? "Новый профиль" : "Профиль документов")
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

        guard studentID != 0 else {
            validationMessage = "Выберите ученика"
            return
        }

        let formData = DocumentProfileFormData(
            profileID: profile?.id,
            studentID: studentID,
            passportSeries: passportSeries,
            passportNumber: passportNumber,
            birthCertificate: birthCertificate,
            registrationAddress: registrationAddress,
            residentialAddress: residentialAddress,
            snils: snils,
            medicalPolicy: medicalPolicy,
            parentFullName: parentFullName,
            parentPhone: parentPhone,
            notes: notes
        )

        onSave(formData)
        dismiss()
    }
}