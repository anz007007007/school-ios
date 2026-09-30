import SwiftUI
import PhotosUI
import UIKit
import Darwin
import ImageIO
import SchoolAPIClient

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    @State private var isShowingChangePassword = false
    @State private var isShowingStudentAccess = false
    @State private var studentAccessResult: StudentAccessResult?

    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    @State private var isShowingAvatarPicker = false
    @State private var isUploadingAvatar = false
    @State private var profileUser: ProfileCurrentUserDTO?
    @State private var displayedAvatarURL: URL?
    @State private var avatarRefreshID = UUID()

    @State private var parentStudents: [ProfileStudentDTO] = []
    @State private var isLoadingStudents = false

    @State private var isLoadingDevices = false
    @State private var disablingDeviceID: Int?

    var body: some View {
        NavigationStack {
            List {
                if let user = appState.currentUser {
                    Section {
                        VStack(alignment: .center, spacing: 12) {
                            ProfileAvatarView(
                                avatarURL: displayedAvatarURL,
                                size: 96,
                                refreshID: avatarRefreshID
                            )
                            .allowsHitTesting(false)

                            if isUploadingAvatar {
                                ProgressView("Загрузка аватара...")
                                    .font(.footnote)
                            }

                            HStack(spacing: 16) {
                                Button {
                                    guard !isUploadingAvatar else {
                                        return
                                    }

                                    errorMessage = nil
                                    successMessage = nil
                                    isShowingAvatarPicker = true
                                } label: {
                                    Label("Изменить фото", systemImage: "camera.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(isUploadingAvatar)

                                if displayedAvatarURL != nil {
                                    Button(role: .destructive) {
                                        guard !isUploadingAvatar else {
                                            return
                                        }

                                        Task {
                                            await deleteAvatar()
                                        }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isUploadingAvatar)
                                }
                            }

                            Text(user.full_name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text(user.role_name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }

                    if let successMessage {
                        Section {
                            Label(successMessage, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)

                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Данные пользователя") {
                        LabeledContent("ID", value: "\(user.id)")
                        LabeledContent("Логин", value: user.login)
                        LabeledContent("Роль", value: user.role_name)
                        LabeledContent("Код роли", value: user.role_code)
                        LabeledContent("Активен", value: user.is_active ? "Да" : "Нет")
                    }

                    Section("Права доступа") {
                        if user.permissions.isEmpty {
                            Text("Нет прав")
                                .foregroundStyle(.secondary)
                        } else {
                            DisclosureGroup("Показать права: \(user.permissions.count)") {
                                ForEach(user.permissions, id: \.self) { permission in
                                    Text(permission)
                                        .font(.footnote)
                                }
                            }
                        }
                    }

                    Section("Безопасность") {
                        Button {
                            isShowingChangePassword = true
                        } label: {
                            Label("Сменить пароль", systemImage: "key.fill")
                        }
                    }

                    Section("Уведомления") {
                        NavigationLink {
                            NotificationsView()
                        } label: {
                            Label("Уведомления", systemImage: "bell.fill")
                        }

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("Настройки уведомлений", systemImage: "bell.badge.fill")
                        }
                    }

                    if appState.isParent {
                        Section("Доступ ребёнка") {
                            if isLoadingStudents {
                                HStack {
                                    Spacer()
                                    ProgressView("Загрузка детей...")
                                    Spacer()
                                }
                            } else if parentStudents.isEmpty {
                                Text("Связанные дети не найдены.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Button {
                                    isShowingStudentAccess = true
                                } label: {
                                    Label("Управление доступом ребёнка", systemImage: "person.badge.key.fill")
                                }

                                Text("Выберите ребёнка и задайте пароль. Если доступ ещё не создан — приложение создаст логин и пароль. Если доступ уже есть — будет обновлён пароль.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Профиль не загружен")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task {
                            async let currentUser: Void = appState.refreshCurrentUser()
                            async let profile: Void = loadProfileUser()
                            _ = await (currentUser, profile)

                            if appState.isParent {
                                await loadParentStudents()
                            }
                        }
                    } label: {
                        Label("Обновить профиль", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        Task {
                            appState.logout()
                        }
                    } label: {
                        Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: - Diagnostics Section
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppDiagnosticsInfo.displayText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        ShareLink(item: AppDiagnosticsInfo.shareText) {
                            Label("Скопировать данные для поддержки", systemImage: "square.and.arrow.up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
            .appThemedList()
            .navigationTitle("Профиль")
            .sheet(isPresented: $isShowingAvatarPicker) {
                ProfileAvatarPickerView { imageData in
                    Task {
                        await uploadAvatarData(imageData)
                    }
                }
            }
            .task {
                await loadProfileUser()

                if appState.isParent && parentStudents.isEmpty {
                    await loadParentStudents()
                }
            }
            .sheet(isPresented: $isShowingChangePassword) {
                ChangePasswordView(
                    isSaving: isSaving,
                    errorMessage: errorMessage,
                    onSave: { formData in
                        Task {
                            await changePassword(formData)
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingStudentAccess) {
                StudentAccessManagementView(
                    students: parentStudents,
                    isSaving: isSaving,
                    errorMessage: errorMessage,
                    onSave: { formData in
                        Task {
                            await saveStudentAccess(formData)
                        }
                    }
                )
            }
            .sheet(item: $studentAccessResult) { result in
                StudentAccessResultView(result: result)
            }
        }
    }

    // MARK: - Private Functions

    private func loadProfileUser() async {
        do {
            let data = try await sendRequest(
                api: appState.api,
                path: "/api/v1/auth/me",
                method: "GET"
            )

            let decodedUser = try JSONDecoder().decode(ProfileCurrentUserDTO.self, from: data)
            profileUser = decodedUser

            // Обновляем аватар только если адрес реально изменился — иначе
            // при каждом открытии профиля фото перекачивалось бы заново.
            if let resolvedAvatarURL = decodedUser.resolvedAvatarURL,
               resolvedAvatarURL != displayedAvatarURL {
                displayedAvatarURL = resolvedAvatarURL
            }
        } catch {
            print("PROFILE USER LOAD ERROR:", error.localizedDescription)
        }
    }

    private func loadParentStudents() async {
        isLoadingStudents = true
        errorMessage = nil

        do {
            let data = try await sendRequest(
                api: appState.api,
                path: "/api/v1/students",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(ProfileStudentsListResponseDTO.self, from: data)
            parentStudents = decoded.items
        } catch {
            errorMessage = "Не удалось загрузить детей: \(error.localizedDescription)"
        }

        isLoadingStudents = false
    }

    private func changePassword(_ formData: ChangePasswordFormData) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: appState.api,
                path: "/api/v1/auth/change-password",
                method: "POST",
                body: [
                    "old_password": formData.currentPassword,
                    "new_password": formData.newPassword
                ]
            )

            successMessage = "Пароль изменён"
            isShowingChangePassword = false
        } catch {
            errorMessage = "Не удалось сменить пароль: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func saveStudentAccess(_ formData: StudentAccessManagementFormData) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await createStudentAccess(formData)
            successMessage = "Доступ ребёнка создан"
            isShowingStudentAccess = false
            studentAccessResult = result
        } catch let error as ProfileError {
            switch error {
            case .serverError(_, let text):
                let lowercased = text.lowercased()

                if lowercased.contains("student already has credentials") {
                    do {
                        let result = try await resetExistingStudentPassword(formData)
                        successMessage = "Пароль ребёнка обновлён"
                        isShowingStudentAccess = false
                        studentAccessResult = result
                    } catch let resetError as ProfileError {
                        handleStudentAccessError(resetError)
                    } catch {
                        errorMessage = "Не удалось обновить пароль ребёнка: \(error.localizedDescription)"
                    }
                } else {
                    handleStudentAccessError(error)
                }

            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Не удалось сохранить доступ ребёнка: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func createStudentAccess(_ formData: StudentAccessManagementFormData) async throws -> StudentAccessResult {
        _ = try await sendRequest(
            api: appState.api,
            path: "/api/v1/students/credentials",
            method: "POST",
            body: [
                "student_id": formData.studentID,
                "login": formData.login,
                "password": formData.password
            ]
        )

        return StudentAccessResult(
            studentName: formData.studentName,
            login: formData.login,
            password: formData.password,
            actionTitle: "Доступ создан"
        )
    }

    private func resetExistingStudentPassword(_ formData: StudentAccessManagementFormData) async throws -> StudentAccessResult {
        _ = try await sendRequest(
            api: appState.api,
            path: "/api/v1/students/\(formData.studentID)/reset-password",
            method: "POST",
            body: [
                "password": formData.password
            ]
        )

        return StudentAccessResult(
            studentName: formData.studentName,
            login: formData.login,
            password: formData.password,
            actionTitle: "Пароль обновлён"
        )
    }

    private func handleStudentAccessError(_ error: ProfileError) {
        switch error {
        case .serverError(_, let text):
            let lowercased = text.lowercased()

            if lowercased.contains("only parent can reset student password") {
                errorMessage = "Сбросить пароль ребёнка может только родитель."
                return
            }

            if lowercased.contains("student is not attached to this parent") {
                errorMessage = "Этот ученик не привязан к вашему профилю."
                return
            }

            if lowercased.contains("student does not have credentials yet") {
                errorMessage = "У ребёнка ещё нет доступа. Укажите логин и пароль, приложение создаст доступ."
                return
            }

            if lowercased.contains("only parent can create student credentials") {
                errorMessage = "Создать доступ ребёнка может только родитель."
                return
            }

            errorMessage = readableProfileServerError(text)

        default:
            errorMessage = error.localizedDescription
        }
    }

    private func readableProfileServerError(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] as? String else {
            return text.isEmpty ? "Ошибка сервера. Попробуйте позже." : text
        }

        switch detail {
        case "Only parent can reset student password":
            return "Сбросить пароль ребёнка может только родитель."
        case "Student is not attached to this parent":
            return "Этот ученик не привязан к вашему профилю."
        case "Student does not have credentials yet":
            return "У ребёнка ещё нет доступа. Укажите логин и пароль, приложение создаст доступ."
        case "Only parent can create student credentials":
            return "Создать доступ ребёнка может только родитель."
        case "Student already has credentials":
            return "У ребёнка уже есть доступ. Можно обновить пароль."
        default:
            return detail
        }
    }

    private func uploadAvatarData(_ data: Data) async {
        isUploadingAvatar = true
        errorMessage = nil
        successMessage = nil

        do {
            guard data.count <= 5 * 1024 * 1024 else {
                errorMessage = "Фото слишком большое. Максимум 5 МБ."
                isUploadingAvatar = false
                return
            }

            _ = try await sendMultipartAvatar(
                api: appState.api,
                imageData: data,
                filename: "avatar.jpg",
                mimeType: "image/jpeg"
            )

            async let currentUser: Void = appState.refreshCurrentUser()
            async let profile: Void = loadProfileUser()
            _ = await (currentUser, profile)

            if let newAvatarURL = profileUser?.resolvedAvatarURL {
                displayedAvatarURL = newAvatarURL
            }

            avatarRefreshID = UUID()
            successMessage = "Аватар обновлён"
        } catch {
            errorMessage = "Не удалось загрузить аватар: \(error.localizedDescription)"
        }

        isUploadingAvatar = false
    }

    private func deleteAvatar() async {
        isUploadingAvatar = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: appState.api,
                path: "/api/v1/auth/me/avatar",
                method: "DELETE"
            )

            displayedAvatarURL = nil
            profileUser = nil

            async let currentUser: Void = appState.refreshCurrentUser()
            async let profile: Void = loadProfileUser()
            _ = await (currentUser, profile)

            displayedAvatarURL = nil
            avatarRefreshID = UUID()
            successMessage = "Аватар удалён"
        } catch {
            errorMessage = "Не удалось удалить аватар: \(error.localizedDescription)"
        }

        isUploadingAvatar = false
    }

    private func sendMultipartAvatar(
        api: SchoolAPI,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw ProfileError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru/api/v1/auth/me/avatar") else {
            throw ProfileError.badURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipartString("--\(boundary)\r\n")
        body.appendMultipartString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendMultipartString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.appendMultipartString("\r\n")
        body.appendMultipartString("--\(boundary)--\r\n")

        request.httpBody = body

        print("PROFILE AVATAR UPLOAD REQUEST:", url.absoluteString)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("PROFILE AVATAR RESPONSE STATUS:", httpResponse.statusCode)
        print("PROFILE AVATAR RESPONSE BODY:", responseText)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProfileError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw ProfileError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw ProfileError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("PROFILE REQUEST:", method, url.absoluteString)
            print("PROFILE BODY:", body)
        } else {
            print("PROFILE REQUEST:", method, url.absoluteString)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("PROFILE RESPONSE STATUS:", httpResponse.statusCode)
        print("PROFILE RESPONSE BODY:", responseText)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProfileError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }
}

// MARK: - DTO

struct ProfileCurrentUserDTO: Codable, Hashable {
    let id: Int
    let login: String
    let full_name: String
    let is_active: Bool
    let role_code: String
    let role_name: String
    let permissions: [String]
    let avatar_url: String?
    let avatar: String?
    let photo_url: String?

    var resolvedAvatarURL: URL? {
        if let url = Self.makeAvatarURL(from: avatar_url) {
            return url
        }

        if let url = Self.makeAvatarURL(from: avatar) {
            return url
        }

        if let url = Self.makeAvatarURL(from: photo_url) {
            return url
        }

        return nil
    }

    private static func makeAvatarURL(from value: String?) -> URL? {
        guard let value else {
            return nil
        }

        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            return nil
        }

        if clean.hasPrefix("http://") || clean.hasPrefix("https://") {
            return URL(string: clean)
        }

        if clean.hasPrefix("/") {
            return URL(string: "https://sc.it-status.ru\(clean)")
        }

        return URL(string: "https://sc.it-status.ru/\(clean)")
    }
}

struct ProfileStudentsListResponseDTO: Codable {
    let items: [ProfileStudentDTO]
}

struct ProfileStudentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let student_name: String?
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let class_id: Int?
    let class_name: String?
    let login: String?
    let student_login: String?
    let user_login: String?

    var displayName: String {
        if let student_name, !student_name.isEmpty {
            return student_name
        }

        let parts = [
            last_name,
            first_name,
            middle_name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        if parts.isEmpty {
            return "Ученик \(id)"
        }

        return parts.joined(separator: " ")
    }

    var displaySubtitle: String {
        class_name ?? "Класс не указан"
    }

    var resolvedLogin: String {
        if let login, !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return login
        }

        if let student_login, !student_login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return student_login
        }

        if let user_login, !user_login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return user_login
        }

        return "student\(id)"
    }
}

struct ChangePasswordFormData: Hashable {
    let currentPassword: String
    let newPassword: String
}

struct StudentAccessManagementFormData: Hashable {
    let studentID: Int
    let studentName: String
    let login: String
    let password: String
}

struct StudentAccessResult: Identifiable, Hashable {
    let id = UUID()
    let studentName: String
    let login: String
    let password: String
    let actionTitle: String

    var shareText: String {
        """
        \(actionTitle)

        Ученик: \(studentName)
        Логин: \(login)
        Пароль: \(password)
        """
    }
}

// MARK: - Avatar

struct ProfileAvatarView: View {
    let avatarURL: URL?
    let size: CGFloat
    let refreshID: UUID

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var didFail = false

    private struct LoadKey: Equatable {
        let url: URL?
        let refreshID: UUID
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: size, height: size)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if avatarURL != nil && !didFail {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                fallbackImage
            }
        }
        .task(id: LoadKey(url: avatarURL, refreshID: refreshID)) {
            await loadImage()
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 3)
        }
        .shadow(radius: 4)
    }

    private var fallbackImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.blue)
    }

    private func loadImage() async {
        guard let avatarURL else {
            image = nil
            didFail = false
            return
        }

        let pixelSize = size * displayScale

        if let cached = ProfileAvatarImageCache.shared.image(for: avatarURL, refreshID: refreshID) {
            image = cached
            didFail = false
            return
        }

        didFail = false

        do {
            let loaded = try await ProfileAvatarImageCache.shared.load(
                url: cacheBustedURL(avatarURL),
                cacheURL: avatarURL,
                refreshID: refreshID,
                maxPixelSize: pixelSize
            )

            guard !Task.isCancelled else {
                return
            }

            image = loaded
        } catch {
            guard !Task.isCancelled else {
                return
            }

            image = nil
            didFail = true
        }
    }

    private func cacheBustedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "v", value: refreshID.uuidString))
        components.queryItems = queryItems

        return components.url ?? url
    }
}

/// Кэш уже скачанных и уменьшенных до размера аватара картинок,
/// чтобы при каждом открытии профиля не качать и не декодировать фото заново.
final class ProfileAvatarImageCache: @unchecked Sendable {
    static let shared = ProfileAvatarImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 20
    }

    private func key(url: URL, refreshID: UUID) -> NSString {
        "\(url.absoluteString)#\(refreshID.uuidString)" as NSString
    }

    func image(for url: URL, refreshID: UUID) -> UIImage? {
        cache.object(forKey: key(url: url, refreshID: refreshID))
    }

    func load(url: URL, cacheURL: URL, refreshID: UUID, maxPixelSize: CGFloat) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.applyMobileClientHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ProfileError.serverError(statusCode: httpResponse.statusCode, text: "")
        }

        let image = try await Task.detached(priority: .userInitiated) {
            guard let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) else {
                throw ProfileError.badResponse
            }

            return image
        }.value

        cache.setObject(image, forKey: key(url: cacheURL, refreshID: refreshID))
        return image
    }

    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Change password

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    let isSaving: Bool
    let errorMessage: String?
    let onSave: (ChangePasswordFormData) -> Void

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatedPassword = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Смена пароля")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Введите текущий пароль и новый пароль.")
                        .foregroundStyle(.secondary)
                }

                Section("Текущий пароль") {
                    SecureField("Текущий пароль", text: $currentPassword)
                        .textContentType(.password)
                }

                Section("Новый пароль") {
                    SecureField("Новый пароль", text: $newPassword)
                        .textContentType(.newPassword)

                    SecureField("Повторите новый пароль", text: $repeatedPassword)
                        .textContentType(.newPassword)

                    Text("Минимум 6 символов.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Сохранить новый пароль")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .appThemedForm()
            .navigationTitle("Пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        let cleanCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRepeated = repeatedPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCurrent.isEmpty else {
            validationMessage = "Введите текущий пароль"
            return
        }

        guard cleanNew.count >= 6 else {
            validationMessage = "Новый пароль должен быть не короче 6 символов"
            return
        }

        guard cleanNew == cleanRepeated else {
            validationMessage = "Новый пароль и повтор не совпадают"
            return
        }

        guard cleanCurrent != cleanNew else {
            validationMessage = "Новый пароль должен отличаться от текущего"
            return
        }

        onSave(
            ChangePasswordFormData(
                currentPassword: cleanCurrent,
                newPassword: cleanNew
            )
        )
    }
}

