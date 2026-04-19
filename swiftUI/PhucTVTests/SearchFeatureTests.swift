import ComposableArchitecture
import Foundation
import Testing

@testable import PhucTV

@MainActor
struct SearchFeatureTests {
    init() {
        uncheckedUseMainSerialExecutor = true
    }

    @Test
    func bootstrapLoadsFiltersLikedMoviesPresetAndInitialQuery() async {
        let filters = sampleFilters()
        let likedMovies = [sampleMovie(id: 99, title: "Liked")]
        let results = sampleResults(pageNumber: 1)
        let repository = SearchRepositorySpy(
            filters: filters,
            searchResults: results
        )
        let likedStore = StubLikedMovieStore(movies: likedMovies)
        let store = makeStore(
            repository: repository,
            likedMovieStore: likedStore,
            state: SearchFeature.State(
                routeInput: SearchRouteInput(
                    initialQuery: "hero",
                    presetSlug: "action",
                    initialLabel: "Featured"
                )
            )
        )

        await store.send(.onTask) {
            $0.didBootstrap = true
            $0.uiState = $0.uiState.withLoading()
        }

        await store.receive(.loadFiltersResponse(.success(.init(filters: filters, likedMovies: likedMovies)))) {
            $0.uiState = $0.uiState
                .withLoadedFilters(filters)
                .withLikedMovies(likedMovies)
                .applyPreset(
                    SearchPreset(categoryID: 1, categoryLabel: "Action"),
                    fallbackLabel: "Featured",
                    slug: "action"
                )
                .withSearchInput("hero")
                .commitSearch()
        }

        await store.receive(.loadPageResponse(.success(.init(results: results, pageNumber: 1)))) {
            $0.uiState = $0.uiState.withSearchResults(results, pageNumber: 1)
        }

        #expect(repository.loadSearchFiltersCount == 1)
        #expect(repository.loadSearchResultsCount == 1)
        #expect(store.state.uiState.searchText == "hero")
        #expect(store.state.uiState.searchInputValue == "hero")
        #expect(store.state.uiState.selectedCategoryID == 1)
        #expect(store.state.uiState.selectedCategoryLabel == "Action")
        #expect(store.state.uiState.likedMovies.count == 1)
    }

    @Test
    func bootstrapFailureSetsErrorState() async {
        let repository = SearchRepositorySpy(
            filters: sampleFilters(),
            searchResults: sampleResults(pageNumber: 1),
            loadSearchFiltersError: StubError.failed
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: []),
            state: SearchFeature.State(routeInput: SearchRouteInput())
        )

        await store.send(.onTask) {
            $0.didBootstrap = true
            $0.uiState = $0.uiState.withLoading()
        }

        await store.receive(.loadFiltersResponse(.failure(.init(StubError.failed)))) {
            $0.uiState = $0.uiState.withError("failed")
        }

