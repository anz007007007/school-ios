import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published var students: [DocumentStudentDTO] = []
    @Published var profiles: [DocumentProfileDTO] = []
    @Published var generatedDocuments: [GeneratedDocumentDTO] = []
    @Published var publicDocuments: [PublicDocumentDTO] = []

    @Published var selectedStudentID: Int = 0
    @Published var selectedDocumentType: String = "all"
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isLoadingStudents = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let documentTypes: [(code: String, title: String)] = [
        ("statement", "Заявление"),
        ("certificate", "Справка"),
        ("contract", "Договор"),
        ("consent", "Согласие"),
        ("order", "Приказ"),
        ("other", "Другое")
    ]

    var filteredProfiles: [DocumentProfileDTO] {
        var result = profiles

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { profile in
                (profile.student_name ?? "").localizedCaseInsensitiveContains(query)
                || (profile.class_name ?? "").localizedCaseInsensitiveContains(query)
                || (profile.passport_series ?? "").localizedCaseInsensitiveContains(query)
                || (profile.passport_number ?? "").localizedCaseInsensitiveContains(query)
                || (profile.birth_certificate ?? "").localizedCaseInsensitiveContains(query)
                || (profile.registration_address ?? "").localizedCaseInsensitiveContains(query)
                || (profile.residential_address ?? "").localizedCaseInsensitiveContains(query)
                || (profile.snils ?? "").localizedCaseInsensitiveContains(query)
                || (profile.medical_policy ?? "").localizedCaseInsensitiveContains(query)
                || (profile.parent_full_name ?? "").localizedCaseInsensitiveContains(query)
                || (profile.parent_phone ?? "").localizedCaseInsensitiveContains(query)
                || (profile.notes ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.student_name ?? "") < ($1.student_name ?? "")
        }
    }

    var filteredGeneratedDocuments: [GeneratedDocumentDTO] {
        var result = generatedDocuments

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        if selectedDocumentType != "all" {
            result = result.filter { $0.document_type == selectedDocumentType }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || item.document_type.localizedCaseInsensitiveContains(query)
                || (item.student_name ?? "").localizedCaseInsensitiveContains(query)
                || (item.content ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.generated_at ?? "") > ($1.generated_at ?? "")
        }
    }

    var filteredPublicDocuments: [PublicDocumentDTO] {
        var result = publicDocuments

        if selectedDocumentType != "all" {
            result = result.filter { $0.document_type == selectedDocumentType }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || item.document_type.localizedCaseInsensitiveContains(query)
                || (item.content ?? "").localizedCaseInsensitiveContains(query)
                || (item.file_url ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.created_at ?? "") > ($1.created_at ?? "")
        }
    }

    var completedProfilesCount: Int {
        profiles.filter { profile in
            !(profile.passport_number ?? "").isEmpty
            || !(profile.birth_certificate ?? "").isEmpty
            || !(profile.snils ?? "").isEmpty
            || !(profile.medical_policy ?? "").isEmpty
        }.count
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let studentsTask: Void = loadStudents(api: api)
        async let profilesTask: Void = loadProfiles(api: api, showLoading: false)
        async let generatedTask: Void = loadGeneratedDocuments(api: api, showLoading: false)
        async let publicTask: Void = loadPublicDocuments(api: api, showLoading: false)

        _ = await (studentsTask, profilesTask, generatedTask, publicTask)

        isLoading = false
    }

    func loadStudents(api: SchoolAPI) async {
        isLoadingStudents = true

        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/documents/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(DocumentStudentsListResponseDTO.self, from: data)
            students = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить учеников: \(error.localizedDescription)"
        }

        isLoadingStudents = false
    }

    func loadProfiles(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        do {
            var queryItems: [URLQueryItem] = []

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/documents/profiles",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(DocumentProfilesListResponseDTO.self, from: data)
            profiles = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить профили документов: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadGeneratedDocuments(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        do {
            var queryItems: [URLQueryItem] = []

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if selectedDocumentType != "all" {
                queryItems.append(URLQueryItem(name: "document_type", value: selectedDocumentType))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/documents/generated",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(GeneratedDocumentsListResponseDTO.self, from: data)
            generatedDocuments = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить сгенерированные документы: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadPublicDocuments(
        api: SchoolAPI,
        showLoading: Bool = true
    ) async {
        if showLoading {
            isLoading = true
        }

        do {
            var queryItems: [URLQueryItem] = []

            if selectedDocumentType != "all" {
                queryItems.append(URLQueryItem(name: "document_type", value: selectedDocumentType))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/documents/public",
                method: "GET",
                queryItems: queryItems
            )

            let decoded = try JSONDecoder().decode(PublicDocumentsListResponseDTO.self, from: data)
            publicDocuments = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить публичные документы: \(error.localizedDescription)"
        }

        if showLoading {
            isLoading = false
        }
    }

    func reloadForFilters(api: SchoolAPI) async {
        await loadProfiles(api: api, showLoading: false)
        await loadGeneratedDocuments(api: api, showLoading: false)
        await loadPublicDocuments(api: api, showLoading: false)
    }

    func saveProfile(
        api: SchoolAPI,
        formData: DocumentProfileFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.studentID != 0 else {
            errorMessage = "Выберите ученика"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "student_id": formData.studentID,
                "passport_series": cleanOptional(formData.passportSeries) as Any,
                "passport_number": cleanOptional(formData.passportNumber) as Any,
                "birth_certificate": cleanOptional(formData.birthCertificate) as Any,
                "registration_address": cleanOptional(formData.registrationAddress) as Any,
                "residential_address": cleanOptional(formData.residentialAddress) as Any,
                "snils": cleanOptional(formData.snils) as Any,
                "medical_policy": cleanOptional(formData.medicalPolicy) as Any,
                "parent_full_name": cleanOptional(formData.parentFullName) as Any,
                "parent_phone": cleanOptional(formData.parentPhone) as Any,
                "notes": cleanOptional(formData.notes) as Any
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/documents/profiles",
                method: "PUT",
                body: body
            )

            successMessage = "Профиль документов сохранён"
            await loadProfiles(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить профиль: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func generateDocument(
        api: SchoolAPI,
        formData: DocumentGenerateFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        guard formData.profileID != 0 else {
            errorMessage = "Выберите профиль"
            isSaving = false
            return false
        }

        do {
            var body: [String: Any] = [
                "profile_id": formData.profileID,
                "document_type": formData.documentType
            ]

            if let titlePrefix = cleanOptional(formData.titlePrefix) {
                body["title_prefix"] = titlePrefix
            }

            if !formData.studentIDs.isEmpty {
                body["student_ids"] = formData.studentIDs
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/documents/generate",
                method: "POST",
                body: body
            )

            successMessage = "Документ сгенерирован"
            await loadGeneratedDocuments(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сгенерировать документ: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createPublicDocument(
        api: SchoolAPI,
        formData: PublicDocumentFormData
    ) async -> Bool {
        await savePublicDocument(
            api: api,
            documentID: nil,
            formData: formData
        )
    }

    func updatePublicDocument(
        api: SchoolAPI,
        documentID: Int,
        formData: PublicDocumentFormData
    ) async -> Bool {
        await savePublicDocument(
            api: api,
            documentID: documentID,
            formData: formData
        )
    }

    private func savePublicDocument(
        api: SchoolAPI,
        documentID: Int?,
        formData: PublicDocumentFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanTitle = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            errorMessage = "Введите название документа"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "title": cleanTitle,
                "document_type": cleanOptional(formData.documentType) as Any,
                "is_public": formData.isPublic,
                "content": cleanOptional(formData.content) as Any,
                "file_url": cleanOptional(formData.fileURL) as Any
            ]

            let path: String
            let method: String

            if let documentID {
                path = "/api/v1/documents/public/\(documentID)"
                method = "PUT"
            } else {
                path = "/api/v1/documents/public"
                method = "POST"
            }

            _ = try await sendRequest(
                api: api,
                path: path,
                method: method,
                body: body
            )

            successMessage = documentID == nil ? "Публичный документ добавлен" : "Публичный документ обновлён"
            await loadPublicDocuments(api: api, showLoading: false)

            isSaving = false
            return true
        } catch {
            errorMessage = documentID == nil
                ? "Не удалось добавить публичный документ: \(error.localizedDescription)"
                : "Не удалось обновить публичный документ: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deletePublicDocument(
        api: SchoolAPI,
        document: PublicDocumentDTO
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/documents/public/\(document.id)",
                method: "DELETE"
            )

            publicDocuments.removeAll { $0.id == document.id }
            successMessage = "Публичный документ удалён"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить публичный документ: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func documentTypeTitle(_ value: String) -> String {
        documentTypes.first { $0.code == value }?.title ?? value
    }

    func studentName(for id: Int) -> String {
        students.first { $0.id == id }?.student_name ?? "Ученик \(id)"
    }

    func profileForStudent(_ studentID: Int) -> DocumentProfileDTO? {
        profiles.first { $0.student_id == studentID }
    }

    private func cleanOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw DocumentsError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw DocumentsError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("DOCUMENTS REQUEST:", method, url.absoluteString)
            print("DOCUMENTS BODY:", body)
        } else {
            print("DOCUMENTS REQUEST:", method, url.absoluteString)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentsError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("DOCUMENTS RESPONSE STATUS:", httpResponse.statusCode)
        print("DOCUMENTS RESPONSE BODY:", responseText)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw DocumentsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DocumentsError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

enum DocumentsError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}