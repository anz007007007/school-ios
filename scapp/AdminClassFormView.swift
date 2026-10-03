import SwiftUI

struct AdminClassFormData {
    var name: String = ""
    var educationLevel: String = "school"
    var academicYear: String = AdminDateInput.currentAcademicYear
    var curatorTeacherID: Int = 0
    /// 0 — подразделение не выбрано.
    var divisionID: Int = 0
}

struct AdminClassFormView: View {
    @Binding var formData: AdminClassFormData
    let teachers: [AdminTeacherDTO]
    /// Подразделение, которое было у класса при открытии (nil — не было или новый класс).
    var originalDivisionID: Int? = nil

    @ObservedObject var divisionsStore = DivisionsStore.shared

    var body: some View {
        Form {
            Section("Данные класса") {
                TextField("Название класса", text: $formData.name)

                Picker("Уровень образования", selection: $formData.educationLevel) {
                    Text("Школа").tag("school")
                    Text("Детский сад").tag("kindergarten")
                }

                TextField("Учебный год", text: $formData.academicYear)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if divisionsStore.isUsable {
                Section("Подразделение") {
                    Picker("Подразделение", selection: $formData.divisionID) {
                        if originalDivisionID == nil {
                            Text("Не выбрано").tag(0)
                        }

                        ForEach(divisionOptions) { division in
                            Text(division.name).tag(division.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
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

    /// Активные подразделения; текущее неактивное тоже показываем, чтобы не потерять выбор.
    private var divisionOptions: [DivisionDTO] {
        var result = divisionsStore.activeDivisions

        if formData.divisionID != 0,
           !result.contains(where: { $0.id == formData.divisionID }),
           let current = divisionsStore.division(id: formData.divisionID) {
            result.append(current)
        }

        return result
    }
}
