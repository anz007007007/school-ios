import Foundation
import ImageIO
import UniformTypeIdentifiers
import SchoolAPIClient

enum CommunityImageUploadService {
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
            throw APIRequestError.networkError("Файл пустой.")
        }

        guard picked.fileSize <= 25 * 1024 * 1024 else {
            throw APIRequestError.networkError("Файл слишком большой. Максимум 25 МБ до сжатия.")
        }

        let uploadSource: PreparedUploadFile

        if picked.fileSize <= 8 * 1024 * 1024 {
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
            throw APIRequestError.serverError(
                statusCode: httpResponse.statusCode,
                text: responseText
            )
        }

        let decoded = try JSONDecoder().decode(CommunityImageUploadResponseDTO.self, from: responseData)
        return decoded.url
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