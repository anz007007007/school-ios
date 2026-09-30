import SwiftUI

struct AdminUserFormData {
    var login: String = ""
    var password: String = ""
    var fullName: String = ""
    var roleCode: String = "admin"
    var isActive: Bool = true
}

struct AdminUserFormView: View {
    let mode: AdminUserFormMode
    @Binding var formData: AdminUserFormData

    enum AdminUserFormMode {
        case create
        case edit
    }

    var body: some View {
        Form {
            Section("Основные данные") {
                if mode == .create {
                    TextField("Логин", text: $formData.login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                TextField("ФИО", text: $formData.fullName)

                if mode == .create {
                    Picker("Роль", selection: $formData.roleCode) {
                        Text("Администратор").tag("admin")
                        Text("Повар").tag("cook")
                        Text("Менеджер").tag("manager")
                    }

                    Text("Учителей, учеников и родителей создавайте в отдельных разделах админки: «Учителя», «Ученики», «Родители». Общий раздел пользователей используется для администраторов, поваров и менеджеров.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Роль", value: roleTitle(formData.roleCode))

                    Text("Роль учителя, ученика или родителя нельзя менять в общем разделе пользователей. Для них используйте профильные разделы админки.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if mode == .create {
                Section("Пароль") {
                    SecureField("Пароль", text: $formData.password)

                    Text("Пароль можно будет сбросить позже из карточки пользователя.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if mode == .edit {
                Section("Статус") {
                    Toggle("Активен", isOn: $formData.isActive)
                }
            }
        }
        .appThemedForm()
    }

    private func roleTitle(_ roleCode: String) -> String {
        switch roleCode {
        case "admin":
            return "Администратор"
        case "teacher":
            return "Учитель"
        case "student":
            return "Ученик"
        case "parent":
            return "Родитель"
        case "cook":
            return "Повар"
        case "manager":
            return "Менеджер"
        default:
            return roleCode
        }
    }
}