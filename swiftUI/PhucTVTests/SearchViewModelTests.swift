import XCTest
@testable import PhucTvSwiftUI

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testLoadCombinesFiltersLikedMoviesAndSearchResults() async {
        let repository = StubSearchRepository(
            filters: sampleFilters(),
            results: sampleResults()
        )
        let likedStore = StubLikedMovieStore(movies: [sampleMovie(id: 99, title: "Liked")])
        let viewModel = SearchViewModel(
            repository: repository,
            likedMovieStore: likedStore,
            routeInput: SearchRouteInput(initialQuery: "hero")
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.uiState.filters.categories.count, 1)
        XCTAssertEqual(viewModel.uiState.likedMovies.count, 1)
        XCTAssertEqual(viewModel.uiState.records.count, 2)
        XCTAssertEqual(viewModel.uiState.searchText, "hero")
        XCTAssertEqual(repository.loadSearchResultsCallCount, 1)
    }

    func testFilterChangeTriggersPageOneReload() async {
        let repository = StubSearchRepository(
            filters: sampleFilters(),
            results: sampleResults()
        )
        let viewModel = SearchViewModel(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: [])
        )

        await viewModel.load()
        let option = sampleFilters().categories.first
        await viewModel.selectCategory(option)

        XCTAssertEqual(repository.lastCategoryID, option?.id)
        XCTAssertEqual(repository.lastPageNumber, 1)
        XCTAssertEqual(viewModel.uiState.pageNumber, 1)
    }

    func testToggleLikedOnlyDoesNotCallRepositoryAgain() async {
        let repository = StubSearchRepository(
            filters: sampleFilters(),
            results: sampleResults()
        )
        let viewModel = SearchViewModel(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: [sampleMovie(id: 11, title: "Local favorite")])
        )

        await viewModel.load()
        let callCount = repository.loadSearchResultsCallCount
        viewModel.toggleLikedOnly()

        XCTAssertTrue(viewModel.uiState.showLikedOnly)
        XCTAssertEqual(repository.loadSearchResultsCallCount, callCount)
    }

    func testFailureSurfacesErrorState() async {
        let repository = StubSearchRepository(
            filters: sampleFilters(),
            results: sampleResults(),
            searchError: StubError.failed
        )
        let viewModel = SearchViewModel(
            repository: repository,
            likedMovieStore: StubLikedMovieStore(movies: [])
        )

        await viewModel.load()

        XCTAssertNotNil(viewModel.uiState.errorMessage)
        XCTAssertFalse(viewModel.uiState.isLoading)
        XCTAssertFalse(viewModel.uiState.isSearching)
    }

    private func sampleFilters() -> PhucTvSearchFilterData {
        PhucTvSearchFilterData(
            categories: [PhucTvSearchFacetOption(id: 1, name: "Action", slug: "action")],
            countries: [PhucTvSearchFacetOption(id: 2, name: "Korea", slug: "korea")]
        )
    }

    private func sampleResults() -> PhucTvSearchResults {
        PhucTvSearchResults(
            records: [
                sampleMovie(id: 1, title: "Hero"),
                sampleMovie(id: 2, title: "Another Hero"),
            ],
            pagination: PhucTvSearchPagination(pageIndex: 1, pageSize: 12, pageCount: 2, totalRecords: 20)
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

private final class StubSearchRepository: PhucTvRepository, @unchecked Sendable {
    let filters: PhucTvSearchFilterData
    let results: PhucTvSearchResults
    let searchError: Error?

    private(set) var loadSearchResultsCallCount = 0
    private(set) var lastCategoryID: Int?
    private(set) var lastPageNumber: Int?

    init(
        filters: PhucTvSearchFilterData,
        results: PhucTvSearchResults,
        searchError: Error? = nil
    ) {
        self.filters = filters
        self.results = results
        self.searchError = searchError
    }

    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }
    func loadSearchFilters() async throws -> PhucTvSearchFilterData { filters }
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
        loadSearchResultsCallCount += 1
        lastCategoryID = categoryId
        lastPageNumber = pageNumber
        if let searchError {
            throw searchError
        }
        return results
    }
    func loadEpisodeSources(movieID: Int, episodeID: Int, server: Int) async throws -> [PhucTvPlaySource] { [] }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
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
