import Foundation

let searchPageSize = 12
let defaultSearchOrderBy = "UpdateOn"

let searchOrderOptions = [
    MotchillSearchChoice(value: "UpdateOn", label: "Mới Nhất"),
    MotchillSearchChoice(value: "ViewNumber", label: "Lượt Xem"),
    MotchillSearchChoice(value: "Year", label: "Năm Phát Hành"),
]

let searchTypeOptions = [
    MotchillSearchChoice(value: "", label: "Tất cả"),
    MotchillSearchChoice(value: "single", label: "Phim Lẻ"),
    MotchillSearchChoice(value: "series", label: "Phim Bộ"),
]

let searchYearOptions: [MotchillSearchChoice] = {
    let currentYear = Calendar.current.component(.year, from: Date())
    let years = stride(from: currentYear, through: 2010, by: -1)
        .map { MotchillSearchChoice(value: "\($0)", label: "\($0)") }
    return [MotchillSearchChoice(value: "", label: "Tất cả")] + years
}()

struct SearchRouteInput: Hashable, Sendable {
    var initialQuery: String = ""
    var presetSlug: String = ""
    var initialLabel: String = ""
    var startLikedOnly: Bool = false
}

struct SearchPreset: Hashable, Sendable {
    let categoryID: Int?
    let categoryLabel: String?
    let countryID: Int?
    let countryLabel: String?

    init(
        categoryID: Int? = nil,
        categoryLabel: String? = nil,
        countryID: Int? = nil,
        countryLabel: String? = nil
    ) {
        self.categoryID = categoryID
        self.categoryLabel = categoryLabel
        self.countryID = countryID
        self.countryLabel = countryLabel
    }
}

struct SearchUIPickerOption: Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

enum SearchPickerKind: String, Identifiable {
    case category
    case country
    case type
    case year
    case order

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category: return "Thể loại"
        case .country: return "Quốc gia"
        case .type: return "Loại phim"
        case .year: return "Năm"
        case .order: return "Sắp xếp"
        }
    }
}

struct SearchChipState: Hashable, Identifiable {
    let id: String
    let title: String
    let value: String
    let isActive: Bool
    let picker: SearchPickerKind
}

struct SearchUIState: Hashable, Sendable {
    var isLoading = true
    var isSearching = false
    var errorMessage: String?
    var filters = MotchillSearchFilterData(categories: [], countries: [])
    var searchText = ""
    var searchInputValue = ""
    var selectedCategoryID: Int?
    var selectedCategoryLabel = ""
    var selectedCountryID: Int?
    var selectedCountryLabel = ""
    var selectedTypeRaw = ""
    var selectedTypeLabel = ""
    var selectedYear = ""
    var selectedOrderBy = defaultSearchOrderBy
    var showLikedOnly = false
    var likedMovies: [MotchillMovieCard] = []
    var likedMovieIDs: Set<Int> = []
    var records: [MotchillMovieCard] = []
    var pagination = MotchillSearchPagination(pageIndex: 0, pageSize: 0, pageCount: 0, totalRecords: 0)
    var pageNumber = 1

    var likedFilteredMovies: [MotchillMovieCard] {
        filterLikedMovies(movies: likedMovies, uiState: self)
    }

    var visibleMovies: [MotchillMovieCard] {
        if showLikedOnly {
            return paginateMovies(movies: likedFilteredMovies, pageNumber: pageNumber, pageSize: searchPageSize).movies
        }
        return records
    }

    var totalVisibleCount: Int {
        if showLikedOnly {
            return likedFilteredMovies.count
        }
        return pagination.totalRecords > 0 ? pagination.totalRecords : records.count
    }

    var currentPage: Int {
        if showLikedOnly {
            return paginateMovies(movies: likedFilteredMovies, pageNumber: pageNumber, pageSize: searchPageSize).pagination.pageIndex
        }
        return pagination.pageIndex > 0 ? pagination.pageIndex : max(pageNumber, 1)
    }

    var totalPages: Int {
        if showLikedOnly {
            return paginateMovies(movies: likedFilteredMovies, pageNumber: pageNumber, pageSize: searchPageSize).pagination.pageCount
        }
        return pagination.pageCount
    }

