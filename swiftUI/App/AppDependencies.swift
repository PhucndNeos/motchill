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
    let supabaseClient: SupabaseClient?
    let authManager: PhucTvSupabaseAuthManager
    let configuration: AppConfiguration
    let screenIdleManager: ScreenIdleManaging
    private let likedMovieStoreOverride: (any PhucTvLikedMovieStoring)?
    private let playbackPositionStoreOverride: (any PhucTvPlaybackPositionStoring)?

    init(
        repository: PhucTvRepository,
        supabaseClient: SupabaseClient?,
        authManager: PhucTvSupabaseAuthManager,
        likedMovieStoreOverride: PhucTvLikedMovieStoring? = nil,
        playbackPositionStoreOverride: PhucTvPlaybackPositionStoring? = nil,
        configuration: AppConfiguration,
        screenIdleManager: ScreenIdleManaging
    ) {
        self.repository = repository
        self.supabaseClient = supabaseClient
        self.authManager = authManager
        self.likedMovieStoreOverride = likedMovieStoreOverride
        self.playbackPositionStoreOverride = playbackPositionStoreOverride
        self.configuration = configuration
        self.screenIdleManager = screenIdleManager
    }

    static func live() -> AppDependencies {
        let configuration = AppConfiguration()
        let apiClient = PhucTvAPIClient(configuration: configuration)
        let repository = DefaultPhucTvRepository(apiClient: apiClient)
        let supabaseClient = makeSupabaseClient(configuration: configuration)

        _ = PhucTvLogger.shared

        return AppDependencies(
            repository: repository,
            supabaseClient: supabaseClient,
            authManager: PhucTvSupabaseAuthManager(client: supabaseClient),
            configuration: configuration,
            screenIdleManager: LiveScreenIdleManager()
        )
    }

    static func preview() -> AppDependencies {
        AppDependencies(
            repository: PreviewRepository(),
            supabaseClient: nil,
            authManager: PhucTvSupabaseAuthManager(client: nil),
            configuration: AppConfiguration(),
            screenIdleManager: PreviewScreenIdleManager()
        )
    }

    static func test(
        repository: PhucTvRepository = PreviewRepository(),
        authManager: PhucTvSupabaseAuthManager = PhucTvSupabaseAuthManager(client: nil),
        likedMovieStore: PhucTvLikedMovieStoring? = nil,
        playbackPositionStore: PhucTvPlaybackPositionStoring? = nil,
        supabaseClient: SupabaseClient? = nil,
        configuration: AppConfiguration = AppConfiguration(),
        screenIdleManager: ScreenIdleManaging = PreviewScreenIdleManager()
    ) -> AppDependencies {
        AppDependencies(
            repository: repository,
            supabaseClient: supabaseClient,
            authManager: authManager,
            likedMovieStoreOverride: likedMovieStore,
            playbackPositionStoreOverride: playbackPositionStore,
            configuration: configuration,
            screenIdleManager: screenIdleManager
        )
    }

    var likedMovieStore: PhucTvLikedMovieStoring {
        likedMovieStoreOverride ?? SupabaseLikedMovieStore(client: supabaseClient)
    }

    var playbackPositionStore: PhucTvPlaybackPositionStoring {
        playbackPositionStoreOverride ?? SupabasePlaybackPositionStore(client: supabaseClient)
    }
}

func makeSupabaseClient(configuration: AppConfiguration) -> SupabaseClient? {
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
