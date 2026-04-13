import Foundation

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let configuration = AppConfiguration()
    let apiClient: PhucTvAPIClient
    let repository: PhucTvRepository
    let likedMovieStore: PhucTvLikedMovieStoring
    let playbackPositionStore: PhucTvPlaybackPositionStoring
    let screenIdleManager: ScreenIdleManaging

    private init() {
        _ = PhucTvLogger.shared
        apiClient = PhucTvAPIClient(configuration: configuration)
        repository = DefaultPhucTvRepository(apiClient: apiClient)
        likedMovieStore = UserDefaultsPhucTvLikedMovieStore()
        playbackPositionStore = UserDefaultsPhucTvPlaybackPositionStore()
        screenIdleManager = LiveScreenIdleManager()
    }
}
