import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminParentsViewModel: ObservableObject {
    @Published var parents: [AdminParentDTO] = []
    @Published var students: [AdminStudentDTO] = []
    @Published var messageTeachers: [AdminParentMessageTeacherDTO] = []
    @Published var searchText = ""
    @Published var selectedFilter: ParentFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isLoadingMessageTeachers = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum ParentFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"

        var id: String {
            rawValue
        }
    }

    var filteredParents: [AdminParentDTO] {
        var result = parents

        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.is_active }
        case .inactive:
            result = result.filter { !$0.is_active }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { parent in
                parent.login.localizedCaseInsensitiveContains(query)
                || parent.full_name.localizedCaseInsensitiveContains(query)
                || parent.relation_type.localizedCaseInsensitiveContains(query)
                || parent.studentsText.localizedCaseInsensitiveContains(query)
            }
        }

        return result
    }

    func loadParents(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parents",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminParentsResponseDTO.self, from: data)
            parents = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить родителей: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadStudents(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminStudentsResponseDTO.self, from: data)
            students = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить учеников: \(error.localizedDescription)"
        }
    }

    func createParent(
        api: SchoolAPI,
        login: String,
        password: String,
        fullName: String,
        relationType: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "login": login,
                "password": password,
                "full_name": fullName,
                "relation_type": relationType
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parents",
                method: "POST",
                body: body
            )

            successMessage = "Родитель создан"
            await loadParents(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать родителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateParent(
        api: SchoolAPI,
        parentID: Int,
        fullName: String,
        relationType: String,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "full_name": fullName,
                "relation_type": relationType,
                "is_active": isActive
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parents/\(parentID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Родитель обновлён"
            await loadParents(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить родителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func resetPassword(
        api: SchoolAPI,
        userID: Int,
        newPassword: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "password": newPassword
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/users/\(userID)/reset-password",
                method: "POST",
                body: body
            )

            successMessage = "Пароль родителя сброшен"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сбросить пароль родителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func attachStudent(
        api: SchoolAPI,
        parentID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "parent_id": parentID,
                "student_id": studentID
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parent-students",
                method: "POST",
                body: body
            )

            successMessage = "Ученик привязан к родителю"
            await loadParents(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось привязать ученика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func detachStudent(
        api: SchoolAPI,
        parentID: Int,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let path = "/api/v1/admin/parent-students?parent_id=\(parentID)&student_id=\(studentID)"

            _ = try await sendRequest(
                api: api,
                path: path,
                method: "DELETE"
            )

            successMessage = "Ученик отвязан от родителя"
            await loadParents(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось отвязать ученика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func loadMessageTeachers(
        api: SchoolAPI,
        parentID: Int
    ) async {
        isLoadingMessageTeachers = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parents/\(parentID)/message-teachers",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminParentMessageTeachersResponseDTO.self, from: data)
            messageTeachers = decoded.items.sorted {
                $0.full_name.localizedCaseInsensitiveCompare($1.full_name) == .orderedAscending
            }
        } catch {
            errorMessage = "Не удалось загрузить настройки сообщений родителя: \(error.localizedDescription)"
        }

        isLoadingMessageTeachers = false
    }

    func saveMessageTeachers(
        api: SchoolAPI,
        parentID: Int,
        allowedTeacherIDs: Set<Int>
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let body: [String: Any] = [
                "teacher_ids": Array(allowedTeacherIDs).sorted()
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/parents/\(parentID)/message-teachers",
                method: "PUT",
                body: body
            )

            successMessage = "Настройки сообщений родителя сохранены"
            await loadMessageTeachers(api: api, parentID: parentID)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить настройки сообщений родителя: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw AdminParentsError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminParentsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminParentsError.badResponse
        }

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminParentsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AdminParentsError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }
}

enum AdminParentsError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Сессия истекла. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            return APIRequestError.readableServerError(statusCode: statusCode, text: text)
        }
    }
}