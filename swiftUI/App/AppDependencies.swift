import Foundation
import Supabase
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

    static func live() -> AppDependencies {
        let configuration = AppConfiguration()
        let apiClient = PhucTvAPIClient(configuration: configuration)
        let repository = DefaultPhucTvRepository(apiClient: apiClient)
        let client = makeSupabaseClient(configuration: configuration)
        let likedMovieStore = SupabaseLikedMovieStore(client: client)
        let playbackPositionStore = SupabasePlaybackPositionStore(client: client)
        let localPlaybackPositionStore = UserDefaultsPhucTvPlaybackPositionStore()
        let legacyDataMigrator = PhucTvLegacyLocalDataMigrator(
            likedMovieStore: likedMovieStore,
            playbackPositionStore: playbackPositionStore
        )

        _ = PhucTvLogger.shared

        return AppDependencies(
            repository: repository,
            authManager: PhucTvSupabaseAuthManager(
                client: client,
                redirectURL: configuration.supabaseAuthRedirectURL,
                legacyDataMigrator: legacyDataMigrator
            ),
            likedMovieStore: likedMovieStore,
            playbackPositionStore: playbackPositionStore,
            localPlaybackPositionStore: localPlaybackPositionStore,
            configuration: configuration,
            screenIdleManager: LiveScreenIdleManager()
        )
    }

    static func preview() -> AppDependencies {
        AppDependencies(
            repository: PreviewRepository(),
            authManager: PhucTvSupabaseAuthManager(client: nil),
            likedMovieStore: PreviewLikedMovieStore(),
            playbackPositionStore: PreviewPlaybackPositionStore(),
            localPlaybackPositionStore: PreviewPlaybackPositionStore(),
            configuration: AppConfiguration(),
            screenIdleManager: PreviewScreenIdleManager()
        )
    }

    static func test(
        repository: PhucTvRepository = PreviewRepository(),
        authManager: PhucTvSupabaseAuthManager = PhucTvSupabaseAuthManager(client: nil),
        likedMovieStore: PhucTvLikedMovieStoring = PreviewLikedMovieStore(),
        playbackPositionStore: PhucTvPlaybackPositionStoring = PreviewPlaybackPositionStore(),
        localPlaybackPositionStore: PhucTvPlaybackPositionStoring = PreviewPlaybackPositionStore(),
        configuration: AppConfiguration = AppConfiguration(),
        screenIdleManager: ScreenIdleManaging = PreviewScreenIdleManager()
    ) -> AppDependencies {
        AppDependencies(
            repository: repository,
            authManager: authManager,
            likedMovieStore: likedMovieStore,
            playbackPositionStore: playbackPositionStore,
            localPlaybackPositionStore: localPlaybackPositionStore,
            configuration: configuration,
            screenIdleManager: screenIdleManager
        )
    }

    private static func makeSupabaseClient(configuration: AppConfiguration) -> SupabaseClient? {
        guard let supabaseConfiguration = PhucTvSupabaseConfiguration(configuration: configuration) else {
            return nil
        }

        return SupabaseClient(
            supabaseURL: supabaseConfiguration.url,
            supabaseKey: supabaseConfiguration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: configuration.supabaseAuthRedirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.preview()
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
