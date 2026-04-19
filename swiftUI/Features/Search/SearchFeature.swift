import ComposableArchitecture
import Foundation

@Reducer
struct SearchFeature {
    enum CancelID {
        case bootstrap
        case pageLoad
    }

    struct LoadError: Equatable, Sendable, Error {
        let message: String

        init(_ error: Error) {
            message = String(describing: error)
        }
    }

    struct BootstrapResponse: Equatable, Sendable {
        let filters: PhucTvSearchFilterData
        let likedMovies: [PhucTvMovieCard]
    }

    struct PageResponse: Equatable, Sendable {
        let results: PhucTvSearchResults
        let pageNumber: Int
    }

    @ObservableState
    struct State: Equatable {
        var uiState: SearchUIState
        var routeInput: SearchRouteInput
        var activePicker: SearchPickerKind?
        var didBootstrap = false

        init(
            routeInput: SearchRouteInput = SearchRouteInput(),
            uiState: SearchUIState? = nil
        ) {
            self.routeInput = routeInput
            self.uiState = uiState ?? SearchUIState(
                searchText: routeInput.initialQuery,
                searchInputValue: routeInput.initialQuery,
                showLikedOnly: routeInput.startLikedOnly
            )
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onTask
        case refresh
        case retryTapped
        case submitSearch(String?)
        case clearSearch
        case selectCategory(String)
        case selectCountry(String)
        case selectTypeRaw(String)
        case selectYear(String)
        case selectOrderBy(String)
        case toggleLikedOnly
        case clearCategory
        case clearCountry
        case clearTypeRaw
        case clearYear
        case clearOrderBy
        case goToPage(Int)
        case loadFiltersResponse(Result<BootstrapResponse, LoadError>)
        case loadPageResponse(Result<PageResponse, LoadError>)
        case detailTapped(movie: PhucTvMovieCard)
        case backButtonTapped
    }

    @Dependency(\.phucTvRepository) var repository
    @Dependency(\.phucTvLikedMovieStore) var likedMovieStore

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onTask:
                guard !state.didBootstrap else {
                    return .none
                }
                return startBootstrap(&state)

            case .refresh:
                if state.uiState.showLikedOnly {
                    state.uiState = state.uiState.withIdle()
                    return .none
                }

                if hasLoadedBootstrapData(state) == false {
                    return startBootstrap(&state)
                }

                return loadPage(pageNumber: state.uiState.currentPage, state: &state)

            case .retryTapped:
                if hasLoadedBootstrapData(state) == false {
                    return startBootstrap(&state)
                }

                if state.uiState.showLikedOnly {
                    state.uiState = state.uiState.withIdle()
                    return .none
                }

                return loadPage(pageNumber: state.uiState.currentPage, state: &state)

            case let .submitSearch(text):
                let nextValue = (text ?? state.uiState.searchInputValue)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                state.uiState = state.uiState
                    .withSearchInput(nextValue)
                    .commitSearch()
                return loadPage(pageNumber: 1, state: &state)

            case .clearSearch:
                state.uiState = state.uiState.clearSearchInput()
                return loadPage(pageNumber: 1, state: &state)

            case let .selectCategory(optionID):
                if let option = categoryOption(for: optionID, in: state.uiState) {
                    state.uiState = state.uiState.withCategory(option)
                } else {
                    state.uiState = state.uiState.clearCategory()
                }
                return loadPage(pageNumber: 1, state: &state)

            case let .selectCountry(optionID):
                if let option = countryOption(for: optionID, in: state.uiState) {
                    state.uiState = state.uiState.withCountry(option)
                } else {
                    state.uiState = state.uiState.clearCountry()
                }
                return loadPage(pageNumber: 1, state: &state)

            case let .selectTypeRaw(optionID):
                if let option = searchTypeOption(for: optionID) {
                    state.uiState = state.uiState.withTypeRaw(option)
                } else {
                    state.uiState = state.uiState.clearTypeRaw()
                }
                return loadPage(pageNumber: 1, state: &state)

            case let .selectYear(optionID):
                if let option = searchYearOption(for: optionID) {
                    state.uiState = state.uiState.withYear(option)
                } else {
                    state.uiState = state.uiState.clearYear()
                }
                return loadPage(pageNumber: 1, state: &state)

            case let .selectOrderBy(value):
                state.uiState = state.uiState.withOrderBy(value)
                return loadPage(pageNumber: 1, state: &state)

            case .toggleLikedOnly:
                state.uiState = state.uiState.toggleLikedOnly()
                return .none

            case .clearCategory:
                state.uiState = state.uiState.clearCategory()
                return loadPage(pageNumber: 1, state: &state)

            case .clearCountry:
                state.uiState = state.uiState.clearCountry()
                return loadPage(pageNumber: 1, state: &state)

            case .clearTypeRaw:
                state.uiState = state.uiState.clearTypeRaw()
                return loadPage(pageNumber: 1, state: &state)

