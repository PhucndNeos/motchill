import SwiftUI

struct AppShellView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(
                repository: dependencies.repository,
                router: router
            )
                .navigationDestination(for: AppRoute.self, destination: destinationView)
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView(
                repository: dependencies.repository,
                router: router
            )
        case .search(let routeInput):
            SearchView(
                repository: dependencies.repository,
                likedMovieStore: dependencies.likedMovieStore,
                router: router,
                routeInput: routeInput
            )
        case .detail(let movie):
            DetailView(
                movie: movie,
                repository: dependencies.repository,
                likedMovieStore: dependencies.likedMovieStore,
                playbackPositionStore: dependencies.playbackPositionStore,
                router: router
            )
        case .player(let movieID, let episodeID, let movieTitle, let episodeLabel):
            PlayerView(
                movieID: movieID,
                episodeID: episodeID,
                movieTitle: movieTitle,
                episodeLabel: episodeLabel,
                repository: dependencies.repository,
                playbackPositionStore: dependencies.playbackPositionStore,
                router: router
            )
        }
    }
}
