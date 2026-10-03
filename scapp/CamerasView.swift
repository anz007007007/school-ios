import SwiftUI
import AVKit
import SchoolAPIClient

struct CamerasView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CamerasViewModel()

    @State private var selectedCamera: CameraDTO?

    var body: some View {
        content
            .navigationTitle("Камеры")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.loadCameras(api: appState.api)
            }
            .task {
                guard !viewModel.hasLoaded else {
                    return
                }

                await viewModel.loadCameras(api: appState.api)
            }
            .sheet(item: $selectedCamera) { camera in
                CameraPlayerSheet(camera: camera, api: appState.api)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasLoaded {
            ProgressView("Загружаем камеры...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage, viewModel.cameras.isEmpty {
            errorView(errorMessage)
        } else if viewModel.cameras.isEmpty {
            ContentUnavailableView(
                "Камеры не найдены",
                systemImage: "video.slash.fill",
                description: Text("Вам пока не назначены камеры видеонаблюдения.")
            )
        } else if viewModel.shouldShowComingSoonBanner {
            comingSoonBanner
        } else {
            List {
                Section("Камеры") {
                    ForEach(viewModel.cameras) { camera in
                        CameraRowView(camera: camera) {
                            selectedCamera = camera
                        }
                    }
                }
            }
            .appThemedList()
        }
    }

    private var comingSoonBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.badge.waveform")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.control)

            Text("Видеонаблюдение скоро заработает")
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Text("Камеры уже подключены, но медиа-сервер пока не настроен. Трансляция появится здесь автоматически, как только это сделают.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.danger)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Повторить") {
                Task {
                    await viewModel.loadCameras(api: appState.api)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.control)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}

private struct CameraRowView: View {
    let camera: CameraDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill((camera.stream_available ? AppTheme.control : AppTheme.muted).opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: camera.stream_available ? "video.fill" : "video.slash.fill")
                        .font(.title3)
                        .foregroundStyle(camera.stream_available ? AppTheme.control : AppTheme.muted)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Text(camera.stream_available ? "Нажмите, чтобы посмотреть" : "Видео временно недоступно")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                if camera.stream_available {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!camera.stream_available)
    }
}

/// Полноэкранный плеер: сначала простой GET к stream.m3u8 (понятная ошибка вместо
/// «вечной загрузки», если медиа-сервер недоступен или камера скрыта), и только
/// после успеха — AVPlayer с Bearer-токеном в заголовках HLS-запросов.
private struct CameraPlayerSheet: View {
    let camera: CameraDTO
    let api: SchoolAPI

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isChecking = true
    @State private var errorMessage: String?
    @State private var statusObservation: NSKeyValueObservation?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else if isChecking {
                    ProgressView("Подключаемся к камере...")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if let errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)

                        Text(errorMessage)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("Повторить") {
                            Task {
                                await load()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
            .navigationTitle(camera.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await load()
            }
            .onDisappear {
                statusObservation?.invalidate()
                player?.pause()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func load() async {
        isChecking = true
        errorMessage = nil
        statusObservation?.invalidate()
        player = nil

        let result = await CamerasViewModel.checkStreamAvailability(api: api, cameraID: camera.id)

        switch result {
        case .available(let url):
            guard let token = api.authToken else {
                errorMessage = "Сессия истекла. Войдите снова."
                isChecking = false
                return
            }

            var headers = MobileClientInfo.headers
            headers["Authorization"] = "Bearer \(token)"

            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers
            ])
            let item = AVPlayerItem(asset: asset)
            observeFailure(of: item)

            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            isChecking = false
            newPlayer.play()

        case .unavailable(let message):
            errorMessage = message
            isChecking = false
        }
    }

    /// Если поток оборвался уже после старта (например, медиа-сервер упал во время
    /// просмотра) — показываем тот же понятный текст вместо зависшего чёрного экрана.
    private func observeFailure(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            guard item.status == .failed else {
                return
            }

            Task { @MainActor in
                errorMessage = "Видео временно недоступно."
                player = nil
            }
        }
    }
}