    var canGoPrevious: Bool {
        currentPage > 1
    }

    var canGoNext: Bool {
        let pages = totalPages
        return pages > 0 && currentPage < pages
    }

    var currentOrderLabel: String {
        orderLabel(selectedOrderBy)
    }

    var screenTitle: String {
        "Tìm kiếm phim"
    }

    var screenSubtitle: String {
        let parts = [
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "\"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"",
            selectedCategoryLabel.nonEmptyValue,
            selectedCountryLabel.nonEmptyValue,
            selectedTypeLabel.nonEmptyValue,
            selectedYear.nonEmptyValue,
            showLikedOnly ? "Đã thích" : nil,
        ].compactMap { $0 }

        if parts.isEmpty {
            return "Nhập từ khóa hoặc chọn bộ lọc"
        }

        return parts.joined(separator: " • ")
    }

    var filterChips: [SearchChipState] {
        [
            SearchChipState(
                id: SearchPickerKind.category.rawValue,
                title: "Thể loại",
                value: selectedCategoryLabel.nonEmptyValue ?? "Tất cả",
                isActive: selectedCategoryID != nil || selectedCategoryLabel.nonEmptyValue != nil,
                picker: .category
            ),
            SearchChipState(
                id: SearchPickerKind.country.rawValue,
                title: "Quốc gia",
                value: selectedCountryLabel.nonEmptyValue ?? "Tất cả",
                isActive: selectedCountryID != nil || selectedCountryLabel.nonEmptyValue != nil,
                picker: .country
            ),
            SearchChipState(
                id: SearchPickerKind.type.rawValue,
                title: "Loại",
                value: selectedTypeLabel.nonEmptyValue ?? "Tất cả",
                isActive: selectedTypeRaw.nonEmptyValue != nil,
                picker: .type
            ),
            SearchChipState(
                id: SearchPickerKind.year.rawValue,
                title: "Năm",
                value: selectedYear.nonEmptyValue ?? "Tất cả",
                isActive: selectedYear.nonEmptyValue != nil,
                picker: .year
            ),
            SearchChipState(
                id: SearchPickerKind.order.rawValue,
                title: "Sắp xếp",
                value: currentOrderLabel,
                isActive: selectedOrderBy != defaultSearchOrderBy,
                picker: .order
            ),
        ]
    }

    var overlayDescriptor: FeatureOverlayDescriptor? {
        if isLoading && visibleMovies.isEmpty {
            return .loading(
                title: "Đang tải tìm kiếm",
                message: "Motchill đang lấy bộ lọc và danh sách phim phù hợp.",
                errorCode: "search_loading"
            )
        }

        if let errorMessage, visibleMovies.isEmpty {
            return .failure(
                title: "Không thể tải tìm kiếm",
                message: errorMessage,
                errorCode: "search_error",
                icon: .network
            )
        }

        if !isLoading && errorMessage == nil && visibleMovies.isEmpty {
            return .empty(
                title: "Chưa có kết quả phù hợp",
                message: showLikedOnly
                    ? "Danh sách đã thích hiện chưa có nội dung khớp với bộ lọc này."
                    : "Thử đổi từ khóa, bộ lọc hoặc sắp xếp để xem thêm nội dung.",
                errorCode: "search_empty",
                icon: .generic
            )
        }

        return nil
    }
}

struct SearchPaginationSlice: Hashable, Sendable {
    let movies: [MotchillMovieCard]
    let pagination: MotchillSearchPagination
}

extension MotchillSearchFilterData {
    func findPreset(slug: String) -> SearchPreset {
        let normalizedSlug = normalizeSearchSlug(slug)
        guard !normalizedSlug.isEmpty else { return SearchPreset() }

        if let category = categories.first(where: { $0.matchesSlug(normalizedSlug) }) {
            return SearchPreset(
                categoryID: category.id > 0 ? category.id : nil,
                categoryLabel: category.name
            )
        }

        if let country = countries.first(where: { $0.matchesSlug(normalizedSlug) }) {
            return SearchPreset(
                countryID: country.id > 0 ? country.id : nil,
                countryLabel: country.name
            )
        }

        return SearchPreset()
    }

