import Foundation
import Supabase

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let configuration = AppConfiguration()
    let apiClient: PhucTvAPIClient
    let repository: PhucTvRepository
    let authManager: PhucTvSupabaseAuthManager
    let likedMovieStore: SupabaseLikedMovieStore
    let playbackPositionStore: SupabasePlaybackPositionStore
    let localPlaybackPositionStore: UserDefaultsPhucTvPlaybackPositionStore
    let legacyDataMigrator: PhucTvLegacyLocalDataMigrating
    let screenIdleManager: ScreenIdleManaging
    let supabaseClient: SupabaseClient?

    private init() {
        _ = PhucTvLogger.shared
        apiClient = PhucTvAPIClient(configuration: configuration)
        repository = DefaultPhucTvRepository(apiClient: apiClient)
        let supabaseConfiguration = PhucTvSupabaseConfiguration(configuration: configuration)
        let redirectURL = configuration.supabaseAuthRedirectURL
        let client = supabaseConfiguration.map { configurationValue in
            SupabaseClient(
                supabaseURL: configurationValue.url,
                supabaseKey: configurationValue.publishableKey,
                options: SupabaseClientOptions(
                    auth: .init(
                        redirectToURL: redirectURL,
                        emitLocalSessionAsInitialSession: true
                    )
                )
            )
        }
        supabaseClient = client
        likedMovieStore = SupabaseLikedMovieStore(client: client)
        playbackPositionStore = SupabasePlaybackPositionStore(client: client)
        localPlaybackPositionStore = UserDefaultsPhucTvPlaybackPositionStore()
        legacyDataMigrator = PhucTvLegacyLocalDataMigrator(
            likedMovieStore: likedMovieStore,
            playbackPositionStore: playbackPositionStore
        )
        authManager = PhucTvSupabaseAuthManager(
            client: client,
            redirectURL: configuration.supabaseAuthRedirectURL,
            legacyDataMigrator: legacyDataMigrator
        )
        screenIdleManager = LiveScreenIdleManager()
    }
}
