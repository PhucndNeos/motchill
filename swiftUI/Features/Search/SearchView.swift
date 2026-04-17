import SwiftUI

struct SearchView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let routeInput: SearchRouteInput
    private let initialViewModel: SearchViewModel?
    private let shouldLoadOnAppear: Bool

    init(
        router: AppRouter,
        routeInput: SearchRouteInput = SearchRouteInput()
    ) {
        self.router = router
        self.routeInput = routeInput
        self.initialViewModel = nil
        self.shouldLoadOnAppear = true
    }

    init(
        repository: PhucTvRepository,
        likedMovieStore: PhucTvLikedMovieStoring,
        router: AppRouter,
        routeInput: SearchRouteInput = SearchRouteInput()
    ) {
        self.router = router
        self.routeInput = routeInput
        self.initialViewModel = SearchViewModel(
            repository: repository,
            likedMovieStore: likedMovieStore,
            routeInput: routeInput
        )
        self.shouldLoadOnAppear = true
    }

    init(viewModel: SearchViewModel, router: AppRouter) {
        self.router = router
        self.routeInput = SearchRouteInput()
        self.initialViewModel = viewModel
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        SearchRootView(
            viewModel: initialViewModel ?? SearchViewModel(
                repository: dependencies.repository,
                likedMovieStore: dependencies.likedMovieStore,
                routeInput: routeInput
            ),
            router: router,
            shouldLoadOnAppear: shouldLoadOnAppear
        )
    }
}

private struct SearchRootView: View {
    let router: AppRouter

    @State private var viewModel: SearchViewModel
    @State private var activePicker: SearchPickerKind?
    @State private var shouldLoadOnAppear: Bool

