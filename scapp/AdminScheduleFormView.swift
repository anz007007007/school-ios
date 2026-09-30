import SwiftUI

struct AdminScheduleFormData {
    var classID: Int = 0
    var subjectID: Int = 0
    var teacherID: Int = 0
    var weekday: Int = 1
    var lessonNumber: Int = 1
    var startsAt: String = "09:00"
    var endsAt: String = "09:45"
}

struct AdminScheduleFormView: View {
    @Binding var formData: AdminScheduleFormData
    let classes: [AdminClassDTO]
    let subjects: [AdminSubjectDTO]
    let teachers: [AdminTeacherDTO]

    var body: some View {
        Section("Класс, предмет и учитель") {
            Picker("Класс", selection: $formData.classID) {
                Text("Выберите класс").tag(0)

                ForEach(classes) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Предмет", selection: $formData.subjectID) {
                Text("Выберите предмет").tag(0)

                ForEach(subjects) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Учитель", selection: $formData.teacherID) {
                Text("Не указан").tag(0)

                ForEach(teachers) { teacher in
                    Text(teacher.full_name).tag(teacher.id)
                }
            }
            .pickerStyle(.navigationLink)
        }

        Section("День и номер урока") {
            Picker("День недели", selection: $formData.weekday) {
                Text("Понедельник").tag(1)
                Text("Вторник").tag(2)
                Text("Среда").tag(3)
                Text("Четверг").tag(4)
                Text("Пятница").tag(5)
                Text("Суббота").tag(6)
                Text("Воскресенье").tag(7)
            }
            .pickerStyle(.navigationLink)

            Stepper(
                "Номер урока: \(formData.lessonNumber)",
                value: $formData.lessonNumber,
                in: 1...12
            )
        }

        Section("Время") {
            TextField("Начало, например 09:00", text: $formData.startsAt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Конец, например 09:45", text: $formData.endsAt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        Section {
            Text("Формат времени должен быть HH:mm, например 08:30 или 14:15.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}