    func categoryOptionsWithAll() -> [MotchillSearchFacetOption] {
        withAllItem(categories)
    }

    func countryOptionsWithAll() -> [MotchillSearchFacetOption] {
        withAllItem(countries)
    }
}

extension SearchUIState {
    func applyPreset(
        _ preset: SearchPreset,
        fallbackLabel: String = "",
        slug: String = ""
    ) -> SearchUIState {
        let fallback = fallbackLabel.nonEmptyValue
            ?? humanizeSearchSlug(slug)
        var updated = self
        updated.selectedCategoryID = preset.categoryID
        updated.selectedCategoryLabel = preset.categoryLabel?.nonEmptyValue ?? (preset.categoryID == nil ? fallback : "")
        updated.selectedCountryID = preset.countryID
        updated.selectedCountryLabel = preset.countryLabel?.nonEmptyValue ?? ""
        updated.pageNumber = 1
        return updated
    }

    func withSearchInput(_ text: String) -> SearchUIState {
        var updated = self
        updated.searchInputValue = text
        return updated
    }

    func commitSearch() -> SearchUIState {
        var updated = self
        updated.searchText = searchInputValue.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.pageNumber = 1
        return updated
    }

    func withCategory(_ option: MotchillSearchFacetOption?) -> SearchUIState {
        var updated = self
        updated.selectedCategoryID = option.flatMap { $0.id > 0 ? $0.id : nil }
        updated.selectedCategoryLabel = option?.id == 0 ? "" : option?.name ?? ""
        updated.pageNumber = 1
        return updated
    }

    func withCountry(_ option: MotchillSearchFacetOption?) -> SearchUIState {
        var updated = self
        updated.selectedCountryID = option.flatMap { $0.id > 0 ? $0.id : nil }
        updated.selectedCountryLabel = option?.id == 0 ? "" : option?.name ?? ""
        updated.pageNumber = 1
        return updated
    }

    func withTypeRaw(_ option: MotchillSearchChoice?) -> SearchUIState {
        var updated = self
        updated.selectedTypeRaw = option?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.selectedTypeLabel = option?.value.nonEmptyValue == nil ? "" : option?.label ?? ""
        updated.pageNumber = 1
        return updated
    }

    func withYear(_ option: MotchillSearchChoice?) -> SearchUIState {
        var updated = self
        updated.selectedYear = option?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.pageNumber = 1
        return updated
    }

    func withOrderBy(_ value: String) -> SearchUIState {
        var updated = self
        updated.selectedOrderBy = value
        updated.pageNumber = 1
        return updated
    }

    func toggleLikedOnly() -> SearchUIState {
        var updated = self
        updated.showLikedOnly.toggle()
        return updated
    }

    func clearSearchInput() -> SearchUIState {
        var updated = self
        updated.searchInputValue = ""
        updated.searchText = ""
        updated.pageNumber = 1
        return updated
    }

    func clearCategory() -> SearchUIState {
        var updated = self
        updated.selectedCategoryID = nil
        updated.selectedCategoryLabel = ""
        updated.pageNumber = 1
        return updated
    }

    func clearCountry() -> SearchUIState {
        var updated = self
        updated.selectedCountryID = nil
        updated.selectedCountryLabel = ""
        updated.pageNumber = 1
        return updated
    }

    func clearTypeRaw() -> SearchUIState {
        var updated = self
        updated.selectedTypeRaw = ""
        updated.selectedTypeLabel = ""
        updated.pageNumber = 1
        return updated
    }

    func clearYear() -> SearchUIState {
        var updated = self
        updated.selectedYear = ""
        updated.pageNumber = 1
        return updated
    }

    func clearOrderBy() -> SearchUIState {
        var updated = self
        updated.selectedOrderBy = defaultSearchOrderBy
        updated.pageNumber = 1
        return updated
    }

    func clearSelectedFilters() -> SearchUIState {
        var updated = self
        updated.selectedCategoryID = nil
        updated.selectedCategoryLabel = ""
        updated.selectedCountryID = nil
        updated.selectedCountryLabel = ""
        updated.selectedTypeRaw = ""
        updated.selectedTypeLabel = ""
        updated.selectedYear = ""
        updated.selectedOrderBy = defaultSearchOrderBy
        updated.showLikedOnly = false
        updated.pageNumber = 1
        return updated
    }

