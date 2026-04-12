import Foundation

enum AppRoute: Hashable {
    case home
    case search(SearchRouteInput = SearchRouteInput())
    case detail(MotchillMovieCard)
    case player(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String
    )

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .detail(let movie): return movie.displayTitle
        case .player(let movieID, _, _, _): return "Player #\(movieID)"
        }
    }

    var subtitle: String {
        switch self {
        case .home:
            return "Phase 0 shell entry point and future landing route."
        case .search:
            return "Shared route for search and category presets."
        case .detail(let movie):
            return movie.displaySubtitle
        case .player(_, _, let movieTitle, let episodeLabel):
            return [movieTitle, episodeLabel]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " • ")
        }
    }
}
