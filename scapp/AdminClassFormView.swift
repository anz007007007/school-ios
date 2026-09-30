import SwiftUI

struct AdminClassFormData {
    var name: String = ""
    var educationLevel: String = "school"
    var academicYear: String = "2025-2026"
    var curatorTeacherID: Int = 0
}

struct AdminClassFormView: View {
    @Binding var formData: AdminClassFormData
    let teachers: [AdminTeacherDTO]

    var body: some View {
        Form {
            Section("Данные класса") {
                TextField("Название класса", text: $formData.name)

                Picker("Уровень образования", selection: $formData.educationLevel) {
                    Text("Школа").tag("school")
                    Text("Детский сад").tag("kindergarten")
                    Text("Дополнительное").tag("additional")
                }

                TextField("Учебный год", text: $formData.academicYear)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Куратор") {
                Picker("Куратор класса", selection: $formData.curatorTeacherID) {
                    Text("Не назначен").tag(0)

                    ForEach(teachers.filter { $0.is_active }) { teacher in
                        Text(teacher.full_name).tag(teacher.id)
                    }
                }
                .pickerStyle(.navigationLink)

                Text("Куратор должен появляться у родителей и учеников в списке получателей сообщений. Если после назначения он не появляется — нужно добавить куратора в ответ API `/api/v1/messages/contacts`.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Пример названия: 1А, 2Б, 10А, Подготовительная группа.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}