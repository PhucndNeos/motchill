import ComposableArchitecture
import Foundation

/// The TCA reducer managing the state and logic for the Home screen.
/// It handles data fetching, user selections (sections/movies), and forwards navigation intents to the app shell.
@Reducer
struct HomeFeature {
    enum CancelID {
        case load
    }

    struct LoadError: Equatable, Sendable, Error {
        let message: String

        init(_ error: Error) {
            message = String(describing: error)
        }
    }

    /// The state of the Home feature, encompassing UI loading status, fetched sections, and user selections.
    @ObservableState
    struct State: Equatable {
        var status: HomeScreenState = .loading
        var selectedSection: PhucTvHomeSection?
        var selectedMovie: PhucTvMovieCard?

        var loadedContent: HomeFeedContent? {
            if case let .loaded(content) = status {
                return content
            }
            return nil
        }

        var sections: [PhucTvHomeSection] {
            loadedContent?.sections ?? []
        }

        var heroSection: PhucTvHomeSection? {
            sections.first(where: { $0.key == "slide" }) ?? sections.first
        }

        var heroMovies: [PhucTvMovieCard] {
            Array(heroSection?.products.prefix(6) ?? [])
        }

        var contentSections: [PhucTvHomeSection] {
            guard sections.contains(where: { $0.key == "slide" }) else {
                return sections
            }

            return sections.filter { $0.key != "slide" }
        }

        var hasRenderableContent: Bool {
            sections.contains(where: { !$0.products.isEmpty })
        }

        static func previewLoaded() -> Self {
            var state = Self(
                status: .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
            )
            HomeFeature.reconcileSelection(&state, with: HomeMockData.loadedSections)
            return state
        }

        static func previewLoading() -> Self {
            Self(status: .loading)
        }

        static func previewEmpty() -> Self {
            Self(status: .empty)
        }

        static func previewError() -> Self {
            Self(status: .error(message: "Không thể tải nội dung ngay lúc này."))
        }
    }

    /// The actions that can occur in the Home feature, including user interactions, binding updates, and network responses.
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onTask
        case retryTapped
        case loadResponse(Result<[PhucTvHomeSection], LoadError>)
        case searchTapped
        case detailTapped(movie: PhucTvMovieCard)
        case playerTapped
    }

    // MARK: - Dependencies

    @Dependency(\.phucTvRepository) var repository
    @Dependency(\.phucTvRemoteConfigClient) var remoteConfigClient
    @Dependency(\.phucTvRemoteConfigStore) var remoteConfigStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onTask, .retryTapped:
                state.status = .loading
                return loadHome()

            case .binding(\.selectedSection):
                Self.applySectionSelection(&state, section: state.selectedSection)
                return .none

            case .binding(\.selectedMovie):
                Self.applyMovieSelection(&state, movie: state.selectedMovie)
                return .none

            case let .loadResponse(.success(sections)):
                if sections.isEmpty {
                    state.status = .empty
                    return .none
                }

                state.status = .loaded(HomeFeedContent(sections: sections))
                Self.reconcileSelection(&state, with: sections)
                return .none

            case let .loadResponse(.failure(error)):
                state.status = .error(message: error.message)
                return .none

            case .searchTapped, .detailTapped, .playerTapped:
                return .none

            case .binding:
                return .none
            }
        }
    }

    /// Triggers the side effect to load remote configuration and home feed data from the repository.
    /// - Returns: An effect that emits a `.loadResponse` action.
    private func loadHome() -> Effect<Action> {
        let remoteConfigClient = remoteConfigClient
        let remoteConfigStore = remoteConfigStore
        let repository = repository

        return .run { send in
            do {
                let remoteConfig = try await remoteConfigClient.fetchRemoteConfig()
                remoteConfigStore.update(remoteConfig)

                let sections = try await repository.loadHome()
                await send(.loadResponse(.success(sections)))
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Home load failed",
                    metadata: [
                        "state": "home"
                    ]
                )
                await send(.loadResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    /// Applies a new section selection and automatically selects the first available movie in that section,
    /// or preserves the currently selected movie if it also exists in the new section.
    /// - Parameters:
    ///   - state: The current state to mutate.
    ///   - section: The newly selected section, or `nil` to clear the selection.
    private static func applySectionSelection(
        _ state: inout State,
        section: PhucTvHomeSection?
    ) {
        guard let section else {
            state.selectedSection = nil
            state.selectedMovie = nil
            return
        }

        let refreshedSection = state.sections.first(where: { $0.id == section.id }) ?? section
        state.selectedSection = refreshedSection
        applyMovieSelection(&state, movie: state.selectedMovie)
    }

    private static func applyMovieSelection(
        _ state: inout State,
        movie: PhucTvMovieCard?
    ) {
        guard let section = state.selectedSection else {
            state.selectedMovie = movie
            return
        }

        if let movie {
            state.selectedMovie = section.products.first(where: { $0.id == movie.id })
                ?? section.products.first
        } else {
            state.selectedMovie = section.products.first
        }
    }

    /// Reconciles the existing selection state with newly loaded data.
    /// This ensures that after a successful data fetch or retry, the UI does not lose the user's current section and movie selection,
    /// provided they still exist in the new data.
    /// - Parameters:
    ///   - state: The current state to mutate.
    ///   - sections: The newly fetched home sections.
    private static func reconcileSelection(
        _ state: inout State,
        with sections: [PhucTvHomeSection]
    ) {
        guard let selectedSection = state.selectedSection,
              let refreshedSection = sections.first(where: { $0.id == selectedSection.id }) else {
            state.selectedSection = sections.first
            state.selectedMovie = sections.first?.products.first
            return
        }

        state.selectedSection = refreshedSection

        if let selectedMovie = state.selectedMovie,
           let refreshedMovie = refreshedSection.products.first(where: { $0.id == selectedMovie.id }) {
            state.selectedMovie = refreshedMovie
        } else {
            state.selectedMovie = refreshedSection.products.first
        }
    }
}