    func withLoadedFilters(_ filters: MotchillSearchFilterData) -> SearchUIState {
        var updated = self
        updated.filters = filters
        return updated
    }

    func withLikedMovies(_ movies: [MotchillMovieCard]) -> SearchUIState {
        var updated = self
        updated.likedMovies = movies
        updated.likedMovieIDs = Set(movies.map(\.id))
        return updated
    }

    func withSearchResults(_ results: MotchillSearchResults, pageNumber: Int) -> SearchUIState {
        var updated = self
        updated.isLoading = false
        updated.isSearching = false
        updated.errorMessage = nil
        updated.records = results.records
        updated.pagination = results.pagination
        updated.pageNumber = pageNumber
        return updated
    }

    func withLoading(isSearching: Bool = false) -> SearchUIState {
        var updated = self
        updated.isLoading = true
        updated.isSearching = isSearching
        updated.errorMessage = nil
        return updated
    }

    func withIdle() -> SearchUIState {
        var updated = self
        updated.isLoading = false
        updated.isSearching = false
        return updated
    }

    func withError(_ message: String) -> SearchUIState {
        var updated = self
        updated.isLoading = false
        updated.isSearching = false
        updated.errorMessage = message
        return updated
    }

    func withPageNumber(_ value: Int) -> SearchUIState {
        var updated = self
        updated.pageNumber = max(value, 1)
        return updated
    }
}

func filterLikedMovies(movies: [MotchillMovieCard], uiState: SearchUIState) -> [MotchillMovieCard] {
    let query = uiState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return movies }

    return movies.filter { movie in
        [
            movie.displayTitle,
            movie.displaySubtitle,
            movie.description,
            movie.statusTitle,
            movie.link,
        ]
        .map { $0.lowercased() }
        .contains(where: { $0.contains(query) })
    }
}

func paginateMovies(
    movies: [MotchillMovieCard],
    pageNumber: Int,
    pageSize: Int = searchPageSize
) -> SearchPaginationSlice {
    let safeSize = max(pageSize, 1)
    guard !movies.isEmpty else {
        return SearchPaginationSlice(
            movies: [],
            pagination: MotchillSearchPagination(pageIndex: 0, pageSize: safeSize, pageCount: 0, totalRecords: 0)
        )
    }

    let pageCount = max(Int(ceil(Double(movies.count) / Double(safeSize))), 1)
    let safePage = min(max(pageNumber, 1), pageCount)
    let start = (safePage - 1) * safeSize
    let end = min(start + safeSize, movies.count)
    return SearchPaginationSlice(
        movies: Array(movies[start..<end]),
        pagination: MotchillSearchPagination(
            pageIndex: safePage,
            pageSize: safeSize,
            pageCount: pageCount,
            totalRecords: movies.count
        )
    )
}

func orderLabel(_ value: String) -> String {
    switch value {
    case "ViewNumber":
        return "Lượt Xem"
    case "Year":
        return "Năm Phát Hành"
    case "Name":
        return "Tên"
    default:
        return "Cập nhật mới"
    }
}

private func withAllItem(_ items: [MotchillSearchFacetOption]) -> [MotchillSearchFacetOption] {
    let all = MotchillSearchFacetOption(id: 0, name: "Tất cả", slug: "")
    guard let first = items.first else { return [all] }
    if first.id == 0 && first.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Tất cả") == .orderedSame {
        return items
    }
    return [all] + items
}

private func normalizeSearchSlug(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

private func humanizeSearchSlug(_ value: String) -> String {
    value
        .split(separator: "-")
        .map { part in
            let text = String(part)
            return text.count == 1 ? text.uppercased() : text.prefix(1).uppercased() + text.dropFirst()
        }
        .joined(separator: " ")
}

private extension MotchillSearchFacetOption {
    func matchesSlug(_ normalizedSlug: String) -> Bool {
        [
            name,
            slug,
        ]
        .map(normalizeSearchSlug)
        .contains(normalizedSlug)
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyValue: String? {
        self?.nonEmptyValue
    }
}