// MARK: - Student access

struct StudentAccessManagementView: View {
    @Environment(\.dismiss) private var dismiss

    let students: [ProfileStudentDTO]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (StudentAccessManagementFormData) -> Void

    @State private var selectedStudentID = 0
    @State private var login = ""
    @State private var password = Self.generatePassword()
    @State private var repeatedPassword = ""
    @State private var validationMessage: String?

    private var selectedStudent: ProfileStudentDTO? {
        students.first { $0.id == selectedStudentID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Управление доступом ребёнка")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Выберите ребёнка и задайте пароль. Если доступа ещё нет — приложение создаст логин и пароль. Если доступ уже есть — будет обновлён пароль.")
                        .foregroundStyle(.secondary)
                }

                Section("Ребёнок") {
                    Picker("Ребёнок", selection: $selectedStudentID) {
                        Text("Выберите ребёнка").tag(0)

                        ForEach(students) { student in
                            Text(student.displayName).tag(student.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let selectedStudent {
                        Text(selectedStudent.displaySubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Логин") {
                    TextField("Логин ребёнка", text: $login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Если доступ уже создан, логин обычно менять не нужно. Если доступа нет — этот логин будет создан.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Пароль") {
                    TextField("Новый пароль", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Повторите пароль", text: $repeatedPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        password = Self.generatePassword()
                        repeatedPassword = password
                    } label: {
                        Label("Сгенерировать пароль", systemImage: "wand.and.stars")
                    }

                    Text("Минимальная длина пароля — 6 символов. После обновления старый пароль перестанет работать.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Сохранить доступ")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .appThemedForm()
            .navigationTitle("Доступ ребёнка")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupInitialState()
            }
            .onChange(of: selectedStudentID) {
                syncLoginFromSelectedStudent(force: false)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func setupInitialState() {
        if selectedStudentID == 0 {
            selectedStudentID = students.first?.id ?? 0
        }

        if repeatedPassword.isEmpty {
            repeatedPassword = password
        }

        syncLoginFromSelectedStudent(force: true)
    }

    private func syncLoginFromSelectedStudent(force: Bool) {
        guard let selectedStudent else {
            return
        }

        let currentLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)

        if force || currentLogin.isEmpty || currentLogin.hasPrefix("student") {
            login = selectedStudent.resolvedLogin
        }
    }

    private func save() {
        validationMessage = nil

        guard let selectedStudent else {
            validationMessage = "Выберите ребёнка"
            return
        }

        let cleanLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRepeatedPassword = repeatedPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanLogin.isEmpty else {
            validationMessage = "Введите логин ребёнка"
            return
        }

        guard cleanPassword.count >= 6 else {
            validationMessage = "Пароль должен быть не короче 6 символов"
            return
        }

        guard cleanPassword == cleanRepeatedPassword else {
            validationMessage = "Пароль и повтор не совпадают"
            return
        }

        onSave(
            StudentAccessManagementFormData(
                studentID: selectedStudent.id,
                studentName: selectedStudent.displayName,
                login: cleanLogin,
                password: cleanPassword
            )
        )
    }

    private static func generatePassword() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        let digits = "23456789"
        let symbols = "-_"
        let all = Array(letters + digits + symbols)

        var result = ""

        for _ in 0..<10 {
            if let char = all.randomElement() {
                result.append(char)
            }
        }

        return result
    }
}

struct StudentAccessResultView: View {
    @Environment(\.dismiss) private var dismiss

    let result: StudentAccessResult

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(result.actionTitle, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Text(result.studentName)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("Передайте эти данные ребёнку. Пароль показывается только сейчас.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                }

                Section("Данные для входа") {
                    LabeledContent("Логин", value: result.login)
                    LabeledContent("Пароль", value: result.password)
                }

                Section {
                    ShareLink(item: result.shareText) {
                        HStack {
                            Spacer()
                            Label("Поделиться доступом", systemImage: "square.and.arrow.up")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Готово")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Доступ ребёнка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Avatar picker

struct ProfileAvatarPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onImageSelected: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            dismiss: dismiss,
            onImageSelected: onImageSelected
        )
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let dismiss: DismissAction
        private let onImageSelected: (Data) -> Void

        init(
            dismiss: DismissAction,
            onImageSelected: @escaping (Data) -> Void
        ) {
            self.dismiss = dismiss
            self.onImageSelected = onImageSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()

            guard let provider = results.first?.itemProvider else {
                return
            }

            guard provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onImageSelected] object, _ in
                // Уменьшаем фото с камеры (12+ Мп) до разумного размера аватара:
                // быстрее кодируется, быстрее грузится и не упирается в лимит 5 МБ.
                guard let image = object as? UIImage,
                      let data = image.resizedForAvatar(maxDimension: 1024)
                        .jpegData(compressionQuality: 0.85) else {
                    return
                }

                DispatchQueue.main.async {
                    onImageSelected(data)
                }
            }
        }
    }
}

// MARK: - Diagnostics

private enum AppDiagnosticsInfo {
    // Считаем один раз: body профиля пересчитывается при любом изменении AppState.
    static let displayText: String = {
        "Версия \(appVersion) (\(buildNumber)) · \(deviceModel) · \(systemName) \(systemVersion)"
    }()

    static let shareText: String = {
        """
        Диагностическая информация

        Приложение: \(appName)
        Версия приложения: \(appVersion)
        Сборка: \(buildNumber)
        Устройство: \(deviceModel)
        ОС: \(systemName) \(systemVersion)
        """
    }()

    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Приложение"
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "1.0"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        ?? "1"
    }

    private static var deviceModel: String {
        let identifier = deviceIdentifier

        if identifier == "i386" || identifier == "x86_64" || identifier == "arm64" {
            return "Simulator (\(simulatorDeviceName))"
        }

        return identifier
    }

    private static var deviceIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let mirror = Mirror(reflecting: systemInfo.machine)

        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }

            result.append(String(UnicodeScalar(UInt8(value))))
        }
    }

    private static var simulatorDeviceName: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iOS Simulator"
    }

    private static var systemName: String {
        UIDevice.current.systemName
    }

    private static var systemVersion: String {
        UIDevice.current.systemVersion
    }
}

// MARK: - Helpers

private extension UIImage {
    func resizedForAvatar(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)

        guard longestSide > maxDimension else {
            return self
        }

        let ratio = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension Data {
    mutating func appendMultipartString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum ProfileError: LocalizedError {
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
            }

            return "Ошибка сервера: \(statusCode). \(text)"
        }
    }
}

private extension String {
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: self) else {
            return self
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "ru_RU")

        return displayFormatter.string(from: date)
    }
}