        #expect(repository.loadSearchFiltersCount == 1)
        #expect(repository.loadSearchResultsCount == 0)
        #expect(store.state.uiState.errorMessage == "failed")
        #expect(store.state.uiState.isLoading == false)
        #expect(store.state.uiState.isSearching == false)
    }

    @Test
    func submittingSearchAndPagingLoadExpectedPages() async {
        let repository = SearchRepositorySpy(
            filters: sampleFilters(),
            searchResults: sampleResults(pageNumber: 1)
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: [sampleMovie(id: 10, title: "Local")]),
            state: bootstrapState(
                records: [sampleMovie(id: 1, title: "Old result")],
                pagination: PhucTvSearchPagination(pageIndex: 1, pageSize: 12, pageCount: 3, totalRecords: 36)
            )
        )

        repository.searchResultsHandler = { request in
            request.pageNumber == 2
                ? sampleResults(pageNumber: 2)
                : sampleResults(pageNumber: 1)
        }

        await store.send(.submitSearch(" hero ")) {
            $0.uiState = $0.uiState
                .withSearchInput("hero")
                .commitSearch()
                .withLoading(isSearching: true)
        }

        await store.receive(.loadPageResponse(.success(.init(results: sampleResults(pageNumber: 1), pageNumber: 1)))) {
            $0.uiState = $0.uiState.withSearchResults(sampleResults(pageNumber: 1), pageNumber: 1)
        }

        #expect(repository.requests.first?.search == "hero")
        #expect(repository.requests.first?.pageNumber == 1)

        await store.send(.goToPage(2)) {
            $0.uiState = $0.uiState.withLoading(isSearching: true)
        }

        await store.receive(.loadPageResponse(.success(.init(results: sampleResults(pageNumber: 2), pageNumber: 2)))) {
            $0.uiState = $0.uiState.withSearchResults(sampleResults(pageNumber: 2), pageNumber: 2)
        }

        #expect(repository.requests.count == 2)
        #expect(repository.requests.last?.pageNumber == 2)
        #expect(repository.requests.last?.search == "hero")

        #expect(store.state.uiState.currentPage == 2)
        #expect(store.state.uiState.searchText == "hero")
    }

    @Test
    func filterChangeUpdatesStateAndReloadsFirstPage() async {
        let repository = SearchRepositorySpy(
            filters: sampleFilters(),
            searchResults: sampleResults(pageNumber: 1)
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: []),
            state: bootstrapState()
        )

        await store.send(.selectCategory("category-1-action")) {
            $0.uiState = $0.uiState.withCategory(sampleFilters().categories.first)
            $0.uiState.isLoading = true
            $0.uiState.isSearching = false
            $0.uiState.errorMessage = nil
        }

        #expect(repository.requests.first?.categoryID == 1)
        #expect(repository.requests.first?.pageNumber == 1)
        #expect(repository.requests.first?.search == "")

        await store.receive(.loadPageResponse(.success(.init(results: sampleResults(pageNumber: 1), pageNumber: 1)))) {
            $0.uiState = $0.uiState.withSearchResults(sampleResults(pageNumber: 1), pageNumber: 1)
        }

        #expect(store.state.uiState.selectedCategoryID == 1)
        #expect(store.state.uiState.pageNumber == 1)
    }

    @Test
    func toggleLikedOnlyStaysLocal() async {
        let repository = SearchRepositorySpy(
            filters: sampleFilters(),
            searchResults: sampleResults(pageNumber: 1)
        )
        let likedStore = StubLikedMovieStore(movies: [sampleMovie(id: 11, title: "Local favorite")])
        let store = makeStore(
            repository: repository,
            likedMovieStore: likedStore,
            state: bootstrapState(
                likedMovies: [sampleMovie(id: 11, title: "Local favorite")],
                records: [sampleMovie(id: 1, title: "Remote result")],
                pagination: PhucTvSearchPagination(pageIndex: 1, pageSize: 12, pageCount: 1, totalRecords: 1)
            )
        )

        await store.send(.toggleLikedOnly) {
            $0.uiState = $0.uiState.toggleLikedOnly()
        }

        #expect(repository.loadSearchResultsCount == 0)
        #expect(store.state.uiState.showLikedOnly == true)
        #expect(store.state.uiState.visibleMovies.map(\.id) == [11])
    }

    @Test
    func newSearchCancelsPreviousRequest() async {
        let repository = SearchRepositorySpy(
            filters: sampleFilters(),
            searchResults: sampleResults(pageNumber: 1)
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: []),
            state: bootstrapState()
        )

        repository.searchResultsHandler = { request in
            if request.search == "first" {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch is CancellationError {
                    repository.cancelledSearches.append(request.search)
                    throw CancellationError()
                }
            }

            return request.search == "second"
                ? sampleResults(pageNumber: 1, titlePrefix: "Second")
                : sampleResults(pageNumber: 1, titlePrefix: "First")
        }

        await store.send(.submitSearch("first")) {
            $0.uiState.searchInputValue = "first"
            $0.uiState.searchText = "first"
            $0.uiState.isLoading = true
            $0.uiState.isSearching = false
            $0.uiState.errorMessage = nil
        }

        await store.send(.submitSearch("second")) {
            $0.uiState.searchInputValue = "second"
            $0.uiState.searchText = "second"
            $0.uiState.isLoading = true
            $0.uiState.isSearching = false
            $0.uiState.errorMessage = nil
        }

        await store.receive(.loadPageResponse(.success(.init(results: sampleResults(pageNumber: 1, titlePrefix: "Second"), pageNumber: 1)))) {
            $0.uiState = $0.uiState.withSearchResults(sampleResults(pageNumber: 1, titlePrefix: "Second"), pageNumber: 1)
        }

        #expect(repository.cancelledSearches == ["first"])
        #expect(repository.requests.map(\.search) == ["first", "second"])
        #expect(store.state.uiState.searchText == "second")
    }

    private func makeStore(
        repository: SearchRepositorySpy,
        likedMovieStore: StubLikedMovieStore,
        state: SearchFeature.State
    ) -> TestStore<SearchFeature.State, SearchFeature.Action> {
        TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(
                AppDependencies.test(
                    repository: repository,
                    likedMovieStore: likedMovieStore
                )
            )
        }
    }

    private func bootstrapState(
        likedMovies: [PhucTvMovieCard] = [],
        records: [PhucTvMovieCard] = [],
        pagination: PhucTvSearchPagination = .init(pageIndex: 1, pageSize: 12, pageCount: 1, totalRecords: 0)
    ) -> SearchFeature.State {
        var state = SearchFeature.State(routeInput: SearchRouteInput())
        state.didBootstrap = true
        state.uiState = SearchUIState()
            .withLoadedFilters(sampleFilters())
            .withLikedMovies(likedMovies)
            .withSearchResults(
                PhucTvSearchResults(records: records, pagination: pagination),
                pageNumber: pagination.pageIndex == 0 ? 1 : pagination.pageIndex
            )
        return state
    }

    private func sampleFilters() -> PhucTvSearchFilterData {
        PhucTvSearchFilterData(
            categories: [PhucTvSearchFacetOption(id: 1, name: "Action", slug: "action")],
            countries: [PhucTvSearchFacetOption(id: 2, name: "Korea", slug: "korea")]
        )
    }

    private func sampleResults(pageNumber: Int, titlePrefix: String = "Result") -> PhucTvSearchResults {
        PhucTvSearchResults(
            records: [
                sampleMovie(id: pageNumber * 10 + 1, title: "\(titlePrefix) 1"),
                sampleMovie(id: pageNumber * 10 + 2, title: "\(titlePrefix) 2"),
            ],
            pagination: PhucTvSearchPagination(pageIndex: pageNumber, pageSize: 12, pageCount: 3, totalRecords: 36)
        )
    }

    private func sampleMovie(id: Int, title: String) -> PhucTvMovieCard {
        PhucTvMovieCard(
            id: id,
            name: title,
            otherName: "",
            avatar: "",
            bannerThumb: "",
            avatarThumb: "",
            description: "",
            banner: "",
            imageIcon: "",
            link: "movie-\(id)",
            quantity: "",
            rating: "",
            year: 2024,
            statusTitle: "",
            statusRaw: "",
            statusText: "",
            director: "",
            time: "",
            trailer: "",
            showTimes: "",
            moreInfo: "",
            castString: "",
            episodesTotal: 0,
            viewNumber: 0,
            ratePoint: 0,
            photoUrls: [],
            previewPhotoUrls: []
        )
    }
}