            case .clearYear:
                state.uiState = state.uiState.clearYear()
                return loadPage(pageNumber: 1, state: &state)

            case .clearOrderBy:
                state.uiState = state.uiState.clearOrderBy()
                return loadPage(pageNumber: 1, state: &state)

            case let .goToPage(pageNumber):
                let target = max(pageNumber, 1)
                if state.uiState.showLikedOnly {
                    state.uiState = state.uiState.withPageNumber(target)
                    return .none
                }
                return loadPage(pageNumber: target, state: &state)

            case let .loadFiltersResponse(.success(response)):
                state.uiState = state.uiState
                    .withLoadedFilters(response.filters)
                    .withLikedMovies(response.likedMovies)

                let preset = response.filters.findPreset(slug: state.routeInput.presetSlug)
                state.uiState = state.uiState.applyPreset(
                    preset,
                    fallbackLabel: state.routeInput.initialLabel,
                    slug: state.routeInput.presetSlug
                )

                let initialQuery = state.routeInput.initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !initialQuery.isEmpty {
                    state.uiState = state.uiState
                        .withSearchInput(initialQuery)
                        .commitSearch()
                }

                return loadPage(pageNumber: 1, state: &state)

            case let .loadFiltersResponse(.failure(error)):
                state.uiState = state.uiState.withError(error.message)
                return .none

            case let .loadPageResponse(.success(response)):
                state.uiState = state.uiState.withSearchResults(response.results, pageNumber: response.pageNumber)
                return .none

            case let .loadPageResponse(.failure(error)):
                state.uiState = state.uiState.withError(error.message)
                return .none

            case .detailTapped:
                return .none

            case .backButtonTapped:
                return .none
            }
        }
    }

    private func startBootstrap(_ state: inout State) -> Effect<Action> {
        state.didBootstrap = true
        state.uiState = state.uiState.withLoading()
        return .merge(
            .cancel(id: CancelID.pageLoad),
            bootstrapEffect()
        )
    }

    private func hasLoadedBootstrapData(_ state: State) -> Bool {
        !state.uiState.filters.categories.isEmpty
            || !state.uiState.filters.countries.isEmpty
            || !state.uiState.likedMovies.isEmpty
    }

    private func bootstrapEffect() -> Effect<Action> {
        let repository = repository
        let likedMovieStore = likedMovieStore

        return .run { send in
            do {
                async let filtersTask = repository.loadSearchFilters()
                async let likedMoviesTask = likedMovieStore.loadMovies()
                let filters = try await filtersTask
                let likedMovies = try await likedMoviesTask
                await send(
                    .loadFiltersResponse(
                        .success(
                            BootstrapResponse(filters: filters, likedMovies: likedMovies)
                        )
                    )
                )
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Search bootstrap failed",
                    metadata: [
                        "state": "search_bootstrap",
                    ]
                )
                await send(.loadFiltersResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.bootstrap, cancelInFlight: true)
    }

    private func loadPage(pageNumber: Int, state: inout State) -> Effect<Action> {
        let targetPage = max(pageNumber, 1)
        if state.uiState.showLikedOnly {
            state.uiState = state.uiState.withPageNumber(targetPage).withIdle()
            return .none
        }

        let queryState = state.uiState.withLoading(isSearching: !state.uiState.records.isEmpty)
        state.uiState = queryState

        let repository = repository
        return .run { send in
            do {
                let results = try await repository.loadSearchResults(
                    categoryId: queryState.selectedCategoryID,
                    countryId: queryState.selectedCountryID,
                    typeRaw: queryState.selectedTypeRaw,
                    year: queryState.selectedYear,
                    orderBy: queryState.selectedOrderBy,
                    isChieuRap: false,
                    is4k: false,
                    search: queryState.searchText,
                    pageNumber: targetPage
                )
                await send(
                    .loadPageResponse(
                        .success(
                            PageResponse(results: results, pageNumber: targetPage)
                        )
                    )
                )
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Search page load failed",
                    metadata: [
                        "page": "\(targetPage)",
                        "query": queryState.searchText,
                    ]
                )
                await send(.loadPageResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.pageLoad, cancelInFlight: true)
    }

    private func categoryOption(for optionID: String, in uiState: SearchUIState) -> PhucTvSearchFacetOption? {
        uiState.filters.categoryOptionsWithAll()
            .first(where: { "category-\($0.id)-\($0.slug)" == optionID })
    }

    private func countryOption(for optionID: String, in uiState: SearchUIState) -> PhucTvSearchFacetOption? {
        uiState.filters.countryOptionsWithAll()
            .first(where: { "country-\($0.id)-\($0.slug)" == optionID })
    }

    private func searchTypeOption(for optionID: String) -> PhucTvSearchChoice? {
        searchTypeOptions.first(where: { "type-\($0.value)" == optionID })
    }

    private func searchYearOption(for optionID: String) -> PhucTvSearchChoice? {
        searchYearOptions.first(where: { "year-\($0.value)" == optionID })
    }
}
