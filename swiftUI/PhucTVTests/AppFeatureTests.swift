import ComposableArchitecture
import Foundation
import Testing

@testable import PhucTV

@MainActor
struct AppFeatureTests {
    init() {
        uncheckedUseMainSerialExecutor = true
    }

    @Test
    func launchRefreshesAuthBanner() async {
        let authState = AuthStateBox(
            authenticated: false,
            summary: PhucTvSupabaseUserSummary(
                id: UUID(),
                email: "user@example.com",
                displayName: nil
            )
        )
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.phucTvAuthManager = PhucTvAuthManagerClient(
                isAuthenticated: { authState.authenticated },
                userSummary: { authState.authenticated ? authState.summary : nil },
                signInHint: { authState.authenticated ? nil : "Đăng nhập để đồng bộ liked movies và playback position." },
                sendOTP: { _ in },
                verifyOTP: { _, _ in },
                refreshSessionState: {
                    authState.authenticated = true
                },
                signOut: {
                    authState.authenticated = false
                },
                handle: { _ in }
            )
        }

        #expect(store.state.home.status == .loading)
        #expect(store.state.path.isEmpty)
        #expect(store.state.authBanner == nil)

        await store.send(.task)
        await store.receive(.authSnapshotRefreshed) {
            $0.authBanner = AppFeature.AuthBannerState(
                message: "Đang đăng nhập với user@example.com.",
                buttonTitle: "Đăng xuất",
                isSignedIn: true
            )
        }
    }

    @Test
    func pushSearchRoute() async {
        let store = makeStore()

        await store.send(.home(.searchTapped)) {
            $0.path.append(.search(SearchFeature.State()))
        }
    }

    @Test
    func pushDetailFromSearchRoute() async {
        let store = makeStore()
        let movie = placeholderMovie()

        await store.send(.home(.searchTapped)) {
            $0.path.append(.search(SearchFeature.State()))
        }

        let id = store.state.path.ids.first!

        await store.send(.path(.element(id: id, action: .search(.detailTapped(movie: movie))))) {
            $0.path.append(.detail(DetailFeature.State(movie: movie)))
        }
    }

    @Test
    func pushDetailRoute() async {
        let store = makeStore()
        let movie = placeholderMovie()

        await store.send(.home(.detailTapped(movie: movie))) {
            $0.path.append(
                .detail(
                    DetailFeature.State(movie: movie)
                )
            )
        }

        guard case let .detail(detailState)? = store.state.path.first else {
            Issue.record("Expected a detail route to be pushed.")
            return
        }

        #expect(detailState.movie.id == movie.id)
    }

    @Test
    func detailPlayEpisodePushesPlayerRoute() async {
        let movie = DetailMockData.movie
        let episode = DetailMockData.detail.episodes[0]

        var detailState = DetailFeature.State(movie: movie)
        detailState.detail = DetailMockData.detail
        detailState.screenState = .loaded
        detailState.selectedTab = .episodes
        detailState.isLiked = true
        detailState.episodeProgressById = [
            episode.id: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
        ]

        let store = TestStore(initialState: {
            var state = AppFeature.State()
            state.path.append(.detail(detailState))
            return state
        }()) {
            AppFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test(authManager: PhucTvSupabaseAuthManager(client: nil)))
        }

        let id = store.state.path.ids.first!

        await store.send(.path(.element(id: id, action: .detail(.playEpisodeTapped(episode))))) {
            $0.path.append(
                .player(
                    PlayerFeature.State(
                        movieID: DetailMockData.detail.id,
                        episodeID: episode.id,
                        movieTitle: DetailMockData.detail.title,
                        episodeLabel: episode.label,
                        summary: detailState.summary
                    )
                )
            )
        }
    }

    @Test
    func pushPlayerRoute() async {
        let store = makeStore()
        let movie = placeholderMovie()

        await store.send(.home(.playerTapped)) {
            $0.path.append(
                .player(
                    PlayerFeature.State(
                        movieID: movie.id,
                        episodeID: 1,
                        movieTitle: movie.displayTitle,
                        episodeLabel: "Tập 1",
                        summary: "Placeholder player screen. Phase 3 will map playback logic here."
                    )
                )
            )
        }

        guard case let .player(playerState)? = store.state.path.first else {
            Issue.record("Expected a player route to be pushed.")
            return
        }

        #expect(playerState.movieTitle == movie.displayTitle)
    }

    @Test
    func popRouteFromChildBackAction() async {
        let store = makeStore()

        await store.send(.home(.searchTapped)) {
            $0.path.append(.search(SearchFeature.State()))
        }

        let id = store.state.path.ids.first!

        await store.send(.path(.element(id: id, action: .search(.backButtonTapped))))
        await store.receive(.popFromPath(id)) {
            $0.path = StackState()
        }
    }

    @Test
    func popToRootClearsStack() async {
        let store = makeStore()

        await store.send(.home(.searchTapped)) {
            $0.path.append(.search(SearchFeature.State()))
        }
        await store.send(.home(.detailTapped(movie: placeholderMovie()))) {
            $0.path.append(
                .detail(
                    DetailFeature.State(movie: placeholderMovie())
                )
            )
        }
        await store.send(.popToRootTapped) {
            $0.path = StackState()
        }
    }

    @Test
    func authBannerOpensAndDismissesSheet() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test(authManager: PhucTvSupabaseAuthManager(client: nil)))
        }

        await store.send(.task)
        await store.receive(.authSnapshotRefreshed) {
            $0.authBanner = AppFeature.AuthBannerState(
                message: "Đăng nhập để đồng bộ liked movies và playback position.",
                buttonTitle: "Đăng nhập",
                isSignedIn: false
            )
        }

        await store.send(.authBannerButtonTapped) {
            $0.auth = AuthFeature.State()
        }

        await store.send(.auth(.dismiss)) {
            $0.auth = nil
        }
    }

    @Test
    func openURLRefreshesAuthState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test(authManager: PhucTvSupabaseAuthManager(client: nil)))
        }

        await store.send(.task)
        await store.receive(.authSnapshotRefreshed) {
            $0.authBanner = AppFeature.AuthBannerState(
                message: "Đăng nhập để đồng bộ liked movies và playback position.",
                buttonTitle: "Đăng nhập",
                isSignedIn: false
            )
        }

        await store.send(.openURL(URL(string: "phuctv://auth/callback")!))
        await store.receive(.authSnapshotRefreshed)
    }

    private func makeStore() -> TestStore<AppFeature.State, AppFeature.Action> {
        let authManager = PhucTvSupabaseAuthManager(client: nil)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test(authManager: authManager))
        }

        return store
    }

    private func placeholderMovie() -> PhucTvMovieCard {
        PhucTvMovieCard(
            id: 1_001,
            name: "Placeholder Movie",
            otherName: "Shell Migration",
            avatar: "",
            bannerThumb: "",
            avatarThumb: "",
            description: "A placeholder movie used during the shell migration phase.",
            banner: "",
            imageIcon: "",
            link: "placeholder-movie",
            quantity: "",
            rating: "",
            year: 2026,
            statusTitle: "Placeholder",
            statusRaw: "placeholder",
            statusText: "placeholder",
            director: "",
            time: "",
            trailer: "",
            showTimes: "",
            moreInfo: "",
            castString: "",
            episodesTotal: 1,
            viewNumber: 0,
            ratePoint: 0,
            photoUrls: [],
            previewPhotoUrls: []
        )
    }
}

@MainActor
private final class AuthStateBox: @unchecked Sendable {
    var authenticated: Bool
    let summary: PhucTvSupabaseUserSummary

    init(authenticated: Bool, summary: PhucTvSupabaseUserSummary) {
        self.authenticated = authenticated
        self.summary = summary
    }
}
