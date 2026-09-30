import SwiftUI

struct AdminEditUserView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminUsersViewModel
    let user: AdminUserDTO

    @State private var formData: AdminUserFormData
    @State private var newPassword = ""
    @State private var showResetPasswordSheet = false
    @State private var showDeactivateAlert = false

    init(viewModel: AdminUsersViewModel, user: AdminUserDTO) {
        self.viewModel = viewModel
        self.user = user

        _formData = State(
            initialValue: AdminUserFormData(
                login: user.login,
                password: "",
                fullName: user.full_name,
                roleCode: user.role_code,
                isActive: user.is_active
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основные данные") {
                    LabeledContent("Логин", value: user.login)

                    TextField("ФИО", text: $formData.fullName)

                    if canEditRoleInUsersSection {
                        Picker("Роль", selection: $formData.roleCode) {
                            Text("Администратор").tag("admin")
                            Text("Повар").tag("cook")
                            Text("Менеджер").tag("manager")
                        }

                        Text("В общем разделе пользователей можно менять роли: администратор, повар и менеджер.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Роль", value: roleTitle(user.role_code))

                        Text("Роль учителя, ученика или родителя нельзя менять в общем списке пользователей. Используйте профильные разделы: «Учителя», «Ученики», «Родители». Здесь можно изменить ФИО, активность и пароль.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Активен", isOn: $formData.isActive)
                }

                Section("Безопасность") {
                    Button {
                        showResetPasswordSheet = true
                    } label: {
                        Label("Сменить пароль", systemImage: "key.fill")
                    }
                }

                Section("Опасная зона") {
                    Button(role: .destructive) {
                        showDeactivateAlert = true
                    } label: {
                        Label("Отключить пользователя", systemImage: "person.crop.circle.badge.xmark")
                    }
                    .disabled(!user.is_active)

                    Text("Отключение не удаляет пользователя физически, а делает его неактивным. Он не сможет войти в систему.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.updateUser(
                                api: appState.api,
                                userID: user.id,
                                fullName: formData.fullName,
                                originalRoleCode: user.role_code,
                                roleCode: formData.roleCode,
                                isActive: formData.isActive
                            )

                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(!isFormValid || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showResetPasswordSheet) {
                ResetPasswordSheet(
                    viewModel: viewModel,
                    user: user,
                    newPassword: $newPassword
                )
                .environmentObject(appState)
            }
            .alert("Отключить пользователя?", isPresented: $showDeactivateAlert) {
                Button("Отмена", role: .cancel) {}

                Button("Отключить", role: .destructive) {
                    Task {
                        let success = await viewModel.deactivateUser(
                            api: appState.api,
                            userID: user.id
                        )

                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Пользователь \(user.login) больше не сможет входить в систему.")
            }
        }
    }

    private var isFormValid: Bool {
        !formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canEditRoleInUsersSection: Bool {
        ["admin", "cook", "manager"].contains(user.role_code)
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

struct ResetPasswordSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminUsersViewModel
    let user: AdminUserDTO

    @Binding var newPassword: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Пользователь") {
                    LabeledContent("Логин", value: user.login)
                    LabeledContent("ФИО", value: user.full_name)
                }

                Section("Новый пароль") {
                    SecureField("Введите новый пароль", text: $newPassword)

                    Text("После смены пароля пользователь сможет войти только с новым паролем.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage = viewModel.successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .appThemedForm()
            .navigationTitle("Смена пароля")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newPassword = ""
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.resetPassword(
                                api: appState.api,
                                userID: user.id,
                                newPassword: newPassword
                            )

                            if success {
                                newPassword = ""
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Сменить")
                        }
                    }
                    .disabled(newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
                }
            }
        }
    }
}