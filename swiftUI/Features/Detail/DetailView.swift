import SwiftUI

struct DetailView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let movie: PhucTvMovieCard?
    private let initialViewModel: DetailViewModel?
    private let shouldLoadOnAppear: Bool

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
        DetailRootView(
            viewModel: resolvedViewModel,
            router: router,
            shouldLoadOnAppear: shouldLoadOnAppear
        )
    }

    private var resolvedViewModel: DetailViewModel {
        if let initialViewModel {
            return initialViewModel
        }

        guard let movie else {
            preconditionFailure("DetailView requires either a movie or an injected view model.")
        }

        return DetailViewModel(
            movie: movie,
            repository: dependencies.repository,
            likedMovieStore: dependencies.likedMovieStore,
            playbackPositionStore: dependencies.playbackPositionStore
        )
    }
}

private struct DetailRootView: View {
    let router: AppRouter

    @State private var viewModel: DetailViewModel
    @State private var shouldLoadOnAppear: Bool

    init(
        viewModel: DetailViewModel,
        router: AppRouter,
        shouldLoadOnAppear: Bool
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        _shouldLoadOnAppear = State(initialValue: shouldLoadOnAppear)
    }

    var body: some View {
        DetailScreen(viewModel: viewModel, router: router)
            .task {
                guard shouldLoadOnAppear else {
                    await viewModel.load(episodeProgressOnly: true)
                    return
                }
                await viewModel.load()
                shouldLoadOnAppear = false
            }
    }
}

#Preview("Detail") {
    DetailView(
        viewModel: DetailViewModel.previewLoaded(),
        router: AppRouter()
    )
}