    init(
        viewModel: SearchViewModel,
        router: AppRouter,
        shouldLoadOnAppear: Bool
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        _shouldLoadOnAppear = State(initialValue: shouldLoadOnAppear)
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            titleToolbar
            likedOnlyToolbar
        }
        .sheet(item: $activePicker, content: pickerSheet)
        .task {
            await loadIfNeeded()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                AppTheme.background,
                AppTheme.surface.opacity(0.96),
                Color.black.opacity(0.94),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                SearchFieldSection(
                    text: searchTextBinding,
                    onSubmit: submitSearch,
                    onClear: clearSearch
                )

                SearchFilterStrip(
                    uiState: viewModel.uiState,
                    onOpenPicker: openPicker
                )

                SearchResultsSection(
                    uiState: viewModel.uiState,
                    onOpenDetail: openDetail,
                    onPrevious: goToPreviousPage,
                    onNext: goToNextPage
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .overlay { overlayView }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.uiState.searchInputValue },
            set: { viewModel.onSearchTextChanged($0) }
        )
    }

    @ViewBuilder
    private var overlayView: some View {
        if let descriptor = viewModel.uiState.overlayDescriptor {
            if descriptor.isLoading {
                SearchOverlay(
                    descriptor: descriptor,
                    onRetry: refresh,
                    onSecondary: nil
                )
            } else {
                SearchOverlay(
                    descriptor: descriptor,
                    onRetry: refresh,
                    onSecondary: closeSearch
                )
            }
        }
    }

    private var titleToolbar: ToolbarItem<(), some View> {
        ToolbarItem(placement: .title) {
            Text(viewModel.uiState.screenTitle)
                .font(.largeTitle)
        }
    }

    private var likedOnlyToolbar: ToolbarItem<(), some View> {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: viewModel.toggleLikedOnly) {
                Image(systemName: viewModel.uiState.showLikedOnly ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.uiState.showLikedOnly ? Color.red.opacity(0.95) : AppTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        (viewModel.uiState.showLikedOnly ? Color.red.opacity(0.18) : Color.white.opacity(0.06)),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func pickerSheet(for picker: SearchPickerKind) -> some View {
        SearchPickerSheet(
            title: picker.title,
            options: viewModel.pickerOptions(for: picker),
            onSelect: { optionID in
                Task {
                    await handleSelection(optionID: optionID, for: picker)
                    activePicker = nil
                }
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func openPicker(_ picker: SearchPickerKind) {
        activePicker = picker
    }

    private func openDetail(_ movie: PhucTvMovieCard) {
        router.push(.detail(movie))
    }

    private func closeSearch() {
        router.pop()
    }

    private func submitSearch() {
        Task { await viewModel.submitSearch() }
    }

    private func clearSearch() {
        Task { await viewModel.clearSearch() }
    }

    private func refresh() {
        Task { await viewModel.refresh() }
    }

    private func goToPreviousPage() {
        Task { await viewModel.goToPage(viewModel.uiState.currentPage - 1) }
    }

    private func goToNextPage() {
        Task { await viewModel.goToPage(viewModel.uiState.currentPage + 1) }
    }

    private func loadIfNeeded() async {
        guard shouldLoadOnAppear else { return }
        await viewModel.load()
        shouldLoadOnAppear = false
    }

    private func handleSelection(optionID: String, for picker: SearchPickerKind) async {
        switch picker {
        case .category:
            let option = viewModel.uiState.filters.categoryOptionsWithAll()
                .first(where: { "category-\($0.id)-\($0.slug)" == optionID })
            await viewModel.selectCategory(option?.hasID == true ? option : nil)
        case .country:
            let option = viewModel.uiState.filters.countryOptionsWithAll()
                .first(where: { "country-\($0.id)-\($0.slug)" == optionID })
            await viewModel.selectCountry(option?.hasID == true ? option : nil)
        case .type:
            let option = searchTypeOptions.first(where: { "type-\($0.value)" == optionID })
            await viewModel.selectTypeRaw(option?.value.isEmpty == false ? option : nil)
        case .year:
            let option = searchYearOptions.first(where: { "year-\($0.value)" == optionID })
            await viewModel.selectYear(option?.value.isEmpty == false ? option : nil)
        case .order:
            let option = searchOrderOptions.first(where: { "order-\($0.value)" == optionID })
            if let option {
                await viewModel.selectOrderBy(option.value)
            }
        }
    }
}

private struct SearchOverlay: View {
    let descriptor: FeatureOverlayDescriptor
    let onRetry: () -> Void
    let onSecondary: (() -> Void)?

    var body: some View {
        FeatureStateOverlay(
            descriptor: descriptor,
            onRetry: onRetry,
            onSecondary: onSecondary
        )
        .background(Color.black.opacity(0.28).ignoresSafeArea())
    }
}

private struct SearchHeaderSection: View {
    let uiState: SearchUIState
    let onBack: () -> Void
    let onToggleLikedOnly: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Spacer()
            Text(uiState.screenTitle)
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer(minLength: 12)
        }
    }
}

private struct SearchFieldSection: View {
    @Binding var text: String
    let onSubmit: () -> Void
    let onClear: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textMuted)
            TextField("Search movies, series, or actors...", text: $text)
                .focused($isFocused)
                .submitLabel(.search)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textMuted)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.10 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isFocused ? Color.red.opacity(0.7) : AppTheme.border, lineWidth: isFocused ? 1.5 : 1)
        )
    }
}

private struct SearchFilterStrip: View {
    let uiState: SearchUIState
    let onOpenPicker: (SearchPickerKind) -> Void

