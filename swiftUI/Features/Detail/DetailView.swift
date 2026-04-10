import SwiftUI

struct DetailView: View {
    @State private var viewModel: DetailViewModel
    let router: AppRouter
    private let shouldLoadOnAppear: Bool

    init(
        movie: MotchillMovieCard,
        repository: MotchillRepository,
        likedMovieStore: MotchillLikedMovieStoring,
        playbackPositionStore: MotchillPlaybackPositionStoring,
        router: AppRouter
    ) {
        _viewModel = State(
            initialValue: DetailViewModel(
                movie: movie,
                repository: repository,
                likedMovieStore: likedMovieStore,
                playbackPositionStore: playbackPositionStore
            )
        )
        self.router = router
        self.shouldLoadOnAppear = true
    }

    init(viewModel: DetailViewModel, router: AppRouter) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        DetailScreen(viewModel: viewModel, router: router)
            .task {
                guard shouldLoadOnAppear else { return }
                await viewModel.load()
            }
    }
}

#Preview("Detail") {
    DetailView(
        viewModel: DetailViewModel.previewLoaded(),
        router: AppRouter()
    )
}
