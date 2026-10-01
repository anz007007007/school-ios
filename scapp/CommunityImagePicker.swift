import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

final class CommunityPickedImage: NSObject {
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let fileSize: Int

    init(
        fileURL: URL,
        fileName: String,
        mimeType: String,
        fileSize: Int
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSize = fileSize
    }
}

enum CommunityImagePickerError: LocalizedError {
    case noImage
    case unsupportedType
    case fileTooLarge
    case emptyFile
    case cannotReadFile

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "Изображение не выбрано."
        case .unsupportedType:
            return "Поддерживаются только JPEG, PNG и WEBP."
        case .fileTooLarge:
            return "Файл слишком большой (больше 25 МБ). Выберите изображение поменьше: после сжатия оно должно быть не больше 8 МБ."
        case .emptyFile:
            return "Файл пустой или недоступен."
        case .cannotReadFile:
            return "Не удалось прочитать файл."
        }
    }
}

enum CommunityImageReader {
    static let maxInputSize = 25 * 1024 * 1024

    static func makePickedImage(from sourceURL: URL) throws -> CommunityPickedImage {
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let detectedMimeType = mimeType(for: sourceURL)

        guard isSupportedMimeType(detectedMimeType) else {
            throw CommunityImagePickerError.unsupportedType
        }

        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])

        guard let fileSize = values.fileSize, fileSize > 0 else {
            throw CommunityImagePickerError.emptyFile
        }

        guard fileSize <= maxInputSize else {
            throw CommunityImagePickerError.fileTooLarge
        }

        let copiedURL = try copyToTemporaryFile(
            sourceURL: sourceURL,
            mimeType: detectedMimeType
        )

        return CommunityPickedImage(
            fileURL: copiedURL,
            fileName: copiedURL.lastPathComponent,
            mimeType: detectedMimeType,
            fileSize: fileSize
        )
    }

    static func makePickedImageFromPhotoTempURL(_ sourceURL: URL) throws -> CommunityPickedImage {
        let copiedURL = try copyToTemporaryFile(
            sourceURL: sourceURL,
            mimeType: "image/jpeg"
        )

        let values = try copiedURL.resourceValues(forKeys: [.fileSizeKey])

        guard let fileSize = values.fileSize, fileSize > 0 else {
            throw CommunityImagePickerError.emptyFile
        }

        guard fileSize <= maxInputSize else {
            throw CommunityImagePickerError.fileTooLarge
        }

        return CommunityPickedImage(
            fileURL: copiedURL,
            fileName: copiedURL.lastPathComponent,
            mimeType: "image/jpeg",
            fileSize: fileSize
        )
    }

    static func copyToTemporaryFile(sourceURL: URL, mimeType: String) throws -> URL {
        let fileExtension: String

        switch mimeType {
        case "image/png":
            fileExtension = "png"
        case "image/webp":
            fileExtension = "webp"
        default:
            fileExtension = "jpg"
        }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-picked-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "heic", "heif":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }

    static func isSupportedMimeType(_ mimeType: String) -> Bool {
        mimeType == "image/jpeg" || mimeType == "image/png" || mimeType == "image/webp"
    }
}

struct CommunityPhotoPickerView: UIViewControllerRepresentable {
    let onPicked: (Result<CommunityPickedImage, Error>) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: (Result<CommunityPickedImage, Error>) -> Void

        init(onPicked: @escaping (Result<CommunityPickedImage, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else {
                onPicked(.failure(CommunityImagePickerError.noImage))
                return
            }

            let typeIdentifier: String

            if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
                typeIdentifier = UTType.jpeg.identifier
            } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                typeIdentifier = UTType.png.identifier
            } else if provider.hasItemConformingToTypeIdentifier(UTType.webP.identifier) {
                typeIdentifier = UTType.webP.identifier
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                typeIdentifier = UTType.image.identifier
            } else {
                onPicked(.failure(CommunityImagePickerError.unsupportedType))
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    DispatchQueue.main.async {
                        self.onPicked(.failure(error))
                    }
                    return
                }

                guard let url else {
                    DispatchQueue.main.async {
                        self.onPicked(.failure(CommunityImagePickerError.cannotReadFile))
                    }
                    return
                }

                do {
                    let picked = try CommunityImageReader.makePickedImageFromPhotoTempURL(url)

                    DispatchQueue.main.async {
                        self.onPicked(.success(picked))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.onPicked(.failure(error))
                    }
                }
            }
        }
    }
}

struct CommunityDocumentImagePickerView: UIViewControllerRepresentable {
    let onPicked: (Result<CommunityPickedImage, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .jpeg,
                .png,
                .webP
            ],
            asCopy: true
        )

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPicked: (Result<CommunityPickedImage, Error>) -> Void

        init(onPicked: @escaping (Result<CommunityPickedImage, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onPicked(.failure(CommunityImagePickerError.noImage))
                return
            }

            do {
                let picked = try CommunityImageReader.makePickedImage(from: url)
                onPicked(.success(picked))
            } catch {
                onPicked(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}