import Combine
import SchoolAPIClient
import SwiftUI

struct GateCodeDTO: Codable {
    let gate_code: String?
}

@MainActor
final class AdminSettingsViewModel: ObservableObject {
    @Published var gateCode = ""
    @Published private(set) var savedGateCode = ""
    @Published private(set) var isLoaded = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load(api: SchoolAPI) async {
        errorMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                GateCodeDTO.self,
                api: api,
                path: "/api/v1/school-info/gate-code",
                logPrefix: "ADMIN GATE CODE"
            )

            savedGateCode = response.gate_code ?? ""
            gateCode = savedGateCode
            isLoaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить код калитки"
        }
    }

    func save(api: SchoolAPI) async {
        let value = gateCode.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                GateCodeDTO.self,
                api: api,
                path: "/api/v1/school-info/gate-code",
                method: "PUT",
                body: ["gate_code": value.isEmpty ? NSNull() : value],
                logPrefix: "ADMIN GATE CODE"
            )

            savedGateCode = response.gate_code ?? ""
            gateCode = savedGateCode
            successMessage = savedGateCode.isEmpty ? "Код калитки скрыт" : "Код калитки сохранён"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось сохранить код калитки"
        }

        isSaving = false
    }
}

/// Настройки администрирования: код калитки (виден всем вошедшим в шапке главной).
struct AdminSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AdminSettingsViewModel()

    private var canSave: Bool {
        viewModel.isLoaded
            && !viewModel.isSaving
            && viewModel.gateCode.trimmingCharacters(in: .whitespacesAndNewlines) != viewModel.savedGateCode
    }

    var body: some View {
        Form {
            Section {
                TextField("Например: 2735#", text: $viewModel.gateCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!viewModel.isLoaded || viewModel.isSaving)
                    .onChange(of: viewModel.gateCode) { _, newValue in
                        if newValue.count > 32 {
                            viewModel.gateCode = String(newValue.prefix(32))
                        }
                    }

                Button {
                    Task {
                        await viewModel.save(api: appState.api)
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Сохранить")
                    }
                }
                .disabled(!canSave)
            } header: {
                Text("Код калитки")
            } footer: {
                Text("Виден всем, кто вошёл в приложение, — в шапке главной. Пустое поле скрывает код.")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.danger)
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
        .appThemedList()
        .navigationTitle("Настройки")
        .task {
            if !viewModel.isLoaded {
                await viewModel.load(api: appState.api)
            }
        }
    }
}
