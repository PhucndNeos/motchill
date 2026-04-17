import SwiftUI

struct DetailView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let movie: PhucTvMovieCard?
    private let initialViewModel: DetailViewModel?
    private let shouldLoadOnAppear: Bool
    @State private var viewModel: DetailViewModel?

    init(
        movie: PhucTvMovieCard,
        router: AppRouter
    ) {
        self.router = router
        self.movie = movie
        self.initialViewModel = nil
        self.shouldLoadOnAppear = true
    }

    init(
        movie: PhucTvMovieCard,
        repository: PhucTvRepository,
        likedMovieStore: PhucTvLikedMovieStoring,
        playbackPositionStore: PhucTvPlaybackPositionStoring,
        router: AppRouter
    ) {
        self.router = router
        self.movie = movie
        self.initialViewModel = DetailViewModel(
            movie: movie,
            repository: repository,
            likedMovieStore: likedMovieStore,
            playbackPositionStore: playbackPositionStore
        )
        self.shouldLoadOnAppear = true
    }

    init(viewModel: DetailViewModel, router: AppRouter) {
        self.router = router
        self.movie = nil
        self.initialViewModel = viewModel
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        Group {
            if let viewModel {
                detailContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await bootstrapIfNeeded()
        }
    }

    @ViewBuilder
    private func detailContent(viewModel: DetailViewModel) -> some View {
        ZStack {
            if viewModel.state != .loaded || !viewModel.hasRenderableContent {
                DetailBackground()
                    .ignoresSafeArea()
            }

            loadedContent(viewModel: viewModel)
            stateOverlay(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleLike) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.isLiked ? Color.red.opacity(0.95) : AppTheme.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            (viewModel.isLiked ? Color.red.opacity(0.18) : Color.white.opacity(0.06)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: viewModel.movie.id) {
            guard viewModel.state == .idle else {
                if !shouldLoadOnAppear {
                    await viewModel.loadEpisodeProgress()
                }
                return
            }

            if shouldLoadOnAppear {
                await viewModel.load()
            } else {
                await viewModel.loadEpisodeProgress()
            }
        }
    }

    @ViewBuilder
    private func loadedContent(viewModel: DetailViewModel) -> some View {
        if viewModel.state == .loaded, viewModel.hasRenderableContent {
            DetailsIpadScreen(
                viewModel: viewModel,
                router: router,
                onToggleLike: toggleLike,
                onOpenTrailer: openTrailer,
                onOpenEpisode: openEpisode
            )
        }
    }

    @ViewBuilder
    private func stateOverlay(viewModel: DetailViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            FeatureStateOverlay(
                descriptor: .loading(
                    title: "Đang tải nội dung",
                    message: "Chờ một lát để nạp thông tin chi tiết của phim.",
                    errorCode: "DETAIL_LOADING"
                ),
                onRetry: retry
            )
        case .error(let message):
            FeatureStateOverlay(
                descriptor: .failure(
                    title: "Không thể tải chi tiết",
                    message: message,
                    errorCode: "DETAIL_LOAD_FAIL",
                    icon: .server,
                    secondaryTitle: "Quay lại"
                ),
                onRetry: retry,
                onSecondary: closeDetail
            )
        case .loaded:
            if !viewModel.hasRenderableContent {
                FeatureStateOverlay(
                    descriptor: .empty(
                        title: "Chưa có nội dung",
                        message: "Trang chi tiết hiện chưa có section nào để hiển thị. Bạn có thể thử quay lại hoặc tìm kiếm nội dung khác.",
                        errorCode: "DETAIL_EMPTY",
                        secondaryTitle: "Tìm kiếm"
                    ),
                    onRetry: retry,
                    onSecondary: openSearch
                )
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() async {
        guard viewModel == nil else {
            return
        }

        let resolvedViewModel: DetailViewModel
        if let initialViewModel {
            resolvedViewModel = initialViewModel
        } else {
            guard let movie else {
                preconditionFailure("DetailView requires either a movie or an injected view model.")
            }

            resolvedViewModel = DetailViewModel(
                movie: movie,
                repository: dependencies.repository,
                likedMovieStore: dependencies.likedMovieStore,
                playbackPositionStore: dependencies.playbackPositionStore
            )
        }

        viewModel = resolvedViewModel
    }
    
    private func retry() {
        guard let viewModel else { return }
        makeAsyncAction { await viewModel.retry() }()
    }

    private func toggleLike() {
        guard let viewModel else { return }
        Task { await viewModel.toggleLike() }
    }

    private func closeDetail() {
        router.pop()
    }

    private func openSearch() {
        router.push(.search())
    }

    private func openTrailer() {
        openExternalURL(viewModel?.trailerURL())
    }

    private func openEpisode(_ episode: PhucTvMovieEpisode) {
        guard let viewModel else { return }
        router.push(
            .player(
                movieID: viewModel.detail?.id ?? viewModel.movie.id,
                episodeID: episode.id,
                movieTitle: viewModel.title,
                episodeLabel: episode.label
            )
        )
    }
}

private struct DetailBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.10, blue: 0.18).opacity(0.85),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )
        }
    }
}
