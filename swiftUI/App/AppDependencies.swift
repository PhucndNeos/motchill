import SwiftUI

protocol ScreenIdleManaging: Sendable {
    func disableAutoLock()
    func enableAutoLock()
    func reset()
}

struct AppDependencies: Sendable {
    let repository: PhucTvRepository
    let authManager: PhucTvSupabaseAuthManager
    let likedMovieStore: PhucTvLikedMovieStoring
    /// Remote Supabase store — source of truth for cross-device sync.
    let playbackPositionStore: PhucTvPlaybackPositionStoring
    /// Local UserDefaults store — used by the player for fast periodic writes.
    let localPlaybackPositionStore: PhucTvPlaybackPositionStoring
    let configuration: AppConfiguration
    let screenIdleManager: ScreenIdleManaging

    @MainActor
    init(container: AppContainer) {
        repository = container.repository
        authManager = container.authManager
        likedMovieStore = container.likedMovieStore
        playbackPositionStore = container.playbackPositionStore
        localPlaybackPositionStore = container.localPlaybackPositionStore
        configuration = container.configuration
        screenIdleManager = container.screenIdleManager
    }

    init(
        repository: PhucTvRepository,
        authManager: PhucTvSupabaseAuthManager,
        likedMovieStore: PhucTvLikedMovieStoring,
        playbackPositionStore: PhucTvPlaybackPositionStoring,
        localPlaybackPositionStore: PhucTvPlaybackPositionStoring,
        configuration: AppConfiguration,
        screenIdleManager: ScreenIdleManaging
    ) {
        self.repository = repository
        self.authManager = authManager
        self.likedMovieStore = likedMovieStore
        self.playbackPositionStore = playbackPositionStore
        self.localPlaybackPositionStore = localPlaybackPositionStore
        self.configuration = configuration
        self.screenIdleManager = screenIdleManager
    }

    static let preview = AppDependencies(
        repository: PreviewRepository(),
        authManager: PhucTvSupabaseAuthManager(client: nil),
        likedMovieStore: PreviewLikedMovieStore(),
        playbackPositionStore: PreviewPlaybackPositionStore(),
        localPlaybackPositionStore: PreviewPlaybackPositionStore(),
        configuration: AppConfiguration(),
        screenIdleManager: PreviewScreenIdleManager()
    )
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.preview
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

private struct PreviewRepository: PhucTvRepository {
    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { throw PreviewDependencyError.unimplemented }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { throw PreviewDependencyError.unimplemented }
    func loadSearchFilters() async throws -> PhucTvSearchFilterData { .init(categories: [], countries: []) }

    func loadSearchResults(
        categoryId: Int?,
        countryId: Int?,
        typeRaw: String,
        year: String,
        orderBy: String,
        isChieuRap: Bool,
        is4k: Bool,
        search: String,
        pageNumber: Int
    ) async throws -> PhucTvSearchResults {
        .init(records: [], pagination: .init(pageIndex: 1, pageSize: 20, pageCount: 1, totalRecords: 0))
    }

    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [PhucTvPlaySource] {
        []
    }

    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private actor PreviewLikedMovieStore: PhucTvLikedMovieStoring {
    func loadMovies() async throws -> [PhucTvMovieCard] { [] }
    func loadIDs() async throws -> Set<Int> { [] }
    func isLiked(movieID: Int) async throws -> Bool { false }
    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] { [movie] }
}

private actor PreviewPlaybackPositionStore: PhucTvPlaybackPositionStoring {
    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {}

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        nil
    }
}

private struct PreviewScreenIdleManager: ScreenIdleManaging {
    func disableAutoLock() {}
    func enableAutoLock() {}
    func reset() {}
}

struct LiveScreenIdleManager: ScreenIdleManaging {
    func disableAutoLock() {
        MainActor.assumeIsolated {
            ScreenIdeManager.shared.disableAutoLock()
        }
    }

    func enableAutoLock() {
        MainActor.assumeIsolated {
            ScreenIdeManager.shared.enableAutoLock()
        }
    }

    func reset() {
        MainActor.assumeIsolated {
            ScreenIdeManager.shared.reset()
        }
    }
}

private enum PreviewDependencyError: Error {
    case unimplemented
}
