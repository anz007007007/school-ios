import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published var students: [DocumentStudentDTO] = []
    @Published var profiles: [DocumentProfileDTO] = []
    @Published var generatedDocuments: [GeneratedDocumentDTO] = []
    @Published var publicDocuments: [PublicDocumentDTO] = []
    /// Родители для выбора parent_user_id (только admin/manager).
    @Published var parents: [AdminParentDTO] = []

    @Published var selectedStudentID: Int = 0
    @Published var selectedDocumentType: String = "all"
    @Published var searchText = ""

    /// Профили, ученики и сгенерированные документы сервер отдаёт только
    /// admin/manager/parent/student; остальным ролям — 403. Публичные — всем.
    @Published private(set) var canReadProfiles = true

    @Published var isLoading = false
    @Published var isLoadingStudents = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let documentTypes = DocumentTypes.generationTypes

    var filteredProfiles: [DocumentProfileDTO] {
        var result = profiles

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { profile in
                profile.displayStudentName.localizedCaseInsensitiveContains(query)
                || profile.displayParentName.localizedCaseInsensitiveContains(query)
                || (profile.class_name ?? "").localizedCaseInsensitiveContains(query)
                || (profile.parent_phone ?? "").localizedCaseInsensitiveContains(query)
                || (profile.parent_email ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            $0.displayStudentName < $1.displayStudentName
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
                || DocumentTypes.title(item.document_type).localizedCaseInsensitiveContains(query)
                || (item.student_full_name ?? "").localizedCaseInsensitiveContains(query)
                || (item.parent_full_name ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.generated_at ?? "") > ($1.generated_at ?? "")
        }
    }

    var filteredPublicDocuments: [PublicDocumentDTO] {
        var result = publicDocuments

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || (item.description ?? "").localizedCaseInsensitiveContains(query)
                || (item.author_name ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            ($0.created_at ?? "") > ($1.created_at ?? "")
        }
    }

    var completedProfilesCount: Int {
        profiles.filter(\.isCompleted).count
    }

    func loadInitialData(
        api: SchoolAPI,
        canReadProfiles: Bool,
        canManageProfiles: Bool
    ) async {
        self.canReadProfiles = canReadProfiles

        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let studentsTask: Void = loadStudents(api: api)
        async let profilesTask: Void = loadProfiles(api: api)
        async let generatedTask: Void = loadGeneratedDocuments(api: api)
        async let publicTask: Void = loadPublicDocuments(api: api)
        async let parentsTask: Void = loadParents(api: api, canManageProfiles: canManageProfiles)

        _ = await (studentsTask, profilesTask, generatedTask, publicTask, parentsTask)

        isLoading = false
    }

    func loadStudents(api: SchoolAPI) async {
        guard canReadProfiles else {
            students = []
            return
        }

        isLoadingStudents = true

        do {
            let decoded = try await APIRequestService.shared.decode(
                DocumentStudentsListResponseDTO.self,
                api: api,
                path: "/api/v1/documents/students",
                logPrefix: "DOCUMENTS"
            )
            students = decoded.items
        } catch {
            if !Self.isForbidden(error) {
                errorMessage = "Не удалось загрузить учеников: \(error.localizedDescription)"
            }
        }

        isLoadingStudents = false
    }

    func loadProfiles(api: SchoolAPI) async {
        guard canReadProfiles else {
            profiles = []
            return
        }

        do {
            let decoded = try await APIRequestService.shared.decode(
                DocumentProfilesListResponseDTO.self,
                api: api,
                path: "/api/v1/documents/profiles",
                logPrefix: "DOCUMENTS"
            )
            profiles = decoded.items
        } catch {
            // 403 на профилях — не ошибка экрана: роль просто не видит этот раздел.
            if Self.isForbidden(error) {
                profiles = []
            } else {
                errorMessage = "Не удалось загрузить профили документов: \(error.localizedDescription)"
            }
        }
    }

    func loadGeneratedDocuments(api: SchoolAPI) async {
        guard canReadProfiles else {
            generatedDocuments = []
            return
        }

        do {
            let decoded = try await APIRequestService.shared.decode(
                GeneratedDocumentsListResponseDTO.self,
                api: api,
                path: "/api/v1/documents/generated",
                logPrefix: "DOCUMENTS"
            )
            generatedDocuments = decoded.items
        } catch {
            if Self.isForbidden(error) {
                generatedDocuments = []
            } else {
                errorMessage = "Не удалось загрузить сгенерированные документы: \(error.localizedDescription)"
            }
        }
    }

    func loadPublicDocuments(api: SchoolAPI) async {
        do {
            let decoded = try await APIRequestService.shared.decode(
                PublicDocumentsListResponseDTO.self,
                api: api,
                path: "/api/v1/documents/public",
                logPrefix: "DOCUMENTS"
            )
            publicDocuments = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить публичные документы: \(error.localizedDescription)"
        }
    }

    /// Без списка родителей форма всё равно открывается, поэтому ошибку не показываем.
    private func loadParents(api: SchoolAPI, canManageProfiles: Bool) async {
        guard canManageProfiles else {
            parents = []
            return
        }

        do {
            let decoded = try await APIRequestService.shared.decode(
                AdminParentsResponseDTO.self,
                api: api,
                path: "/api/v1/admin/parents",
                queryItems: [URLQueryItem(name: "is_active", value: "true")],
                logPrefix: "DOCUMENTS PARENTS"
            )
            parents = decoded.items
        } catch {
            #if DEBUG
            print("DOCUMENTS PARENTS ERROR:", error.localizedDescription)
            #endif
        }
    }

    func saveProfile(
        api: SchoolAPI,
        formData: DocumentProfileFormData
    ) async -> Bool {
        if let validation = formData.validationError() {
            errorMessage = validation
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/documents/profiles",
                method: "PUT",
                body: formData.requestBody,
                logPrefix: "DOCUMENTS"
            )

            successMessage = "Профиль документов сохранён"
            await loadProfiles(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить профиль: \(Self.readableError(error))"
            isSaving = false
            return false
        }
    }

    func generateDocument(
        api: SchoolAPI,
        formData: DocumentGenerateFormData
    ) async -> Bool {
        guard formData.profileID != 0 else {
            errorMessage = "Выберите профиль"
            return false
        }

        guard documentTypes.contains(where: { $0.code == formData.documentType }) else {
            errorMessage = "Выберите тип документа"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/documents/generate",
                method: "POST",
                body: [
                    "profile_id": formData.profileID,
                    "document_type": formData.documentType
                ],
                logPrefix: "DOCUMENTS"
            )

            successMessage = "Документ сгенерирован"
            await loadGeneratedDocuments(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сгенерировать документ: \(Self.readableError(error))"
            isSaving = false
            return false
        }
    }

    /// HTML сгенерированного документа (GET /documents/generated/{id}).
    func loadGeneratedDocumentHTML(
        api: SchoolAPI,
        documentID: Int
    ) async throws -> String {
        let data = try await APIRequestService.shared.request(
            api: api,
            path: "/api/v1/documents/generated/\(documentID)",
            method: "GET",
            logPrefix: "DOCUMENTS HTML"
        )

        return String(data: data, encoding: .utf8) ?? ""
    }

    func createPublicDocument(
        api: SchoolAPI,
        formData: PublicDocumentFormData
    ) async -> Bool {
        await savePublicDocument(
            api: api,
            document: nil,
            formData: formData
        )
    }

    func updatePublicDocument(
        api: SchoolAPI,
        document: PublicDocumentDTO,
        formData: PublicDocumentFormData
    ) async -> Bool {
        await savePublicDocument(
            api: api,
            document: document,
            formData: formData
        )
    }

    private func savePublicDocument(
        api: SchoolAPI,
        document: PublicDocumentDTO?,
        formData: PublicDocumentFormData
    ) async -> Bool {
        let cleanTitle = formData.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanTitle.count >= 2 else {
            errorMessage = "Введите название документа (не короче 2 символов)"
            return false
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            if let document {
                _ = try await APIRequestService.shared.request(
                    api: api,
                    path: "/api/v1/documents/public/\(document.id)",
                    method: "PUT",
                    body: formData.updateBody(original: document),
                    logPrefix: "DOCUMENTS"
                )
            } else {
                _ = try await APIRequestService.shared.request(
                    api: api,
                    path: "/api/v1/documents/public",
                    method: "POST",
                    body: formData.createBody,
                    logPrefix: "DOCUMENTS"
                )
            }

            successMessage = document == nil ? "Публичный документ добавлен" : "Публичный документ обновлён"
            await loadPublicDocuments(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = document == nil
                ? "Не удалось добавить публичный документ: \(Self.readableError(error))"
                : "Не удалось обновить публичный документ: \(Self.readableError(error))"
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
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/documents/public/\(document.id)",
                method: "DELETE",
                logPrefix: "DOCUMENTS"
            )

            publicDocuments.removeAll { $0.id == document.id }
            successMessage = "Публичный документ удалён"
            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить публичный документ: \(Self.readableError(error))"
            isSaving = false
            return false
        }
    }

    func documentTypeTitle(_ value: String?) -> String {
        DocumentTypes.title(value)
    }

    func studentName(for id: Int) -> String {
        students.first { $0.id == id }?.displayName ?? "Ученик"
    }

    func profileForStudent(_ studentID: Int) -> DocumentProfileDTO? {
        profiles.first { $0.student_id == studentID }
    }

    private static func isForbidden(_ error: Error) -> Bool {
        if case APIRequestError.serverError(let statusCode, _) = error {
            return statusCode == 403
        }

        return false
    }

    /// Переводит известные ответы сервера по документам, остальное — через APIRequestError.
    private static func readableError(_ error: Error) -> String {
        if case APIRequestError.serverError(_, let text) = error {
            let lowercased = text.lowercased()

            if lowercased.contains("only admin or manager can manage documents") {
                return "Управлять документами могут только администратор и менеджер."
            }

            if lowercased.contains("you can create profile only for yourself") {
                return "Профиль можно создать только для себя."
            }

            if lowercased.contains("you do not have access to this student") {
                return "Нет доступа к этому ученику."
            }

            if lowercased.contains("document profile not found") {
                return "Профиль документов не найден. Обновите экран."
            }

            if lowercased.contains("document not found") {
                return "Документ не найден. Обновите экран."
            }

            if lowercased.contains("you do not have access to document profiles") {
                return "Нет доступа к профилям документов."
            }
        }

        return error.localizedDescription
    }
}
