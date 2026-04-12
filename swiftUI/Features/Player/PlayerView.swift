import AVKit
import SwiftUI

struct PlayerView: View {
    @State private var viewModel: PlayerViewModel
    let router: AppRouter
    private let shouldLoadOnAppear: Bool

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        repository: MotchillRepository,
        playbackPositionStore: MotchillPlaybackPositionStoring,
        router: AppRouter
    ) {
        _viewModel = State(
            initialValue: PlayerViewModel(
                movieID: movieID,
                episodeID: episodeID,
                movieTitle: movieTitle,
                episodeLabel: episodeLabel,
                repository: repository,
                playbackPositionStore: playbackPositionStore
            )
        )
        self.router = router
        self.shouldLoadOnAppear = true
    }

    init(viewModel: PlayerViewModel, router: AppRouter) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        PlayerScreen(viewModel: viewModel, router: router)
            .task {
                guard shouldLoadOnAppear else { return }
                await viewModel.load()
            }
            .onDisappear {
                Task {
                    await viewModel.persistProgress()
                    viewModel.stop()
                }
            }
    }
}

private struct PlayerScreen: View {
    let viewModel: PlayerViewModel
    let router: AppRouter

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if viewModel.state == .loaded, let _ = viewModel.selectedSource {
                ZStack {
                    VideoPlayer(player: viewModel.player)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    PlayerOverlay(
                        viewModel: viewModel,
                        onBack: { router.pop() }
                    )
                    .opacity(viewModel.overlayVisible ? 1 : 0)
                }
            }

            switch viewModel.state {
            case .idle, .loading:
                FeatureStateOverlay(
                    descriptor: .loading(
                        title: "Đang tải player",
                        message: "Chờ một lát để nạp nguồn phát cho tập này.",
                        errorCode: "PLAYER_LOADING"
                    ),
                    onRetry: makeAsyncAction {
                        await viewModel.retry()
                    }
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
                    onRetry: makeAsyncAction {
                        await viewModel.retry()
                    },
                    onSecondary: { router.pop() }
                )
            case .loaded:
                if viewModel.selectedSource == nil {
                    FeatureStateOverlay(
                        descriptor: .empty(
                            title: "Chưa có nguồn phát",
                            message: "Không tìm thấy nguồn phát khả dụng cho tập này. Bạn có thể quay lại hoặc thử tải lại.",
                            errorCode: "PLAYER_NO_SOURCE",
                            icon: .playback,
                            secondaryTitle: "Quay lại"
                        ),
                        onRetry: makeAsyncAction {
                            await viewModel.retry()
                        },
                        onSecondary: { router.pop() }
                    )
                }
            }
        }
        .onTapGesture {
            viewModel.handleOverlayTap()
        }
        .toolbar(.hidden, for: .navigationBar)
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
