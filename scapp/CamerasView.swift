import SwiftUI
import AVKit
import Combine
import SchoolAPIClient

struct CamerasView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CamerasViewModel()
    @StateObject private var playerCoordinator = CameraGridPlayerCoordinator()

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
            .onDisappear {
                // Уходим с экрана «Камеры» целиком (переход назад/на другую вкладку) —
                // на всякий случай останавливаем всё, что ещё числится активным, не
                // полагаясь только на onDisappear отдельных ячеек сетки.
                playerCoordinator.stopAll()
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
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(viewModel.cameras) { camera in
                        CameraGridCell(
                            camera: camera,
                            api: appState.api,
                            coordinator: playerCoordinator
                        ) {
                            selectedCamera = camera
                        }
                    }
                }
                .padding(16)
            }
            .appScreenBackground()
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

/// Простой арбитр для сетки камер: ограничивает число одновременно активных
/// (реально стримящих) плееров в сетке, чтобы не перегружать сеть/декодер,
/// когда камер много. Полноэкранный просмотр (CameraPlayerSheet) в этот лимит
/// не считается — там всегда ровно один плеер.
@MainActor
final class CameraGridPlayerCoordinator: ObservableObject {
    static let maxActivePlayers = 8

    private var activeCameraIDs: Set<Int> = []

    /// Пытается занять слот под камеру. true — слот занят, можно стартовать плеер;
    /// false — лимит исчерпан, ячейка должна остаться статичной.
    func tryActivate(_ cameraID: Int) -> Bool {
        if activeCameraIDs.contains(cameraID) {
            return true
        }

        guard activeCameraIDs.count < Self.maxActivePlayers else {
            return false
        }

        activeCameraIDs.insert(cameraID)
        return true
    }

    func deactivate(_ cameraID: Int) {
        activeCameraIDs.remove(cameraID)
    }

    /// Вызывается при уходе со всего экрана «Камеры» — просто сбрасывает учёт;
    /// сами плееры останавливают себя в onDisappear каждой ячейки.
    func stopAll() {
        activeCameraIDs.removeAll()
    }
}

/// Лёгкая обёртка над AVPlayerLayer: в отличие от AVKit.VideoPlayer не рисует
/// системные элементы управления поверх — для мозаики из нескольких камер они
/// только мешали бы (и перехватывали тап, нужный для перехода в полноэкранный режим).
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.isUserInteractionEnabled = false
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            // swiftlint:disable:next force_cast
            layer as! AVPlayerLayer
        }
    }
}

/// Одна ячейка мозаики: карточка 16:9 с именем камеры и встроенным немым
/// плеером. Плеер создаётся лениво в .task (ячейка появилась на экране) и
/// освобождается в .onDisappear (ячейка ушла из дерева) — несколько ячеек
/// могут стримить параллельно, в отличие от прежнего «один плеер в sheet».
private struct CameraGridCell: View {
    let camera: CameraDTO
    let api: SchoolAPI
    @ObservedObject var coordinator: CameraGridPlayerCoordinator
    let onTap: () -> Void

    @State private var player: AVPlayer?
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var didRequestActivation = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)

                if let player {
                    PlayerLayerView(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else if isChecking {
                    ProgressView()
                        .tint(.white)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: camera.stream_available ? "video.fill" : "video.slash.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))

                        Text(placeholderText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10)
                }

                VStack {
                    Spacer()

                    HStack {
                        Text(camera.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(8)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!camera.stream_available)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .task {
            await activateIfNeeded()
        }
        .onDisappear {
            release()
        }
    }

    private var placeholderText: String {
        if !camera.stream_available {
            return "Скоро"
        }

        if let errorMessage {
            return errorMessage
        }

        return "Нажмите, чтобы посмотреть"
    }

    /// Ленивый запуск: срабатывает, когда ячейка впервые появилась в дереве.
    /// Сначала занимаем слот у координатора (лимит одновременных плееров),
    /// затем — тот же preflight-GET к stream.m3u8, что и раньше в sheet.
    private func activateIfNeeded() async {
        guard camera.stream_available, !didRequestActivation else {
            return
        }

        didRequestActivation = true

        guard coordinator.tryActivate(camera.id) else {
            // Лимит исчерпан — остаёмся статичной карточкой, запуск только по тапу
            // (тап откроет полноэкранный просмотр этой камеры отдельно от сетки).
            return
        }

        isChecking = true
        errorMessage = nil

        let result = await CamerasViewModel.checkStreamAvailability(api: api, cameraID: camera.id)

        guard !Task.isCancelled else {
            return
        }

        switch result {
        case .available(let url):
            guard let token = api.authToken else {
                errorMessage = "Сессия истекла. Войдите снова."
                isChecking = false
                coordinator.deactivate(camera.id)
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
            newPlayer.isMuted = true
            newPlayer.volume = 0
            player = newPlayer
            isChecking = false
            newPlayer.play()

        case .unavailable(let message):
            errorMessage = message
            isChecking = false
            coordinator.deactivate(camera.id)
        }
    }

    /// Поток оборвался уже во время показа (например, медиа-сервер упал) —
    /// показываем понятный текст в самой ячейке вместо зависшего чёрного кадра.
    private func observeFailure(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            guard item.status == .failed else {
                return
            }

            Task { @MainActor in
                errorMessage = "Видео временно недоступно."
                player = nil
                coordinator.deactivate(camera.id)
            }
        }
    }

    private func release() {
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        isChecking = false

        if didRequestActivation {
            coordinator.deactivate(camera.id)
            didRequestActivation = false
        }
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