private final class SearchRepositorySpy: PhucTvRepository, @unchecked Sendable {
    let filters: PhucTvSearchFilterData
    let searchResults: PhucTvSearchResults
    var loadSearchFiltersError: Error?
    var loadSearchResultsError: Error?

    var searchResultsHandler: ((SearchRequest) async throws -> PhucTvSearchResults)?
    private(set) var loadSearchFiltersCount = 0
    private(set) var loadSearchResultsCount = 0
    private(set) var requests: [SearchRequest] = []
    var cancelledSearches: [String] = []

    init(
        filters: PhucTvSearchFilterData,
        searchResults: PhucTvSearchResults,
        loadSearchFiltersError: Error? = nil,
        loadSearchResultsError: Error? = nil
    ) {
        self.filters = filters
        self.searchResults = searchResults
        self.loadSearchFiltersError = loadSearchFiltersError
        self.loadSearchResultsError = loadSearchResultsError
    }

    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }

    func loadSearchFilters() async throws -> PhucTvSearchFilterData {
        loadSearchFiltersCount += 1
        if let loadSearchFiltersError {
            throw loadSearchFiltersError
        }
        return filters
    }

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
        let request = SearchRequest(
            categoryID: categoryId,
            countryID: countryId,
            typeRaw: typeRaw,
            year: year,
            orderBy: orderBy,
            search: search,
            pageNumber: pageNumber
        )
        requests.append(request)
        loadSearchResultsCount += 1

        if let searchResultsHandler {
            return try await searchResultsHandler(request)
        }

        if let loadSearchResultsError {
            throw loadSearchResultsError
        }

        return searchResults
    }

    func loadEpisodeSources(movieID: Int, episodeID: Int, server: Int) async throws -> [PhucTvPlaySource] { [] }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private struct SearchRequest: Equatable {
    let categoryID: Int?
    let countryID: Int?
    let typeRaw: String
    let year: String
    let orderBy: String
    let search: String
    let pageNumber: Int
}

private actor StubLikedMovieStore: PhucTvLikedMovieStoring {
    let movies: [PhucTvMovieCard]

    init(movies: [PhucTvMovieCard]) {
        self.movies = movies
    }

    func loadMovies() async throws -> [PhucTvMovieCard] { movies }
    func loadIDs() async throws -> Set<Int> { Set(movies.map(\.id)) }
    func isLiked(movieID: Int) async throws -> Bool { movies.contains(where: { $0.id == movieID }) }
    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] { movies }
}

private enum StubError: Error {
    case failed
}
