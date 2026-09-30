import SwiftUI

struct AdminParentFormData {
    var login: String = ""
    var password: String = ""
    var fullName: String = ""
    var relationType: String = "parent"
    var isActive: Bool = true
}

struct AdminParentRelationOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String {
        code
    }

    static let all: [AdminParentRelationOption] = [
        AdminParentRelationOption(code: "mother", name: "Мать"),
        AdminParentRelationOption(code: "father", name: "Отец"),
        AdminParentRelationOption(code: "parent", name: "Родитель"),
        AdminParentRelationOption(code: "guardian", name: "Опекун"),
        AdminParentRelationOption(code: "grandmother", name: "Бабушка"),
        AdminParentRelationOption(code: "grandfather", name: "Дедушка"),
        AdminParentRelationOption(code: "aunt", name: "Тётя"),
        AdminParentRelationOption(code: "uncle", name: "Дядя"),
        AdminParentRelationOption(code: "sister", name: "Сестра"),
        AdminParentRelationOption(code: "brother", name: "Брат"),
        AdminParentRelationOption(code: "stepmother", name: "Мачеха"),
        AdminParentRelationOption(code: "stepfather", name: "Отчим"),
        AdminParentRelationOption(code: "relative", name: "Родственник"),
        AdminParentRelationOption(code: "representative", name: "Представитель"),
        AdminParentRelationOption(code: "other", name: "Другое")
    ]

    static func title(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }
}

struct AdminParentFormView: View {
    let mode: AdminParentFormMode
    @Binding var formData: AdminParentFormData

    enum AdminParentFormMode {
        case create
        case edit
    }

    var body: some View {
        Form {
            Section("Данные родителя") {
                if mode == .create {
                    TextField("Логин", text: $formData.login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                TextField("ФИО", text: $formData.fullName)

                Picker("Тип родства", selection: $formData.relationType) {
                    ForEach(AdminParentRelationOption.all) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .pickerStyle(.navigationLink)

                if mode == .edit {
                    Toggle("Активен", isOn: $formData.isActive)
                }
            }

            if mode == .create {
                Section("Пароль") {
                    SecureField("Пароль", text: $formData.password)

                    if !formData.password.isEmpty && formData.password.count < 6 {
                        Label("Пароль должен быть не короче 6 символов", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Text("Родитель сможет войти в приложение с этим логином и паролем.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}