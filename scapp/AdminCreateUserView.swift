import SwiftUI

struct AdminCreateUserView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AdminUsersViewModel
    @State private var formData = AdminUserFormData(roleCode: "admin")

    var body: some View {
        NavigationStack {
            AdminUserFormView(
                mode: .create,
                formData: $formData
            )
            .appThemedForm()
            .navigationTitle("Новый пользователь")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createUser(
                                api: appState.api,
                                login: formData.login,
                                password: formData.password,
                                fullName: formData.fullName,
                                roleCode: formData.roleCode
                            )

                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Создать")
                        }
                    }
                    .disabled(!isFormValid || viewModel.isSaving)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !formData.login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}