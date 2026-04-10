import Foundation

enum AppRoute: Hashable {
    case home
    case search
    case detail(MotchillMovieCard)
    case player

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .detail(let movie): return movie.displayTitle
        case .player: return "Player"
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
        case .player:
            return "Direct stream playback with resume and tracks."
        }
    }
}
