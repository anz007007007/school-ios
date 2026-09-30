import SwiftUI

struct AdminStudentFormData {
    var firstName: String = ""
    var lastName: String = ""
    var gender: String = "male"
    var status: String = "active"
    var classID: Int = 0
}

struct AdminStudentFormView: View {
    @Binding var formData: AdminStudentFormData

    let classes: [AdminClassDTO]

    var body: some View {
        Group {
            Section("Данные ученика") {
                TextField("Имя", text: $formData.firstName)
                TextField("Фамилия", text: $formData.lastName)

                Picker("Пол", selection: $formData.gender) {
                    Text("Мальчик").tag("male")
                    Text("Девочка").tag("female")
                    Text("Не указан").tag("unknown")
                }
                .pickerStyle(.navigationLink)

                Picker("Статус", selection: $formData.status) {
                    Text("Активен").tag("active")
                    Text("Неактивен").tag("inactive")
                    Text("Выпускник").tag("graduated")
                }
                .pickerStyle(.navigationLink)
            }

            Section("Класс") {
                if classes.isEmpty {
                    Text("Классы не загружены.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Класс", selection: $formData.classID) {
                        Text("Без класса").tag(0)

                        ForEach(classes) { schoolClass in
                            Text(schoolClass.name).tag(schoolClass.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section {
                Text("Класс можно изменить позже в карточке ученика.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}