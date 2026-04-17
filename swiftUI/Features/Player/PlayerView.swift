import AVKit
import SwiftUI

struct PlayerView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let playerInput: PlayerInput?
    private let initialViewModel: PlayerViewModel?
    private let shouldLoadOnAppear: Bool

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        router: AppRouter
    ) {
        self.router = router
        self.playerInput = PlayerInput(
            movieID: movieID,
            episodeID: episodeID,
            movieTitle: movieTitle,
            episodeLabel: episodeLabel
        )
        self.initialViewModel = nil
        self.shouldLoadOnAppear = true
    }

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        repository: PhucTvRepository,
        localPlaybackPositionStore: PhucTvPlaybackPositionStoring,
        remotePlaybackPositionStore: PhucTvPlaybackPositionStoring,
        router: AppRouter
    ) {
        self.router = router
        self.playerInput = PlayerInput(
            movieID: movieID,
            episodeID: episodeID,
            movieTitle: movieTitle,
            episodeLabel: episodeLabel
        )
        self.initialViewModel = PlayerViewModel(
            movieID: movieID,
            episodeID: episodeID,
            movieTitle: movieTitle,
            episodeLabel: episodeLabel,
            repository: repository,
            localStore: localPlaybackPositionStore,
            remoteStore: remotePlaybackPositionStore
        )
        self.shouldLoadOnAppear = true
    }

    init(viewModel: PlayerViewModel, router: AppRouter) {
        self.router = router
        self.playerInput = nil
        self.initialViewModel = viewModel
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        PlayerRootView(
            viewModel: resolvedViewModel,
            router: router,
            shouldLoadOnAppear: shouldLoadOnAppear
        )
    }

    private var resolvedViewModel: PlayerViewModel {
        if let initialViewModel {
            return initialViewModel
        }

        guard let playerInput else {
            preconditionFailure("PlayerView requires either playback input or an injected view model.")
        }

        return PlayerViewModel(
            movieID: playerInput.movieID,
            episodeID: playerInput.episodeID,
            movieTitle: playerInput.movieTitle,
            episodeLabel: playerInput.episodeLabel,
            repository: dependencies.repository,
            localStore: dependencies.localPlaybackPositionStore,
            remoteStore: dependencies.playbackPositionStore
        )
    }
}

private struct PlayerInput {
    let movieID: Int
    let episodeID: Int
    let movieTitle: String
    let episodeLabel: String
}

private struct PlayerRootView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    @State private var viewModel: PlayerViewModel
    @State private var shouldLoadOnAppear: Bool

    init(
        viewModel: PlayerViewModel,
        router: AppRouter,
        shouldLoadOnAppear: Bool
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        _shouldLoadOnAppear = State(initialValue: shouldLoadOnAppear)
    }

    var body: some View {
        PlayerScreen(viewModel: viewModel, router: router)
            .task {
                await loadIfNeeded()
            }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
    }

    private func loadIfNeeded() async {
        guard shouldLoadOnAppear else { return }
        await viewModel.load()
        shouldLoadOnAppear = false
    }

    private func handleAppear() {
        dependencies.screenIdleManager.disableAutoLock()
    }

    private func handleDisappear() {
        dependencies.screenIdleManager.enableAutoLock()
        Task {
            await viewModel.persistProgress()
            viewModel.stop()
        }
    }
}

private struct PlayerScreen: View {
    let viewModel: PlayerViewModel
    let router: AppRouter

