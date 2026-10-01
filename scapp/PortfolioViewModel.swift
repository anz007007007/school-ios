import Foundation
import SchoolAPIClient
import UIKit
import Combine


@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published var students: [PortfolioStudentDTO] = []
    @Published var selectedStudent: PortfolioStudentDTO?
    @Published var portfolio: PortfolioDTO?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let requestService = APIRequestService.shared
    private var portfolioLoadTask: Task<PortfolioDTO, Error>?
    private var portfolioLoadID = 0

    func loadInitial(
        api: SchoolAPI,
        roleCode: String
    ) async {
        portfolioLoadTask?.cancel()
        portfolioLoadID += 1
        let loadID = portfolioLoadID

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let loadedStudents = try await loadAvailableStudents(
                api: api,
                roleCode: roleCode
            )

            guard loadID == portfolioLoadID else {
                return
            }

            students = loadedStudents

            if selectedStudent == nil || !students.contains(where: { $0.id == selectedStudent?.id }) {
                selectedStudent = students.first
                portfolio = nil
            }

            if let student = selectedStudent {
                do {
                    let loaded = try await fetchPortfolio(api: api, studentId: student.id)

                    guard loadID == portfolioLoadID else {
                        return
                    }

                    if selectedStudent?.id == student.id {
                        portfolio = loaded
                    }
                } catch {
                    guard loadID == portfolioLoadID, !Self.isCancellation(error) else {
                        return
                    }

                    try await selectFirstAccessiblePortfolio(api: api, loadID: loadID)
                }
            } else {
                portfolio = nil
            }
        } catch {
            guard loadID == portfolioLoadID, !Self.isCancellation(error) else {
                return
            }

            errorMessage = error.localizedDescription
        }

        if loadID == portfolioLoadID {
            isLoading = false
        }
    }

    private func loadAvailableStudents(
        api: SchoolAPI,
        roleCode: String
    ) async throws -> [PortfolioStudentDTO] {
        do {
            let response = try await requestService.decode(
                PortfolioStudentsResponseDTO.self,
                api: api,
                path: "/api/v1/portfolio/students",
                logPrefix: "PORTFOLIO STUDENTS"
            )

            return response.items
        } catch {
            print("PORTFOLIO STUDENTS PRIMARY ERROR:", error.localizedDescription)
            return try await loadAvailableStudentsFallback(
                api: api,
                roleCode: roleCode
            )
        }
    }

    private func loadAvailableStudentsFallback(
        api: SchoolAPI,
        roleCode: String
    ) async throws -> [PortfolioStudentDTO] {
        switch roleCode {
        case "parent":
            return try await loadParentStudentsFallback(api: api)

        case "teacher":
            return try await loadTeacherStudentsFallback(api: api)

        case "admin", "manager":
            return try await loadStudentsFallback(
                api: api,
                path: "/api/v1/admin/students",
                logPrefix: "PORTFOLIO STUDENTS FALLBACK ADMIN"
            )

        case "student":
            return try await loadStudentsFallback(
                api: api,
                path: "/api/v1/students",
                logPrefix: "PORTFOLIO STUDENTS FALLBACK STUDENT"
            )

        default:
            return try await loadStudentsFallback(
                api: api,
                path: "/api/v1/students",
                logPrefix: "PORTFOLIO STUDENTS FALLBACK DEFAULT"
            )
        }
    }

    private func loadParentStudentsFallback(api: SchoolAPI) async throws -> [PortfolioStudentDTO] {
        do {
            let response = try await requestService.decode(
                FamilyDashboardResponseDTO.self,
                api: api,
                path: "/api/v1/school-info/family-dashboard",
                logPrefix: "PORTFOLIO STUDENTS FALLBACK FAMILY"
            )

            let items = response.students.map { student in
                PortfolioStudentDTO(
                    id: student.id,
                    user_id: nil,
                    class_id: nil,
                    student_name: student.displayName,
                    class_name: student.class_name
                )
            }

            if !items.isEmpty {
                return items
            }
        } catch {
            print("PORTFOLIO STUDENTS FAMILY FALLBACK ERROR:", error.localizedDescription)
        }

        return try await loadStudentsFallback(
            api: api,
            path: "/api/v1/students",
            logPrefix: "PORTFOLIO STUDENTS FALLBACK PARENT STUDENTS"
        )
    }

    private func loadTeacherStudentsFallback(api: SchoolAPI) async throws -> [PortfolioStudentDTO] {
        let classesResponse = try await requestService.decode(
            TeacherClassesResponseDTO.self,
            api: api,
            path: "/api/v1/teacher/classes",
            logPrefix: "PORTFOLIO TEACHER CLASSES"
        )

        var result: [PortfolioStudentDTO] = []
        var seenIDs = Set<Int>()

        for item in classesResponse.items {
            do {
                let studentsResponse = try await requestService.decode(
                    PortfolioFallbackStudentsResponseDTO.self,
                    api: api,
                    path: "/api/v1/teacher/students",
                    queryItems: [
                        URLQueryItem(name: "class_id", value: "\(item.id)")
                    ],
                    logPrefix: "PORTFOLIO TEACHER STUDENTS CLASS \(item.id)"
                )

                for student in studentsResponse.items {
                    let mapped = student.asPortfolioStudent

                    if !seenIDs.contains(mapped.id) {
                        seenIDs.insert(mapped.id)
                        result.append(mapped)
                    }
                }
            } catch {
                print("PORTFOLIO TEACHER STUDENTS ERROR class_id=\(item.id):", error.localizedDescription)
            }
        }

        if result.isEmpty {
            throw APIRequestError.serverError(
                statusCode: 422,
                text: "Не удалось получить учеников учителя. Проверьте привязку классов."
            )
        }

        return result.sorted {
            $0.student_name.localizedCaseInsensitiveCompare($1.student_name) == .orderedAscending
        }
    }

    private func loadStudentsFallback(
        api: SchoolAPI,
        path: String,
        logPrefix: String
    ) async throws -> [PortfolioStudentDTO] {
        let response = try await requestService.decode(
            PortfolioFallbackStudentsResponseDTO.self,
            api: api,
            path: path,
            logPrefix: logPrefix
        )

        return response.items
            .map { $0.asPortfolioStudent }
            .filter { !$0.student_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func selectFirstAccessiblePortfolio(api: SchoolAPI, loadID: Int) async throws {
        var lastError: Error?

        for student in students {
            do {
                let loaded = try await fetchPortfolio(api: api, studentId: student.id)

                guard loadID == portfolioLoadID else {
                    return
                }

                selectedStudent = student
                portfolio = loaded
                return
            } catch {
                if Self.isCancellation(error) || loadID != portfolioLoadID {
                    return
                }

                lastError = error
                print("PORTFOLIO ACCESS CHECK FAILED student_id=\(student.id):", error.localizedDescription)
            }
        }

        portfolio = nil

        throw lastError ?? APIRequestError.serverError(
            statusCode: 403,
            text: "Нет доступных портфолио."
        )
    }

    func selectStudent(_ student: PortfolioStudentDTO, api: SchoolAPI) async {
        if selectedStudent?.id != student.id {
            // Старое портфолио не должно оставаться на экране под именем другого ребёнка.
            portfolio = nil
        }

        selectedStudent = student
        await refreshPortfolio(api: api)
    }

    /// Загружает портфолио выбранного ребёнка. Прошлая загрузка отменяется,
    /// ответ записывается только если этот ребёнок всё ещё выбран.
    func refreshPortfolio(api: SchoolAPI) async {
        guard let student = selectedStudent else {
            portfolioLoadTask?.cancel()
            portfolio = nil
            return
        }

        portfolioLoadTask?.cancel()
        portfolioLoadID += 1
        let loadID = portfolioLoadID

        isLoading = true
        errorMessage = nil
        successMessage = nil

        let task = Task { [weak self] () throws -> PortfolioDTO in
            guard let self else {
                throw CancellationError()
            }

            return try await self.fetchPortfolio(api: api, studentId: student.id)
        }

        portfolioLoadTask = task

        let result = await task.result

        guard loadID == portfolioLoadID else {
            return
        }

        switch result {
        case .success(let loaded):
            if selectedStudent?.id == student.id {
                portfolio = loaded
            }
        case .failure(let error):
            if !Self.isCancellation(error), selectedStudent?.id == student.id {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func fetchPortfolio(api: SchoolAPI, studentId: Int) async throws -> PortfolioDTO {
        let decoded = try await requestService.decode(
            PortfolioDTO.self,
            api: api,
            path: "/api/v1/portfolio/\(studentId)",
            logPrefix: "PORTFOLIO GET"
        )

        return normalized(decoded)
    }

    /// Повторно загружает портфолио ученика после сохранения/отзыва
    /// и записывает его, только если этот ученик всё ещё выбран.
    private func reloadPortfolioIfStillSelected(api: SchoolAPI, studentId: Int) async throws {
        let loaded = try await fetchPortfolio(api: api, studentId: studentId)

        if selectedStudent?.id == studentId {
            portfolio = loaded
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSURLErrorCancelled
    }

    func savePortfolio(api: SchoolAPI, portfolio draft: PortfolioDTO) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let cleanedBlocks = draft.blocks
                .map { block -> PortfolioBlockDTO in
                    var copy = block
                    copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    copy.category = cleanOptionalString(copy.category)
                    copy.period_label = cleanOptionalString(copy.period_label)
                    copy.event_date = cleanOptionalString(copy.event_date)
                    copy.description = cleanOptionalString(copy.description)
                    copy.image_url = cleanOptionalString(copy.image_url)
                    copy.file_url = cleanOptionalString(copy.file_url)
                    copy.file_name = cleanOptionalString(copy.file_name)
                    copy.file_type = cleanOptionalString(copy.file_type)
                    return copy
                }
                .filter { block in
                    !block.title.isEmpty
                }
                .sorted { $0.sort_order < $1.sort_order }

            let cleanedBadges = draft.badges
                .map { badge -> PortfolioBadgeDTO in
                    var copy = badge
                    copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    copy.badge_type = copy.badge_type.trimmingCharacters(in: .whitespacesAndNewlines)
                    copy.description = cleanOptionalString(copy.description)
                    copy.icon = cleanOptionalString(copy.icon)

                    if copy.badge_type.isEmpty {
                        copy.badge_type = "custom"
                    }

                    return copy
                }
                .filter { badge in
                    !badge.title.isEmpty
                }
                .sorted { $0.sort_order < $1.sort_order }

            let request = PortfolioSaveRequestDTO(
                student_id: draft.student_id,
                title: cleanOptionalString(draft.title),
                tagline: cleanOptionalString(draft.tagline),
                summary: cleanOptionalString(draft.summary),
                avatar_url: cleanOptionalString(draft.avatar_url),
                theme_code: draft.theme_code,
                is_public: draft.is_public,
                blocks: cleanedBlocks,
                badges: cleanedBadges
            )

            let body = try request.asDictionary()

            let response = try await requestService.decode(
                PortfolioSaveResponseDTO.self,
                api: api,
                path: "/api/v1/portfolio",
                method: "PUT",
                body: body,
                logPrefix: "PORTFOLIO SAVE"
            )

            successMessage = "Портфолио сохранено"
            try await reloadPortfolioIfStillSelected(api: api, studentId: draft.student_id)

            print("PORTFOLIO SAVED ID:", response.portfolio_id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func createTeacherReview(
        api: SchoolAPI,
        portfolioId: Int,
        studentId: Int,
        title: String,
        body: String
    ) async {
        // Отзыв можно оставить только в портфолио того ребёнка, который сейчас выбран.
        guard selectedStudent?.id == studentId,
              let current = portfolio,
              current.id == portfolioId,
              current.student_id == studentId else {
            errorMessage = "Портфолио изменилось. Откройте нужного ученика и повторите."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let request = PortfolioReviewCreateRequestDTO(
                portfolio_id: portfolioId,
                title: title,
                body: body
            )

            let response = try await requestService.decode(
                PortfolioReviewCreateResponseDTO.self,
                api: api,
                path: "/api/v1/portfolio/reviews",
                method: "POST",
                body: try request.asDictionary(),
                logPrefix: "PORTFOLIO REVIEW"
            )

            successMessage = response.status == "review_created"
                ? "Отзыв добавлен"
                : "Отзыв отправлен"

            try await reloadPortfolioIfStillSelected(api: api, studentId: studentId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func uploadFile(
        api: SchoolAPI,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> PortfolioUploadResponseDTO {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru/api/v1/portfolio/upload") else {
            throw APIRequestError.badURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            data: data
        )

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIRequestError.badResponse
        }

        let responseText = String(data: responseData, encoding: .utf8) ?? ""

        print("PORTFOLIO UPLOAD STATUS:", httpResponse.statusCode)
        print("PORTFOLIO UPLOAD BODY:", responseText)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.serverError(
                statusCode: httpResponse.statusCode,
                text: responseText
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIRequestError.serverError(
                statusCode: httpResponse.statusCode,
                text: responseText
            )
        }

        do {
            return try JSONDecoder().decode(PortfolioUploadResponseDTO.self, from: responseData)
        } catch {
            throw APIRequestError.decodingError(error.localizedDescription)
        }
    }

    private func normalized(_ portfolio: PortfolioDTO) -> PortfolioDTO {
        var copy = portfolio
        copy.blocks = portfolio.blocks.sorted { first, second in
            if first.block_type == PortfolioBlockTypes.timeline,
               second.block_type == PortfolioBlockTypes.timeline,
               let firstDate = first.event_date,
               let secondDate = second.event_date,
               firstDate != secondDate {
                return firstDate < secondDate
            }

            return first.sort_order < second.sort_order
        }

        copy.badges = portfolio.badges.sorted { $0.sort_order < $1.sort_order }

        return copy
    }

    private func makeMultipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return body
    }

    private func cleanOptionalString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return object
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}