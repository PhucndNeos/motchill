import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var home = HomeFeature.State()
        var path = StackState<Path.State>()
        @Presents var auth: AuthFeature.State?
        var authBanner: AuthBannerState?
    }

    @CasePathable
    enum Action: Equatable {
        case task
        case home(HomeFeature.Action)
        case path(StackActionOf<Path>)
        case popFromPath(StackElementID)
        case authBannerButtonTapped
        case auth(PresentationAction<AuthFeature.Action>)
        case openURL(URL)
        case authSnapshotRefreshed
        case popToRootTapped
    }

    struct AuthBannerState: Equatable {
        let message: String
        let buttonTitle: String
        let isSignedIn: Bool
    }

    @Reducer
    enum Path {
        case search(SearchFeature)
        case detail(DetailFeature)
        case player(PlayerFeature)
    }

    @Dependency(\.phucTvAuthManager) private var authManager

    var body: some ReducerOf<Self> {
        let authManager = self.authManager
        Reduce { state, action in
            switch action {
            case .task:
                state.authBanner = nil
                return .run { send in
                    await authManager.refreshSessionState()
                    await send(.authSnapshotRefreshed)
                }

            case .home(.searchTapped):
                state.path.append(.search(SearchFeature.State()))
                return .none

            case let .home(.detailTapped(movie: movie)):
                state.path.append(.detail(Self.makeDetailState(movie: movie)))
                return .none

            case .home(.playerTapped):
                state.path.append(.player(Self.makePlaceholderPlayerState()))
                return .none

            case .home:
                return .none

            case let .path(.element(id: _, action: .search(.detailTapped(movie: movie)))):
                state.path.append(.detail(Self.makeDetailState(movie: movie)))
                return .none

            case let .path(.element(id: id, action: .detail(.playEpisodeTapped(episode)))):
                guard case let .detail(detailState)? = state.path[id: id] else {
                    return .none
                }

                state.path.append(
                    .player(
                        Self.makePlayerState(
                            detail: detailState,
                            episode: episode
                        )
                    )
                )
                return .none

            case let .path(.element(id: _, action: .detail(.relatedMovieTapped(movie)))):
                state.path.append(.detail(Self.makeDetailState(movie: movie)))
                return .none

            case .path(.element(id: _, action: .detail(.searchTapped))):
                state.path.append(.search(SearchFeature.State()))
                return .none

            case let .path(.element(id: id, action: .search(.backButtonTapped))),
                 let .path(.element(id: id, action: .detail(.backButtonTapped))),
                 let .path(.element(id: id, action: .player(.closeRequested))):
                return .send(.popFromPath(id))

            case .path:
                return .none

            case let .popFromPath(id):
                state.path.pop(from: id)
                return .none

            case .authBannerButtonTapped:
                if authManager.isAuthenticated() {
                    return .run { send in
                        await authManager.signOut()
                        await send(.authSnapshotRefreshed)
                    }
                }

                state.auth = AuthFeature.State()
                return .none

            case .auth(.presented(.delegate(.closeRequested))):
                state.auth = nil
                return .none

            case .auth(.presented(.delegate(.authenticated))):
                state.auth = nil
                state.authBanner = Self.makeAuthBanner(from: authManager)
                return .none

            case .auth(.dismiss):
                return .none

            case .auth:
                return .none

            case let .openURL(url):
                authManager.handle(url)
                return .run { send in
                    await authManager.refreshSessionState()
                    await send(.authSnapshotRefreshed)
                }

            case .authSnapshotRefreshed:
                state.authBanner = Self.makeAuthBanner(from: authManager)
                if authManager.isAuthenticated() {
                    state.auth = nil
                }
                return .none

            case .popToRootTapped:
                state.path.removeAll()
                return .none
            }
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        .ifLet(\.$auth, action: \.auth) {
            AuthFeature()
        }
        .forEach(\.path, action: \.path)
    }

    private static func makeAuthBanner(from authManager: PhucTvAuthManagerClient) -> AuthBannerState? {
        if authManager.isAuthenticated() {
            let email = authManager.userSummary()?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = if let email, !email.isEmpty {
                "Đang đăng nhập với \(email)."
            } else {
                "Đang đăng nhập."
            }

            return AuthBannerState(
                message: message,
                buttonTitle: "Đăng xuất",
                isSignedIn: true
            )
        }

        guard let hint = authManager.signInHint() else {
            return nil
        }

        return AuthBannerState(
            message: hint,
            buttonTitle: "Đăng nhập",
            isSignedIn: false
        )
    }

    private static func makeDetailState(movie: PhucTvMovieCard) -> DetailFeature.State {
        DetailFeature.State(movie: movie)
    }

    private static func makePlayerState(
        detail: DetailFeature.State,
        episode: PhucTvMovieEpisode
    ) -> PlayerFeature.State {
        PlayerFeature.State(
            movieID: detail.detail?.id ?? detail.movie.id,
            episodeID: episode.id,
            movieTitle: detail.title,
            episodeLabel: episode.label,
            summary: detail.summary
        )
    }

    private static func makePlaceholderPlayerState() -> PlayerFeature.State {
        PlayerFeature.State(
            movieID: placeholderMovie.id,
            episodeID: 1,
            movieTitle: placeholderMovie.displayTitle,
            episodeLabel: "Tập 1",
            summary: "Placeholder player screen. Phase 3 will map playback logic here."
        )
    }

    private static let placeholderMovie = PhucTvMovieCard(
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

extension AppFeature.Path.State: Equatable {}
extension AppFeature.Path.Action: Equatable {}
