import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    @ObservationIgnored
    private let repository: MotchillRepository
    @ObservationIgnored
    private let likedMovieStore: MotchillLikedMovieStoring
    @ObservationIgnored
    private let routeInput: SearchRouteInput

    var uiState: SearchUIState

    init(
        repository: MotchillRepository,
        likedMovieStore: MotchillLikedMovieStoring,
        routeInput: SearchRouteInput = SearchRouteInput(),
        uiState: SearchUIState? = nil
    ) {
        self.repository = repository
        self.likedMovieStore = likedMovieStore
        self.routeInput = routeInput
        self.uiState = uiState ?? SearchUIState(
            searchText: routeInput.initialQuery,
            searchInputValue: routeInput.initialQuery,
            showLikedOnly: routeInput.startLikedOnly
        )
    }

    func load() async {
        uiState = uiState.withLoading()

        do {
            async let filtersTask = repository.loadSearchFilters()
            async let likedTask = likedMovieStore.loadMovies()
            let filters = try await filtersTask
            let likedMovies = try await likedTask
            let preset = filters.findPreset(slug: routeInput.presetSlug)

            uiState = uiState
                .withLoadedFilters(filters)
                .withLikedMovies(likedMovies)
                .applyPreset(
                    preset,
                    fallbackLabel: routeInput.initialLabel,
                    slug: routeInput.presetSlug
                )

            if !routeInput.initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                uiState = uiState
                    .withSearchInput(routeInput.initialQuery)
                    .commitSearch()
            }

            await loadPage(1)
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Search load failed",
                metadata: ["state": "search_load"]
            )
            uiState = uiState.withError(error.localizedDescription)
        }
    }

    func refresh() async {
        if uiState.showLikedOnly {
            uiState = uiState.withIdle()
            return
        }
        await loadPage(uiState.pageNumber)
    }

    func onSearchTextChanged(_ value: String) {
        uiState = uiState.withSearchInput(value)
    }

    func submitSearch(_ value: String? = nil) async {
        let nextValue = (value ?? uiState.searchInputValue).trimmingCharacters(in: .whitespacesAndNewlines)
        uiState = uiState
            .withSearchInput(nextValue)
            .commitSearch()
        await loadPage(1)
    }

    func clearSearch() async {
        uiState = uiState.clearSearchInput()
        await loadPage(1)
    }

    func selectCategory(_ option: MotchillSearchFacetOption?) async {
        if let option, option.hasID {
            uiState = uiState.withCategory(option)
        } else {
            uiState = uiState.clearCategory()
        }
        await loadPage(1)
    }

    func selectCountry(_ option: MotchillSearchFacetOption?) async {
        if let option, option.hasID {
            uiState = uiState.withCountry(option)
        } else {
            uiState = uiState.clearCountry()
        }
        await loadPage(1)
    }

    func selectTypeRaw(_ option: MotchillSearchChoice?) async {
        if let option, !option.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            uiState = uiState.withTypeRaw(option)
        } else {
            uiState = uiState.clearTypeRaw()
        }
        await loadPage(1)
    }

    func selectYear(_ option: MotchillSearchChoice?) async {
        if let option, !option.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            uiState = uiState.withYear(option)
        } else {
            uiState = uiState.clearYear()
        }
        await loadPage(1)
    }

    func selectOrderBy(_ value: String) async {
        uiState = uiState.withOrderBy(value)
        await loadPage(1)
    }

    func toggleLikedOnly() {
        uiState = uiState.toggleLikedOnly()
    }

    func clearCategory() async {
        uiState = uiState.clearCategory()
        await loadPage(1)
    }

    func clearCountry() async {
        uiState = uiState.clearCountry()
        await loadPage(1)
    }

    func clearTypeRaw() async {
        uiState = uiState.clearTypeRaw()
        await loadPage(1)
    }

    func clearYear() async {
        uiState = uiState.clearYear()
        await loadPage(1)
    }

    func clearOrderBy() async {
        uiState = uiState.clearOrderBy()
        await loadPage(1)
    }

    func goToPage(_ pageNumber: Int) async {
        let target = max(pageNumber, 1)
        if uiState.showLikedOnly {
            uiState = uiState.withPageNumber(target)
            return
        }
        await loadPage(target)
    }

    func pickerOptions(for kind: SearchPickerKind) -> [SearchUIPickerOption] {
        switch kind {
        case .category:
            return uiState.filters.categoryOptionsWithAll().map {
                SearchUIPickerOption(
                    id: "category-\($0.id)-\($0.slug)",
                    title: $0.name,
                    subtitle: $0.slug,
                    isSelected: uiState.selectedCategoryID == $0.id || (!$0.hasID && uiState.selectedCategoryID == nil)
                )
            }
        case .country:
            return uiState.filters.countryOptionsWithAll().map {
                SearchUIPickerOption(
                    id: "country-\($0.id)-\($0.slug)",
                    title: $0.name,
                    subtitle: $0.slug,
                    isSelected: uiState.selectedCountryID == $0.id || (!$0.hasID && uiState.selectedCountryID == nil)
                )
            }
        case .type:
            return searchTypeOptions.map {
                SearchUIPickerOption(
                    id: "type-\($0.value)",
                    title: $0.label,
                    subtitle: $0.value,
                    isSelected: uiState.selectedTypeRaw == $0.value
                )
            }
        case .year:
            return searchYearOptions.map {
                SearchUIPickerOption(
                    id: "year-\($0.value)",
                    title: $0.label,
                    subtitle: $0.value,
                    isSelected: uiState.selectedYear == $0.value
                )
            }
        case .order:
            return searchOrderOptions.map {
                SearchUIPickerOption(
                    id: "order-\($0.value)",
                    title: $0.label,
                    subtitle: $0.value,
                    isSelected: uiState.selectedOrderBy == $0.value
                )
            }
        }
    }

    private func loadPage(_ pageNumber: Int) async {
        if uiState.showLikedOnly {
            uiState = uiState.withPageNumber(pageNumber).withIdle()
            return
        }

        let state = uiState.withLoading(isSearching: !uiState.records.isEmpty)
        uiState = state

        do {
            let results = try await repository.loadSearchResults(
                categoryId: state.selectedCategoryID,
                countryId: state.selectedCountryID,
                typeRaw: state.selectedTypeRaw,
                year: state.selectedYear,
                orderBy: state.selectedOrderBy,
                isChieuRap: false,
                is4k: false,
                search: state.searchText,
                pageNumber: pageNumber
            )
            uiState = state.withSearchResults(results, pageNumber: pageNumber)
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Search page load failed",
                metadata: [
                    "page": "\(pageNumber)",
                    "query": state.searchText,
                ]
            )
            uiState = uiState.withError(error.localizedDescription)
        }
    }
}

