import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class TextbooksViewModel: ObservableObject {
    @Published var items: [TextbookDTO] = []
    @Published var classes: [TextbookClassFilterDTO] = []
    @Published var subjects: [TextbookSubjectFilterDTO] = []
    @Published var materialTypes: [TextbookMaterialTypeFilterDTO] = TextbooksViewModel.defaultMaterialTypes

    @Published var selectedClassID = 0
    @Published var selectedSubjectID = 0
    @Published var selectedMaterialType = "all"
    @Published var searchText = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    static let defaultMaterialTypes: [TextbookMaterialTypeFilterDTO] = [
        TextbookMaterialTypeFilterDTO(code: "textbook", name: "Учебник"),
        TextbookMaterialTypeFilterDTO(code: "workbook", name: "Рабочая тетрадь"),
        TextbookMaterialTypeFilterDTO(code: "methodical", name: "Методичка"),
        TextbookMaterialTypeFilterDTO(code: "presentation", name: "Презентация"),
        TextbookMaterialTypeFilterDTO(code: "other", name: "Материал")
    ]

    var filteredItems: [TextbookDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return items
            .filter { item in
                if selectedClassID != 0, item.class_id != selectedClassID {
                    return false
                }

                if selectedSubjectID != 0, item.subject_id != selectedSubjectID {
                    return false
                }

                if selectedMaterialType != "all", item.material_type != selectedMaterialType {
                    return false
                }

                if !query.isEmpty, !item.normalizedSearchText.contains(query) {
                    return false
                }

                return true
            }
            .sorted {
                if ($0.sort_order ?? 0) == ($1.sort_order ?? 0) {
                    return $0.title < $1.title
                }

                return ($0.sort_order ?? 0) < ($1.sort_order ?? 0)
            }
    }

    var activeCount: Int {
        items.filter { $0.is_active }.count
    }

    func loadInitialData(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let filtersTask: Void = loadFilters(api: api)
        async let itemsTask: Void = loadItems(api: api)

        _ = await (filtersTask, itemsTask)

        isLoading = false
    }

    func refresh(api: SchoolAPI) async {
        await loadInitialData(api: api)
    }

    func loadFilters(api: SchoolAPI) async {
        do {
            let response = try await APIRequestService.shared.decode(
                TextbookFiltersResponseDTO.self,
                api: api,
                path: "/api/v1/textbooks/filters",
                method: "GET",
                logPrefix: "TEXTBOOK FILTERS"
            )

            classes = response.classes.sorted { $0.name < $1.name }
            subjects = response.subjects.sorted { $0.name < $1.name }

            if let loadedTypes = response.material_types,
               !loadedTypes.isEmpty {
                materialTypes = loadedTypes
                    .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .sorted { $0.name < $1.name }
            }
        } catch {
            errorMessage = "Не удалось загрузить фильтры: \(error.localizedDescription)"
        }
    }

    func loadItems(api: SchoolAPI) async {
        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "sort_by", value: "class_subject_title")
            ]

            if selectedClassID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(selectedClassID)"))
            }

            if selectedSubjectID != 0 {
                queryItems.append(URLQueryItem(name: "subject_id", value: "\(selectedSubjectID)"))
            }

            if selectedMaterialType != "all" {
                queryItems.append(URLQueryItem(name: "material_type", value: selectedMaterialType))
            }

            let cleanSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanSearch.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: cleanSearch))
            }

            let response = try await APIRequestService.shared.decode(
                TextbooksListResponseDTO.self,
                api: api,
                path: "/api/v1/textbooks",
                method: "GET",
                queryItems: queryItems,
                logPrefix: "TEXTBOOKS"
            )

            items = response.items
        } catch {
            errorMessage = "Не удалось загрузить учебники: \(error.localizedDescription)"
        }
    }

    func createItem(api: SchoolAPI, formData: TextbookFormData) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await multipartRequest(
                api: api,
                path: "/api/v1/textbooks",
                method: "POST",
                formData: formData,
                requireFile: true
            )

            successMessage = "Учебник добавлен"
            await loadItems(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось добавить учебник: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateItem(api: SchoolAPI, itemID: Int, formData: TextbookFormData) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await multipartRequest(
                api: api,
                path: "/api/v1/textbooks/\(itemID)",
                method: "PUT",
                formData: formData,
                requireFile: false
            )

            successMessage = "Учебник обновлён"
            await loadItems(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить учебник: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteItem(api: SchoolAPI, itemID: Int) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/textbooks/\(itemID)",
                method: "DELETE",
                logPrefix: "TEXTBOOK DELETE"
            )

            items.removeAll { $0.id == itemID }
            successMessage = "Учебник удалён"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить учебник: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    private func multipartRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        formData: TextbookFormData,
        requireFile: Bool
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw TextbookRequestError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw TextbookRequestError.badURL
        }

        if requireFile, formData.fileURL == nil {
            throw TextbookRequestError.fileRequired
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        appendTextField(name: "title", value: formData.title, boundary: boundary, body: &body)
        appendTextField(name: "description", value: formData.description, boundary: boundary, body: &body)
        appendTextField(name: "material_type", value: formData.materialType, boundary: boundary, body: &body)

        if formData.classID != 0 {
            appendTextField(name: "class_id", value: "\(formData.classID)", boundary: boundary, body: &body)
        }

        if formData.subjectID != 0 {
            appendTextField(name: "subject_id", value: "\(formData.subjectID)", boundary: boundary, body: &body)
        }

        appendTextField(name: "sort_order", value: "\(formData.sortOrder)", boundary: boundary, body: &body)
        appendTextField(name: "is_active", value: formData.isActive ? "true" : "false", boundary: boundary, body: &body)

        if let fileURL = formData.fileURL {
            let fileData = try readFileData(from: fileURL)
            let filename = fileURL.lastPathComponent
            let mimeType = mimeTypeForFile(filename)

            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: \(mimeType)\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        print("TEXTBOOK MULTIPART REQUEST:", method, url.absoluteString)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextbookRequestError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("TEXTBOOK MULTIPART STATUS:", httpResponse.statusCode)
        print("TEXTBOOK MULTIPART RESPONSE:", responseText)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw TextbookRequestError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TextbookRequestError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private func appendTextField(
        name: String,
        value: String,
        boundary: String,
        body: inout Data
    ) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    private func readFileData(from url: URL) throws -> Data {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: url)
    }

    private func mimeTypeForFile(_ filename: String) -> String {
        let lower = filename.lowercased()

        if lower.hasSuffix(".pdf") {
            return "application/pdf"
        }

        if lower.hasSuffix(".doc") {
            return "application/msword"
        }

        if lower.hasSuffix(".docx") {
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        }

        if lower.hasSuffix(".ppt") {
            return "application/vnd.ms-powerpoint"
        }

        if lower.hasSuffix(".pptx") {
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }

        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
            return "image/jpeg"
        }

        if lower.hasSuffix(".png") {
            return "image/png"
        }

        return "application/octet-stream"
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum TextbookRequestError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case fileRequired
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."

        case .badURL:
            return "Некорректный адрес запроса."

        case .badResponse:
            return "Некорректный ответ сервера."

        case .fileRequired:
            return "Выберите файл учебника."

        case .serverError(let statusCode, let text):
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if statusCode == 401 {
                return "Сессия истекла. Войдите снова."
            }

            if statusCode == 403 {
                return "У вас нет прав на это действие."
            }

            if statusCode == 422 {
                return cleanText.isEmpty ? "Проверьте заполнение полей." : "Проверьте заполнение полей. \(cleanText)"
            }

            if statusCode >= 500 {
                return "Ошибка сервера. Попробуйте позже."
            }

            return cleanText.isEmpty ? "Ошибка сервера: \(statusCode)" : "Ошибка сервера: \(statusCode). \(cleanText)"
        }
    }
}