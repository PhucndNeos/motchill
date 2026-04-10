import SwiftUI

struct AppShellView: View {
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(
                repository: AppContainer.shared.repository,
                router: router
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    HomeView(repository: AppContainer.shared.repository, router: router)
                case .search:
                    SearchView()
                case .detail(let movie):
                    DetailView(
                        movie: movie,
                        repository: AppContainer.shared.repository,
                        likedMovieStore: AppContainer.shared.likedMovieStore,
                        playbackPositionStore: AppContainer.shared.playbackPositionStore,
                        router: router
                    )
                case .player(let movieID, let episodeID, let movieTitle, let episodeLabel):
                    PlayerView(
                        movieID: movieID,
                        episodeID: episodeID,
                        movieTitle: movieTitle,
                        episodeLabel: episodeLabel,
                        repository: AppContainer.shared.repository,
                        playbackPositionStore: AppContainer.shared.playbackPositionStore,
                        router: router
                    )
                }
            }
        }
    }
}
