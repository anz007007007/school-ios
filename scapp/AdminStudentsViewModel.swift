import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AdminStudentsViewModel: ObservableObject {
    @Published var students: [AdminStudentDTO] = []
    @Published var classes: [AdminClassDTO] = []

    @Published var searchText = ""
    @Published var selectedStatus: StudentStatusFilter = .all
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum StudentStatusFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case active = "Активные"
        case inactive = "Неактивные"
        case graduated = "Выпускники"

        var id: String {
            rawValue
        }

        var apiValue: String? {
            switch self {
            case .all:
                return nil
            case .active:
                return "active"
            case .inactive:
                return "inactive"
            case .graduated:
                return "graduated"
            }
        }
    }

    var filteredStudents: [AdminStudentDTO] {
        var result = students

        if let apiValue = selectedStatus.apiValue {
            result = result.filter { $0.status == apiValue }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { student in
                student.first_name.localizedCaseInsensitiveContains(query)
                || student.last_name.localizedCaseInsensitiveContains(query)
                || student.fullName.localizedCaseInsensitiveContains(query)
                || student.gender.localizedCaseInsensitiveContains(query)
                || student.status.localizedCaseInsensitiveContains(query)
                || student.classTitle.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.classTitle == $1.classTitle {
                return $0.fullName < $1.fullName
            }

            return $0.classTitle < $1.classTitle
        }
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let classesTask: Void = loadClasses(api: api)
        async let studentsTask: Void = loadStudents(api: api, showLoading: false)

        _ = await (classesTask, studentsTask)

        isLoading = false
    }

    func loadStudents(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil
        successMessage = nil

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

        if showLoading {
            isLoading = false
        }
    }

    func loadClasses(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(AdminClassesResponseDTO.self, from: data)
            classes = decoded.items
        } catch {
            // Не блокируем список учеников, если классы не загрузились.
        }
    }

    func createStudent(
        api: SchoolAPI,
        firstName: String,
        lastName: String,
        gender: String,
        status: String,
        classID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "first_name": firstName,
                "last_name": lastName,
                "gender": gender,
                "status": status
            ]

            if classID != 0 {
                body["class_id"] = classID
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/students",
                method: "POST",
                body: body
            )

            successMessage = "Ученик создан"
            await loadStudents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать ученика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateStudent(
        api: SchoolAPI,
        studentID: Int,
        firstName: String,
        lastName: String,
        gender: String,
        status: String,
        classID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var body: [String: Any] = [
                "first_name": firstName,
                "last_name": lastName,
                "gender": gender,
                "status": status
            ]

            if classID != 0 {
                body["class_id"] = classID
            } else {
                body["class_id"] = NSNull()
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/students/\(studentID)",
                method: "PATCH",
                body: body
            )

            successMessage = "Ученик обновлён"
            await loadStudents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить ученика: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createStudentCredentials(
        api: SchoolAPI,
        studentID: Int,
        login: String,
        password: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard studentID != 0 else {
            errorMessage = "Не выбран ученик"
            isSaving = false
            return false
        }

        guard !cleanLogin.isEmpty else {
            errorMessage = "Введите логин ученика"
            isSaving = false
            return false
        }

        guard cleanPassword.count >= 6 else {
            errorMessage = "Пароль должен быть не короче 6 символов"
            isSaving = false
            return false
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/students/credentials",
                method: "POST",
                body: [
                    "student_id": studentID,
                    "login": cleanLogin,
                    "password": cleanPassword
                ]
            )

            successMessage = "Учётные данные ученика созданы"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать учётные данные: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteStudent(
        api: SchoolAPI,
        studentID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/admin/students/\(studentID)",
                method: "DELETE"
            )

            successMessage = "Ученик удалён"
            await loadStudents(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить ученика: \(error.localizedDescription)"
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
            throw AdminStudentsError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AdminStudentsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            #if DEBUG
            print("ADMIN STUDENTS REQUEST:", method, url.absoluteString)
            print("ADMIN STUDENTS BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("ADMIN STUDENTS REQUEST:", method, url.absoluteString)
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminStudentsError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("ADMIN STUDENTS RESPONSE STATUS:", httpResponse.statusCode)
        print("ADMIN STUDENTS RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw AdminStudentsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AdminStudentsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

enum AdminStudentsError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Выйдите и войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            return APIRequestError.readableServerError(statusCode: statusCode, text: text)
        }
    }
}