    @State private var webDestination: PlayerWebDestination?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                playerContent
                playerStateOverlay
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        handleSeekGesture(at: value.location.x, width: proxy.size.width)
                    }
            )
            .onTapGesture {
                viewModel.handleOverlayTap()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $webDestination) { destination in
            NavigationStack {
                PlayerWebViewScreen(destination: destination)
            }
        }
    }

    @ViewBuilder
    private var playerContent: some View {
        if viewModel.state == .loaded, viewModel.selectedSource != nil {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: viewModel.player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                PlayerSubtitleOverlay(text: viewModel.currentSubtitleText)
                PlayerOverlay(
                    viewModel: viewModel,
                    onBack: { router.pop() }
                )
                .opacity(viewModel.overlayVisible ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private var playerStateOverlay: some View {
        switch viewModel.state {
        case .idle, .loading:
            FeatureStateOverlay(
                descriptor: .loading(
                    title: "Đang tải player",
                    message: "Chờ một lát để nạp nguồn phát cho tập này.",
                    errorCode: "PLAYER_LOADING"
                ),
                onRetry: retry
            )
        case .error(let message):
            FeatureStateOverlay(
                descriptor: .failure(
                    title: "Không thể mở player",
                    message: message,
                    errorCode: "PLAYER_LOAD_FAIL",
                    icon: .playback,
                    secondaryTitle: "Quay lại"
                ),
                actionButtons: iframeActionButtons,
                onRetry: retry,
                onSecondary: closePlayer
            )
        case .loaded:
            if viewModel.selectedSource == nil {
                if viewModel.hasIframeOnlySources {
                    FeatureStateOverlay(
                        descriptor: .failure(
                            title: "Không có nguồn phát trực tiếp",
                            message: "Nguồn này chỉ có iframe. Chọn một nguồn bên dưới để mở trong WebView.",
                            errorCode: "PLAYER_IFRAME_ONLY",
                            icon: .playback,
                            secondaryTitle: "Quay lại"
                        ),
                        actionButtons: iframeActionButtons,
                        onRetry: retry,
                        onSecondary: closePlayer
                    )
                } else {
                    FeatureStateOverlay(
                        descriptor: .empty(
                            title: "Chưa có nguồn phát",
                            message: "Không tìm thấy nguồn phát khả dụng cho tập này. Bạn có thể quay lại hoặc thử tải lại.",
                            errorCode: "PLAYER_NO_SOURCE",
                            icon: .playback,
                            secondaryTitle: "Quay lại"
                        ),
                        onRetry: retry,
                        onSecondary: closePlayer
                    )
                }
            }
        }
    }

    private var iframeActionButtons: [ErrorOverlay.ActionButton] {
        viewModel.iframeSources.compactMap { source in
            guard let url = normalizedPlayerURL(from: source.link) else { return nil }

            return ErrorOverlay.ActionButton(title: source.actionButtonTitle) {
                webDestination = PlayerWebDestination(
                    title: source.actionButtonTitle,
                    url: url
                )
            }
        }
    }

    private func retry() {
        makeAsyncAction {
            await viewModel.retry()
        }()
    }

    private func closePlayer() {
        router.pop()
    }

    private func handleSeekGesture(at positionX: CGFloat, width: CGFloat) {
        guard width > 0 else { return }

        if positionX < width / 3 {
            viewModel.seek(by: -viewModel.seekStepMillis)
        } else if positionX > width * 0.75 {
            viewModel.seek(by: viewModel.seekStepMillis)
        }
    }
}

private struct PlayerWebDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private func normalizedPlayerURL(from rawValue: String) -> URL? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let directURL = URL(string: trimmed), let scheme = directURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
        return directURL
    }

    if trimmed.hasPrefix("//"), let protocolRelativeURL = URL(string: "https:\(trimmed)") {
        return protocolRelativeURL
    }

    if let inferredURL = URL(string: "https://\(trimmed)") {
        return inferredURL
    }

    return nil
}

private struct PlayerWebViewScreen: View {
    let destination: PlayerWebDestination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlayerWebView(url: destination.url)
            .ignoresSafeArea()
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
    }
}

#Preview("Player") {
    NavigationStack {
        PlayerView(
            viewModel: PlayerViewModel.previewLoaded(),
            router: AppRouter()
        )
    }
}

#Preview("Player iframe only") {
    NavigationStack {
        PlayerView(
            viewModel: PlayerViewModel.previewIframeOnlyError(),
            router: AppRouter()
        )
    }
}
