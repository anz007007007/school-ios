import SwiftUI

struct AdminTeacherFormData {
    var login: String = ""
    var password: String = ""
    var fullName: String = ""
    var isActive: Bool = true
}

struct AdminTeacherFormView: View {
    let mode: AdminTeacherFormMode
    @Binding var formData: AdminTeacherFormData

    enum AdminTeacherFormMode {
        case create
        case edit
    }

    var body: some View {
        Form {
            Section("Данные учителя") {
                if mode == .create {
                    TextField("Логин", text: $formData.login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                TextField("ФИО", text: $formData.fullName)

                if mode == .edit {
                    Toggle("Активен", isOn: $formData.isActive)
                }
            }

            if mode == .create {
                Section("Пароль") {
                    SecureField("Пароль", text: $formData.password)

                    Text("Учитель сможет войти в приложение с этим логином и паролем.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
