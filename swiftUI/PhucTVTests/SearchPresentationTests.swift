import XCTest
@testable import PhucTvSwiftUI

final class SearchPresentationTests: XCTestCase {
    func testFindPresetPrefersCategoryAndCountryMatches() {
        let filters = PhucTvSearchFilterData(
            categories: [PhucTvSearchFacetOption(id: 1, name: "Action", slug: "hanh-dong")],
            countries: [PhucTvSearchFacetOption(id: 2, name: "Korea", slug: "han-quoc")]
        )

        let categoryPreset = filters.findPreset(slug: "hanh-dong")
        XCTAssertEqual(categoryPreset.categoryID, 1)
        XCTAssertEqual(categoryPreset.categoryLabel, "Action")
        XCTAssertNil(categoryPreset.countryLabel)

        let countryPreset = filters.findPreset(slug: "han-quoc")
        XCTAssertEqual(countryPreset.countryID, 2)
        XCTAssertEqual(countryPreset.countryLabel, "Korea")
    }

    func testUnknownPresetFallsBackToHumanizedSlug() {
        let state = SearchUIState().applyPreset(
            SearchPreset(),
            fallbackLabel: "",
            slug: "science-fiction"
        )

        XCTAssertEqual(state.selectedCategoryLabel, "Science Fiction")
    }

    func testLikedOnlyFilteringUsesLocalQueryMatching() {
        let state = SearchUIState(searchText: "oppenheimer")
        let movies = [
            movie(id: 1, name: "Oppenheimer", year: 2023),
            movie(id: 2, name: "Dune", year: 2024),
            movie(id: 3, name: "Opp", year: 2023),
        ]

        let filtered = filterLikedMovies(movies: movies, uiState: state)
        XCTAssertEqual(filtered.map(\.id), [1])
    }

    func testClearFiltersKeepsSearchInputButResetsRemoteFilters() {
        let state = SearchUIState(
            searchText: "oppenheimer",
            searchInputValue: "oppenheimer",
            selectedCategoryID: 1,
            selectedCategoryLabel: "Action",
            selectedCountryID: 2,
            selectedCountryLabel: "Korea",
            selectedTypeRaw: "single",
            selectedTypeLabel: "Phim Lẻ",
            selectedYear: "2023",
            selectedOrderBy: "Year",
            showLikedOnly: true
        )

        let cleared = state.clearSelectedFilters()
        XCTAssertNil(cleared.selectedCategoryID)
        XCTAssertNil(cleared.selectedCountryID)
        XCTAssertEqual(cleared.selectedTypeRaw, "")
        XCTAssertEqual(cleared.selectedTypeLabel, "")
        XCTAssertEqual(cleared.selectedYear, "")
        XCTAssertEqual(cleared.selectedOrderBy, defaultSearchOrderBy)
        XCTAssertFalse(cleared.showLikedOnly)
        XCTAssertEqual(cleared.searchText, "oppenheimer")
        XCTAssertEqual(cleared.searchInputValue, "oppenheimer")
    }

    func testLocalPaginationCalculatesPageState() {
        let movies = (1...13).map { movie(id: $0, name: "Movie \($0)", year: 2024) }
        let slice = paginateMovies(movies: movies, pageNumber: 2, pageSize: 12)

        XCTAssertEqual(slice.movies.count, 1)
        XCTAssertEqual(slice.movies.first?.id, 13)
        XCTAssertEqual(slice.pagination.pageIndex, 2)
        XCTAssertEqual(slice.pagination.pageCount, 2)
        XCTAssertEqual(slice.pagination.totalRecords, 13)
    }

    private func movie(id: Int, name: String, year: Int) -> PhucTvMovieCard {
        PhucTvMovieCard(
            id: id,
            name: name,
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
            year: year,
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