    var body: some View {
        FlowWrapLayout(items: uiState.filterChips) { chip in
            Button(action: { onOpenPicker(chip.picker) }) {
                HStack(spacing: 8) {
                    Text(chip.title)
                        .font(AppTheme.captionFont.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(chip.value)
                        .font(AppTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(chip.isActive ? Color(red: 1.0, green: 0.74, blue: 0.70) : AppTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(chip.isActive ? 0.11 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(chip.isActive ? Color.red.opacity(0.28) : AppTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SearchResultsSection: View {
    let uiState: SearchUIState
    let onOpenDetail: (PhucTvMovieCard) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 16, alignment: .top)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Results")
                        .font(AppTheme.sectionTitleFont)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Showing \(uiState.totalVisibleCount) titles")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                if uiState.isSearching {
                    ProgressView()
                        .tint(AppTheme.textPrimary)
                }
                HStack(spacing: 10) {
                    SearchPageButton(icon: "chevron.left", enabled: uiState.canGoPrevious, action: onPrevious)
                    Text(pageLabel)
                        .font(AppTheme.captionFont.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(minWidth: 56)
                    SearchPageButton(icon: "chevron.right", enabled: uiState.canGoNext, action: onNext)
                }
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(uiState.visibleMovies) { movie in
                    MovieCardView(movie: movie) {
                        onOpenDetail(movie)
                    }
                    .aspectRatio(0.68, contentMode: .fit)
                }
            }
        }
    }

    private var pageLabel: String {
        guard uiState.totalPages > 0 else { return "Trang 1" }
        return "\(uiState.currentPage)/\(uiState.totalPages)"
    }
}

private struct SearchPageButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(enabled ? 0.08 : 0.04), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct SearchPickerSheet: View {
    let title: String
    let options: [SearchUIPickerOption]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    onSelect(option.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .foregroundStyle(AppTheme.textPrimary)
                            if !option.subtitle.isEmpty {
                                Text(option.subtitle)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        }
                        Spacer()
                        if option.isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(AppTheme.surface)
    }
}

#Preview("Search Loaded") {
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(
                repository: PreviewSearchRepository(),
                likedMovieStore: PreviewLikedMovieStore(),
                uiState: SearchUIState()
                    .withLoadedFilters(
                        PhucTvSearchFilterData(
                            categories: [
                                PhucTvSearchFacetOption(id: 1, name: "Action", slug: "action"),
                                PhucTvSearchFacetOption(id: 2, name: "Thriller", slug: "thriller"),
                            ],
                            countries: [
                                PhucTvSearchFacetOption(id: 10, name: "All Regions", slug: "all-regions"),
                                PhucTvSearchFacetOption(id: 11, name: "Korea", slug: "korea"),
                            ]
                        )
                    )
                    .withLikedMovies(Array(SearchPreviewData.movies.prefix(3)))
                    .withSearchResults(
                        PhucTvSearchResults(
                            records: SearchPreviewData.movies,
                            pagination: PhucTvSearchPagination(pageIndex: 1, pageSize: 12, pageCount: 2, totalRecords: 18)
                        ),
                        pageNumber: 1
                    )
            ),
            router: AppRouter()
        )
    }
}

private struct PreviewSearchRepository: PhucTvRepository {
    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { throw NSError(domain: "preview", code: 1) }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { throw NSError(domain: "preview", code: 1) }
    func loadSearchFilters() async throws -> PhucTvSearchFilterData { .init(categories: [], countries: []) }
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
        .init(records: SearchPreviewData.movies, pagination: .init(pageIndex: 1, pageSize: 12, pageCount: 1, totalRecords: SearchPreviewData.movies.count))
    }
    func loadEpisodeSources(movieID: Int, episodeID: Int, server: Int) async throws -> [PhucTvPlaySource] { [] }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private actor PreviewLikedMovieStore: PhucTvLikedMovieStoring {
    func loadMovies() async throws -> [PhucTvMovieCard] { Array(SearchPreviewData.movies.prefix(2)) }
    func loadIDs() async throws -> Set<Int> { Set(SearchPreviewData.movies.prefix(2).map(\.id)) }
    func isLiked(movieID: Int) async throws -> Bool { movieID == SearchPreviewData.movies.first?.id }
    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] { [movie] }
}

private enum SearchPreviewData {
    static let movies: [PhucTvMovieCard] = [
        previewMovie(id: 1, title: "Neon Genesis: Tokyo", subtitle: "2024 • Sci-Fi Thriller", rating: "8.4"),
        previewMovie(id: 2, title: "Velocity Horizon", subtitle: "2023 • Action", rating: "7.9"),
        previewMovie(id: 3, title: "The Last Whisper", subtitle: "2024 • Mystery", rating: "9.1"),
        previewMovie(id: 4, title: "Skyward Kingdom", subtitle: "2024 • Fantasy", rating: "8.7"),
        previewMovie(id: 5, title: "Before the Tide", subtitle: "2023 • Romance", rating: "7.5"),
        previewMovie(id: 6, title: "Shadow Grove", subtitle: "2024 • Horror", rating: "6.8"),
    ]

    static func previewMovie(id: Int, title: String, subtitle: String, rating: String) -> PhucTvMovieCard {
        PhucTvMovieCard(
            id: id,
            name: title,
            otherName: subtitle,
            avatar: "",
            bannerThumb: "",
            avatarThumb: "",
            description: subtitle,
            banner: "",
            imageIcon: "",
            link: "movie-\(id)",
            quantity: "",
            rating: rating,
            year: 2024,
            statusTitle: subtitle,
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
