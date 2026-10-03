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

    /// Admin/manager видят и отключённые материалы (сервер учитывает include_inactive только для них).
    var includeInactive = false

    static let defaultMaterialTypes: [TextbookMaterialTypeFilterDTO] = [
        // Коды сервера: textbook | literature | workbook | methodical | other (schemas/textbooks.py).
        TextbookMaterialTypeFilterDTO(code: "textbook", name: "Учебник"),
        TextbookMaterialTypeFilterDTO(code: "literature", name: "Литература"),
        TextbookMaterialTypeFilterDTO(code: "workbook", name: "Рабочая тетрадь"),
        TextbookMaterialTypeFilterDTO(code: "methodical", name: "Методичка"),
        TextbookMaterialTypeFilterDTO(code: "other", name: "Другое")
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

            let allowedCodes = Set(Self.defaultMaterialTypes.map { $0.code })

            if let loadedTypes = response.material_types?
                .filter({ allowedCodes.contains($0.code) }),
               !loadedTypes.isEmpty {
                materialTypes = loadedTypes
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

            if includeInactive {
                queryItems.append(URLQueryItem(name: "include_inactive", value: "true"))
            }

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

        if formData.fileURL != nil {
            return await replaceItemFile(api: api, itemID: itemID, formData: formData)
        }

        let cleanDescription = formData.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Сервер принимает изменения JSON-запросом (TextbookUpdateRequest), пустые поля — через clear_*.
        var body: [String: Any] = [
            "title": formData.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "material_type": formData.materialType,
            "sort_order": formData.sortOrder,
            "is_active": formData.isActive,
            "clear_description": cleanDescription.isEmpty,
            "clear_class_id": formData.classID == 0,
            "clear_subject_id": formData.subjectID == 0
        ]

        if !cleanDescription.isEmpty {
            body["description"] = cleanDescription
        }

        if formData.classID != 0 {
            body["class_id"] = formData.classID
        }

        if formData.subjectID != 0 {
            body["subject_id"] = formData.subjectID
        }

        body.setDivisionIDs(formData.divisionIDs)

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/textbooks/\(itemID)",
                method: "PUT",
                body: body,
                logPrefix: "TEXTBOOK UPDATE"
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

    /// Файл на сервере заменить нельзя: загружаем новый материал с теми же полями
    /// и удаляем прежний только после успешной загрузки.
    private func replaceItemFile(api: SchoolAPI, itemID: Int, formData: TextbookFormData) async -> Bool {
        do {
            _ = try await multipartRequest(
                api: api,
                path: "/api/v1/textbooks",
                method: "POST",
                formData: formData,
                requireFile: true
            )
        } catch {
            errorMessage = "Не удалось загрузить новый файл: \(error.localizedDescription)"
            isSaving = false
            return false
        }

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/textbooks/\(itemID)",
                method: "DELETE",
                logPrefix: "TEXTBOOK DELETE OLD"
            )

            successMessage = "Учебник обновлён, файл заменён"
        } catch {
            // Новый материал уже создан — форму закрываем, чтобы не загрузить его повторно.
            errorMessage = "Новый файл загружен, но прежний материал удалить не удалось. Удалите его вручную."
        }

        await loadItems(api: api)

        isSaving = false
        return true
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

        // Пустой список в multipart не передать: без поля сервер считает «вся школа».
        for divisionID in formData.divisionIDs ?? [] {
            appendTextField(name: "division_ids", value: "\(divisionID)", boundary: boundary, body: &body)
        }

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

        #if DEBUG
        print("TEXTBOOK MULTIPART REQUEST:", method, url.absoluteString)
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextbookRequestError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("TEXTBOOK MULTIPART STATUS:", httpResponse.statusCode)
        print("TEXTBOOK MULTIPART RESPONSE:", responseText)
        #endif

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

        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
            return "image/jpeg"
        }

        if lower.hasSuffix(".png") {
            return "image/png"
        }

        if lower.hasSuffix(".webp") {
            return "image/webp"
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
            if text.contains("Allowed file formats") {
                return "Неподходящий формат файла. Можно загрузить PDF, DOC, DOCX, JPG, PNG или WEBP."
            }

            if text.contains("File is too large") {
                return "Файл слишком большой. Максимальный размер — 50 МБ."
            }

            if text.contains("File is empty") {
                return "Файл пустой. Выберите другой файл."
            }

            return APIRequestError.serverError(statusCode: statusCode, text: text).errorDescription
        }
    }
}