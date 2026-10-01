import Foundation
import ImageIO
import UniformTypeIdentifiers
import SchoolAPIClient

/// Ошибки подготовки и загрузки изображения: текст показывается пользователю как есть
/// (APIRequestError.networkError добавил бы ложное «Ошибка сети:»).
enum CommunityImageError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}

enum CommunityImageUploadService {
    /// Как MAX_COMMUNITY_IMAGE_SIZE_BYTES на сервере (routers/community_ads.py).
    static let maxUploadSizeBytes = 8 * 1024 * 1024

    private struct PreparedUploadFile {
        let fileURL: URL
        let fileName: String
        let mimeType: String
        let shouldDeleteAfterUpload: Bool
    }

    static func uploadPickedImage(
        api: SchoolAPI,
        picked: CommunityPickedImage
    ) async throws -> String {
        print("COMMUNITY SERVICE PICKED FILE SIZE:", picked.fileSize)
        print("COMMUNITY SERVICE PICKED MIME:", picked.mimeType)

        guard picked.fileSize > 0 else {
            throw CommunityImageError.message("Файл пустой.")
        }

        guard picked.fileSize <= 25 * 1024 * 1024 else {
            throw CommunityImageError.message("Файл слишком большой (больше 25 МБ). Выберите изображение поменьше: после сжатия оно должно быть не больше 8 МБ.")
        }

        let uploadSource: PreparedUploadFile

        if picked.fileSize <= maxUploadSizeBytes {
            uploadSource = PreparedUploadFile(
                fileURL: picked.fileURL,
                fileName: picked.fileName,
                mimeType: picked.mimeType,
                shouldDeleteAfterUpload: true
            )
        } else {
            uploadSource = try prepareImageFileForUpload(picked)
        }

        defer {
            if uploadSource.shouldDeleteAfterUpload {
                try? FileManager.default.removeItem(at: uploadSource.fileURL)
            }
        }

        return try await uploadImageFile(
            api: api,
            fileURL: uploadSource.fileURL,
            fileName: uploadSource.fileName,
            mimeType: uploadSource.mimeType
        )
    }

    private static func prepareImageFileForUpload(
        _ picked: CommunityPickedImage
    ) throws -> PreparedUploadFile {
        guard let source = CGImageSourceCreateWithURL(picked.fileURL as CFURL, nil) else {
            throw CommunityImageError.message("Не удалось прочитать изображение.")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CommunityImageError.message("Не удалось подготовить изображение.")
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
            throw CommunityImageError.message("Не удалось создать файл изображения.")
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.78
        ]

        CGImageDestinationAddImage(destination, thumbnail, destinationOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CommunityImageError.message("Не удалось сжать изображение.")
        }

        let values = try outputURL.resourceValues(forKeys: [.fileSizeKey])
        let outputSize = values.fileSize ?? 0

        guard outputSize > 0 else {
            throw CommunityImageError.message("Файл пустой после подготовки.")
        }

        guard outputSize <= maxUploadSizeBytes else {
            throw CommunityImageError.message("Изображение слишком большое даже после сжатия. Максимальный размер изображения — 8 МБ.")
        }

        try? FileManager.default.removeItem(at: picked.fileURL)

        return PreparedUploadFile(
            fileURL: outputURL,
            fileName: "community-image-\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg",
            shouldDeleteAfterUpload: true
        )
    }

    private static func uploadImageFile(
        api: SchoolAPI,
        fileURL: URL,
        fileName: String,
        mimeType: String
    ) async throws -> String {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0

        print("COMMUNITY SERVICE UPLOAD FILE SIZE:", fileSize)

        guard fileSize > 0 else {
            throw CommunityImageError.message("Файл пустой.")
        }

        guard fileSize <= maxUploadSizeBytes else {
            throw CommunityImageError.message("Файл слишком большой. Максимальный размер изображения — 8 МБ.")
        }

        guard mimeType == "image/jpeg" || mimeType == "image/png" || mimeType == "image/webp" else {
            throw CommunityImageError.message("Поддерживаются только JPEG, PNG и WEBP.")
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

        let multipartFileURL = try makeMultipartUploadFileFromFile(
            sourceFileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            boundary: boundary
        )

        defer {
            try? FileManager.default.removeItem(at: multipartFileURL)
        }

        print("COMMUNITY SERVICE UPLOAD REQUEST:", url.absoluteString)

        let (responseData, response) = try await URLSession.shared.upload(
            for: request,
            fromFile: multipartFileURL
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIRequestError.badResponse
        }

        let responseText = String(data: responseData, encoding: .utf8) ?? ""

        print("COMMUNITY SERVICE UPLOAD STATUS:", httpResponse.statusCode)
        print("COMMUNITY SERVICE UPLOAD BODY:", responseText)

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw APIRequestError.serverError(
                statusCode: httpResponse.statusCode,
                text: responseText
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = readableUploadError(statusCode: httpResponse.statusCode, text: responseText) {
                throw CommunityImageError.message(message)
            }

            throw APIRequestError.serverError(
                statusCode: httpResponse.statusCode,
                text: responseText
            )
        }

        let decoded = try JSONDecoder().decode(CommunityImageUploadResponseDTO.self, from: responseData)
        return decoded.url
    }

    /// Переводит известные ответы сервера на загрузку изображения.
    private static func readableUploadError(statusCode: Int, text: String) -> String? {
        if statusCode == 413 {
            return "Файл слишком большой. Максимальный размер изображения — 8 МБ."
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = (json["detail"] as? String)?.lowercased() else {
            return nil
        }

        if detail.contains("too large") {
            return "Файл слишком большой. Максимальный размер изображения — 8 МБ."
        }

        if detail.contains("only jpeg") {
            return "Поддерживаются только изображения JPEG, PNG и WEBP."
        }

        if detail.contains("empty") {
            return "Файл пустой."
        }

        if detail.contains("no access") {
            return "Загружать изображения могут только администратор, менеджер и родители."
        }

        if detail.contains("image") {
            return "Не удалось обработать изображение. Выберите другой файл."
        }

        return nil
    }

    private static func makeMultipartUploadFileFromFile(
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