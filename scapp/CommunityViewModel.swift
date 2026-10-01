import Foundation
import Combine
import UIKit
import ImageIO
import UniformTypeIdentifiers
import SchoolAPIClient

private struct CommunityPreparedUploadFile {
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let shouldDeleteAfterUpload: Bool
}

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published var dashboard: CommunityDashboardDTO?
    @Published var parentAds: [CommunityParentAdDTO] = []
    @Published var schoolNeeds: [CommunitySchoolNeedDTO] = []

    @Published var myParentAd: CommunityParentAdDTO?
    @Published var adminPromos: [CommunityAdminPromoDTO] = []

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isSendingContribution = false

    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadDashboard(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                CommunityDashboardDTO.self,
                api: api,
                path: "/api/v1/community/dashboard",
                method: "GET",
                logPrefix: "COMMUNITY DASHBOARD"
            )

            dashboard = response
            parentAds = response.parent_ads.filter { $0.status == "active" }
            schoolNeeds = response.school_needs.filter { ($0.status ?? "active") == "active" }
        } catch {
            errorMessage = "Не удалось загрузить объявления и потребности: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func sendContribution(
        api: SchoolAPI,
        needID: Int,
        amount: Double?,
        comment: String?
    ) async {
        isSendingContribution = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/needs/\(needID)/contributions",
                method: "POST",
                body: CommunityContributionRequestDTO(
                    amount: amount,
                    comment: comment
                ).body,
                logPrefix: "COMMUNITY NEED CONTRIBUTION"
            )

            successMessage = "Спасибо! Ваш вклад отмечен."
            await loadDashboard(api: api)
        } catch {
            errorMessage = "Не удалось отправить вклад: \(error.localizedDescription)"
        }

        isSendingContribution = false
    }

    func loadMyParentAd(api: SchoolAPI) async {
        errorMessage = nil

        do {
            let data = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/parent-ads/my",
                method: "GET",
                logPrefix: "COMMUNITY MY PARENT AD"
            )

            if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                myParentAd = nil
                return
            }

            myParentAd = try JSONDecoder().decode(CommunityParentAdDTO.self, from: data)
        } catch {
            errorMessage = "Не удалось загрузить ваше объявление: \(error.localizedDescription)"
        }
    }

    func saveMyParentAd(
        api: SchoolAPI,
        formData: CommunityParentAdFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let saved = try await APIRequestService.shared.decode(
                CommunityParentAdDTO.self,
                api: api,
                path: "/api/v1/community/parent-ads/my",
                method: "POST",
                body: formData.body,
                logPrefix: "COMMUNITY SAVE MY PARENT AD"
            )

            myParentAd = saved
            successMessage = "Ваше объявление сохранено"

            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить объявление: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func loadAdminPromos(api: SchoolAPI) async {
        errorMessage = nil

        do {
            let response = try await APIRequestService.shared.decode(
                CommunityAdminPromosResponseDTO.self,
                api: api,
                path: "/api/v1/community/admin/promos",
                method: "GET",
                logPrefix: "COMMUNITY ADMIN PROMOS"
            )

            adminPromos = response.items.sorted {
                ($0.updated_at ?? $0.created_at ?? "") > ($1.updated_at ?? $1.created_at ?? "")
            }
        } catch {
            errorMessage = "Не удалось загрузить промо: \(error.localizedDescription)"
        }
    }

    func createAdminPromo(
        api: SchoolAPI,
        formData: CommunityPromoFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos",
                method: "POST",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN PROMO CREATE"
            )

            successMessage = "Промо создано"
            await loadAdminPromos(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateAdminPromo(
        api: SchoolAPI,
        promoID: Int,
        formData: CommunityPromoFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos/\(promoID)",
                method: "PUT",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN PROMO UPDATE"
            )

            successMessage = "Промо обновлено"
            await loadAdminPromos(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteAdminPromo(
        api: SchoolAPI,
        promoID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/promos/\(promoID)",
                method: "DELETE",
                logPrefix: "COMMUNITY ADMIN PROMO DELETE"
            )

            adminPromos.removeAll { $0.id == promoID }
            successMessage = "Промо удалено"

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить промо: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func createAdminNeed(
        api: SchoolAPI,
        formData: CommunityNeedFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs",
                method: "POST",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN NEED CREATE"
            )

            successMessage = "Потребность школы создана"
            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось создать потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func updateAdminNeed(
        api: SchoolAPI,
        needID: Int,
        formData: CommunityNeedFormData
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs/\(needID)",
                method: "PUT",
                body: formData.bodyDictionary,
                logPrefix: "COMMUNITY ADMIN NEED UPDATE"
            )

            successMessage = "Потребность школы обновлена"
            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func deleteAdminNeed(
        api: SchoolAPI,
        needID: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/admin/needs/\(needID)",
                method: "DELETE",
                logPrefix: "COMMUNITY ADMIN NEED DELETE"
            )

            schoolNeeds.removeAll { $0.id == needID }
            successMessage = "Потребность школы удалена"

            await loadDashboard(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось удалить потребность: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func uploadCommunityPickedImage(
        api: SchoolAPI,
        picked: CommunityPickedImage
    ) async throws -> String {
        print("COMMUNITY PICKED IMAGE FILE SIZE:", picked.fileSize)
        print("COMMUNITY PICKED IMAGE MIME:", picked.mimeType)

        guard picked.fileSize > 0 else {
            throw APIRequestError.networkError("Файл пустой.")
        }

        guard picked.fileSize <= 25 * 1024 * 1024 else {
            throw APIRequestError.networkError("Файл слишком большой. Максимум 25 МБ до сжатия.")
        }

        let uploadSource: CommunityPreparedUploadFile

        if picked.fileSize <= 8 * 1024 * 1024 {
            uploadSource = CommunityPreparedUploadFile(
                fileURL: picked.fileURL,
                fileName: picked.fileName,
                mimeType: picked.mimeType,
                shouldDeleteAfterUpload: true
            )
        } else {
            uploadSource = try prepareCommunityImageFileForUpload(picked)
        }

        defer {
            if uploadSource.shouldDeleteAfterUpload {
                try? FileManager.default.removeItem(at: uploadSource.fileURL)
            }
        }

        return try await uploadCommunityImageFile(
            api: api,
            fileURL: uploadSource.fileURL,
            fileName: uploadSource.fileName,
            mimeType: uploadSource.mimeType
        )
    }

    private func prepareCommunityImageFileForUpload(
        _ picked: CommunityPickedImage
    ) throws -> CommunityPreparedUploadFile {
        guard let source = CGImageSourceCreateWithURL(picked.fileURL as CFURL, nil) else {
            throw APIRequestError.networkError("Не удалось прочитать изображение.")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw APIRequestError.networkError("Не удалось подготовить изображение.")
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-prepared-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw APIRequestError.networkError("Не удалось создать файл изображения.")
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.78
        ]

        CGImageDestinationAddImage(destination, thumbnail, destinationOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw APIRequestError.networkError("Не удалось сжать изображение.")
        }

        let values = try outputURL.resourceValues(forKeys: [.fileSizeKey])
        let outputSize = values.fileSize ?? 0

        guard outputSize > 0 else {
            throw APIRequestError.networkError("Файл пустой после подготовки.")
        }

        guard outputSize <= 8 * 1024 * 1024 else {
            throw APIRequestError.networkError("Изображение слишком большое после сжатия. Максимум 8 МБ.")
        }

        try? FileManager.default.removeItem(at: picked.fileURL)

        return CommunityPreparedUploadFile(
            fileURL: outputURL,
            fileName: "community-image-\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg",
            shouldDeleteAfterUpload: true
        )
    }

    private func uploadCommunityImageFile(
        api: SchoolAPI,
        fileURL: URL,
        fileName: String,
        mimeType: String
    ) async throws -> String {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0

        #if DEBUG
        print("COMMUNITY IMAGE UPLOAD FILE SIZE:", fileSize)
        #endif

        guard fileSize > 0 else {
            throw APIRequestError.networkError("Файл пустой.")
        }

        guard fileSize <= 8 * 1024 * 1024 else {
            throw APIRequestError.networkError("Файл слишком большой. Максимум 8 МБ.")
        }

        guard mimeType == "image/jpeg" || mimeType == "image/png" || mimeType == "image/webp" else {
            throw APIRequestError.networkError("Поддерживаются только JPEG, PNG и WEBP.")
        }

        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru/api/v1/community/uploads/image") else {
            throw APIRequestError.badURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let multipartFileURL = try makeCommunityMultipartUploadFileFromFile(
            sourceFileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            boundary: boundary
        )

        defer {
            try? FileManager.default.removeItem(at: multipartFileURL)
        }

        #if DEBUG
        print("COMMUNITY IMAGE UPLOAD REQUEST:", url.absoluteString)
        #endif

        let (responseData, response) = try await URLSession.shared.upload(
            for: request,
            fromFile: multipartFileURL
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIRequestError.badResponse
        }

        let responseText = String(data: responseData, encoding: .utf8) ?? ""

        #if DEBUG
        print("COMMUNITY IMAGE UPLOAD STATUS:", httpResponse.statusCode)
        print("COMMUNITY IMAGE UPLOAD BODY:", responseText)
        #endif

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

        let decoded = try JSONDecoder().decode(CommunityImageUploadResponseDTO.self, from: responseData)
        return decoded.url
    }

    private func makeCommunityMultipartUploadFileFromFile(
        sourceFileURL: URL,
        fileName: String,
        mimeType: String,
        boundary: String
    ) throws -> URL {
        let safeFileName = fileName
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let finalFileName = safeFileName.isEmpty
            ? "community-image-\(Int(Date().timeIntervalSince1970)).jpg"
            : safeFileName

        let uploadFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-upload-\(UUID().uuidString).tmp")

        FileManager.default.createFile(atPath: uploadFileURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: uploadFileURL)
        let inputHandle = try FileHandle(forReadingFrom: sourceFileURL)

        do {
            let header = """
            --\(boundary)\r
            Content-Disposition: form-data; name="file"; filename="\(finalFileName)"\r
            Content-Type: \(mimeType)\r
            \r

            """

            try outputHandle.write(contentsOf: Data(header.utf8))

            while true {
                let chunk = try inputHandle.read(upToCount: 256 * 1024) ?? Data()

                if chunk.isEmpty {
                    break
                }

                try outputHandle.write(contentsOf: chunk)
            }

            let footer = """

            \r
            --\(boundary)--\r

            """

            try outputHandle.write(contentsOf: Data(footer.utf8))

            try inputHandle.close()
            try outputHandle.close()
        } catch {
            try? inputHandle.close()
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: uploadFileURL)
            throw error
        }

        return uploadFileURL
    }
}

@MainActor
final class CommunityPromoViewModel: ObservableObject {
    @Published var promoToShow: CommunityPromoDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var checkedUserID: Int?

    func checkPromoForCurrentUser(
        api: SchoolAPI,
        userID: Int?
    ) async {
        guard let userID else {
            return
        }

        guard checkedUserID != userID else {
            return
        }

        checkedUserID = userID
        await checkPromo(api: api)
    }

    func forceCheckPromo(api: SchoolAPI) async {
        await checkPromo(api: api)
    }

    func resetCheckedUser() {
        checkedUserID = nil
        promoToShow = nil
        errorMessage = nil
    }

    private func checkPromo(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/dashboard",
                method: "GET",
                logPrefix: "COMMUNITY PROMO RAW DASHBOARD"
            )

            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("COMMUNITY PROMO RAW BODY:", responseText)

            let response = try JSONDecoder().decode(CommunityDashboardDTO.self, from: data)

            print("COMMUNITY PROMO COUNT:", response.promos.count)

            if let firstPromo = response.promos.first {
                print("COMMUNITY PROMO FOUND:", firstPromo.id, firstPromo.title)
                promoToShow = firstPromo
            } else {
                print("COMMUNITY PROMO EMPTY")
                promoToShow = nil
            }
        } catch {
            errorMessage = "Не удалось загрузить промо: \(error.localizedDescription)"
            print("COMMUNITY PROMO ERROR:", error.localizedDescription)
        }

        isLoading = false
    }

    func markImpression(api: SchoolAPI, promo: CommunityPromoDTO) async {
        guard promo.id > 0 else {
            print("COMMUNITY PROMO IMPRESSION SKIPPED: BAD PROMO ID")
            return
        }

        do {
            _ = try await APIRequestService.shared.request(
                api: api,
                path: "/api/v1/community/promos/\(promo.id)/impression",
                method: "POST",
                body: [:],
                logPrefix: "COMMUNITY PROMO IMPRESSION"
            )
        } catch {
            errorMessage = "Не удалось зафиксировать показ промо: \(error.localizedDescription)"
            print("COMMUNITY PROMO IMPRESSION ERROR:", error.localizedDescription)
        }
    }
}