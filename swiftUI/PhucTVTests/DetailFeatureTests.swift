import ComposableArchitecture
import Foundation
import Testing

@testable import PhucTV

@MainActor
struct DetailFeatureTests {
    init() {
        uncheckedUseMainSerialExecutor = true
    }

    @Test
    func detailLoadSuccessSeedsDetailLikedStateAndProgress() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail)
        let likedStore = DetailLikedMovieStoreSpy(initialLikedIDs: [DetailMockData.detail.id])
        let playbackStore = DetailPlaybackStoreSpy(
            snapshotsByEpisodeID: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
                2: PhucTvPlaybackProgressSnapshot(positionMillis: 0, durationMillis: 600_000),
            ]
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: likedStore,
            playbackPositionStore: playbackStore
        )

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.receive(.loadResponse(.success(.init(
            detail: DetailMockData.detail,
            isLiked: true,
            episodeProgressById: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
                2: PhucTvPlaybackProgressSnapshot(positionMillis: 0, durationMillis: 600_000),
            ]
        )))) {
            $0.detail = DetailMockData.detail
            $0.screenState = .loaded
            $0.selectedTab = DetailMockData.detail.defaultTab
            $0.isLiked = true
            $0.episodeProgressById = [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
                2: PhucTvPlaybackProgressSnapshot(positionMillis: 0, durationMillis: 600_000),
            ]
        }

        #expect(store.state.title == DetailMockData.detail.title)
        #expect(store.state.subtitle == DetailMockData.detail.otherName)
        #expect(store.state.summary == DetailMockData.detail.description)
        #expect(store.state.availableTabs == DetailMockData.detail.availableTabs)
        #expect(store.state.effectiveSelectedTab == DetailMockData.detail.defaultTab)
        #expect(repository.loadDetailCount == 1)
        #expect(await likedStore.isLikedCountValue() == 1)
        #expect(await playbackStore.loadCountValue() == DetailMockData.detail.episodes.count)
    }

    @Test
    func detailLoadFailureSetsErrorState() async {
        let repository = DetailRepositorySpy(loadDetailResult: .failure(StubError.failed))
        let store = makeStore(repository: repository)

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.receive(.loadResponse(.failure(.init(StubError.failed)))) {
            $0.screenState = .error(message: "failed")
        }

        #expect(repository.loadDetailCount == 1)
        #expect(store.state.detail == nil)
    }

    @Test
    func detailRetryCancelsInFlightLoadAndReloads() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail, firstLoadDelayNanoseconds: 1_000_000_000)
        let likedStore = DetailLikedMovieStoreSpy(initialLikedIDs: [DetailMockData.detail.id])
        let playbackStore = DetailPlaybackStoreSpy(
            snapshotsByEpisodeID: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
            ]
        )
        let store = makeStore(
            repository: repository,
            likedMovieStore: likedStore,
            playbackPositionStore: playbackStore
        )

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.send(.retryTapped)

        await store.receive(.loadResponse(.success(.init(
            detail: DetailMockData.detail,
            isLiked: true,
            episodeProgressById: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
            ]
        )))) {
            $0.detail = DetailMockData.detail
            $0.screenState = .loaded
            $0.selectedTab = DetailMockData.detail.defaultTab
            $0.isLiked = true
            $0.episodeProgressById = [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
            ]
        }

        #expect(repository.loadDetailCount == 2)
        #expect(repository.cancelledSlugs == [DetailMockData.movie.link])
    }

    @Test
    func onAppearWhenLoadedRefreshesProgress() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail)
        let playbackStore = DetailPlaybackStoreSpy(
            snapshotsByEpisodeID: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
            ]
        )
        var loadedState = DetailFeature.State(movie: DetailMockData.movie)
        loadedState.detail = DetailMockData.detail
        loadedState.screenState = .loaded
        loadedState.selectedTab = .episodes
        let store = makeStore(
            repository: repository,
            likedMovieStore: DetailLikedMovieStoreSpy(),
            playbackPositionStore: playbackStore,
            state: loadedState
        )

        await store.send(.onAppear)

        await store.receive(.refreshEpisodeProgress)

        await store.receive(.episodeProgressResponse([
            1: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
        ])) {
            $0.episodeProgressById = [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
            ]
        }

        #expect(repository.loadDetailCount == 0) // Did not reload detail
        #expect(await playbackStore.loadCountValue() == DetailMockData.detail.episodes.count)
    }

    @Test
    func likeToggleUpdatesLikedStateAfterStoreMutation() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail)
        let likedStore = DetailLikedMovieStoreSpy(initialLikedIDs: [])
        let store = makeStore(
            repository: repository,
            likedMovieStore: likedStore,
            playbackPositionStore: DetailPlaybackStoreSpy()
        )

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.receive(.loadResponse(.success(.init(
            detail: DetailMockData.detail,
            isLiked: false,
            episodeProgressById: [:]
        )))) {
            $0.detail = DetailMockData.detail
            $0.screenState = .loaded
            $0.selectedTab = DetailMockData.detail.defaultTab
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.send(.likeToggled)

        await store.receive(.likeToggleResponse(.success(true))) {
            $0.isLiked = true
        }

        #expect(await likedStore.toggleCountValue() == 1)
        #expect(await likedStore.isLikedCountValue() == 2)
        #expect(store.state.isLiked == true)
    }

    @Test
    func tabSelectionAcceptsValidTabsAndIgnoresInvalidTabs() async {
        let movie = DetailMockData.movie
        let detail = PhucTvMovieDetail(
            movie: PhucTvMovieCard(
                id: movie.id,
                name: movie.name,
                otherName: movie.otherName,
                avatar: movie.avatar,
                bannerThumb: movie.bannerThumb,
                avatarThumb: movie.avatarThumb,
                description: movie.description,
                banner: movie.banner,
                imageIcon: movie.imageIcon,
                link: movie.link,
                quantity: movie.quantity,
                rating: movie.rating,
                year: movie.year,
                statusTitle: movie.statusTitle,
                statusRaw: movie.statusRaw,
                statusText: movie.statusText,
                director: movie.director,
                time: movie.time,
                trailer: movie.trailer,
                showTimes: movie.showTimes,
                moreInfo: movie.moreInfo,
                castString: movie.castString,
                episodesTotal: movie.episodesTotal,
                viewNumber: movie.viewNumber,
                ratePoint: movie.ratePoint,
                photoUrls: [],
                previewPhotoUrls: []
            ),
            relatedMovies: [],
            countries: [],
            categories: [],
            episodes: [
                PhucTvMovieEpisode(id: 1, episodeNumber: "1", name: "Episode 1", fullLink: "ep-1", status: "1", type: "sub")
            ]
        )

        let store = makeStore(
            repository: DetailRepositorySpy(detail: detail),
            likedMovieStore: DetailLikedMovieStoreSpy(),
            playbackPositionStore: DetailPlaybackStoreSpy()
        )

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.receive(.loadResponse(.success(.init(
            detail: detail,
            isLiked: false,
            episodeProgressById: [:]
        )))) {
            $0.detail = detail
            $0.screenState = .loaded
            $0.selectedTab = detail.defaultTab
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.send(.tabSelected(.synopsis)) {
            $0.selectedTab = .synopsis
        }

        await store.send(.tabSelected(.gallery))

        #expect(store.state.selectedTab == .synopsis)
        #expect(store.state.effectiveSelectedTab == .synopsis)
    }

    @Test
    func episodeProgressRefreshUpdatesState() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail)
        let playbackStore = DetailPlaybackStoreSpy(
            snapshotsByEpisodeID: [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
                2: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
            ]
        )
        var loadedState = DetailFeature.State(movie: DetailMockData.movie)
        loadedState.detail = DetailMockData.detail
        loadedState.screenState = .loaded
        loadedState.selectedTab = .episodes
        let store = makeStore(
            repository: repository,
            likedMovieStore: DetailLikedMovieStoreSpy(),
            playbackPositionStore: playbackStore,
            state: loadedState
        )

        await store.send(.refreshEpisodeProgress)

        await store.receive(.episodeProgressResponse([
            1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
            2: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
        ])) {
            $0.episodeProgressById = [
                1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000),
                2: PhucTvPlaybackProgressSnapshot(positionMillis: 240_000, durationMillis: 600_000)
            ]
        }

        #expect(await playbackStore.loadCountValue() == DetailMockData.detail.episodes.count)
        #expect(store.state.episodeProgressById.count == 2)
    }

    @Test
    func playEpisodeIntentDoesNotMutateState() async {
        let repository = DetailRepositorySpy(detail: DetailMockData.detail)
        let store = makeStore(
            repository: repository,
            likedMovieStore: DetailLikedMovieStoreSpy(),
            playbackPositionStore: DetailPlaybackStoreSpy()
        )

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.detail = nil
            $0.selectedTab = nil
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        await store.receive(.loadResponse(.success(.init(
            detail: DetailMockData.detail,
            isLiked: false,
            episodeProgressById: [:]
        )))) {
            $0.detail = DetailMockData.detail
            $0.screenState = .loaded
            $0.selectedTab = DetailMockData.detail.defaultTab
            $0.isLiked = false
            $0.episodeProgressById = [:]
        }

        let before = store.state
        await store.send(.playEpisodeTapped(DetailMockData.detail.episodes[0]))
        #expect(store.state == before)
    }

    private func makeStore(
        repository: DetailRepositorySpy = DetailRepositorySpy(detail: DetailMockData.detail),
        likedMovieStore: DetailLikedMovieStoreSpy = DetailLikedMovieStoreSpy(),
        playbackPositionStore: DetailPlaybackStoreSpy = DetailPlaybackStoreSpy(),
        state: DetailFeature.State = DetailFeature.State(movie: DetailMockData.movie)
    ) -> TestStore<DetailFeature.State, DetailFeature.Action> {
        TestStore(initialState: state) {
            DetailFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(
                AppDependencies.test(
                    repository: repository,
                    likedMovieStore: likedMovieStore,
                    playbackPositionStore: playbackPositionStore
                )
            )
        }
    }
}

private final class DetailRepositorySpy: PhucTvRepository, @unchecked Sendable {
    private var loadDetailResults: [Swift.Result<PhucTvMovieDetail, Error>]
    let detail: PhucTvMovieDetail?
    let firstLoadDelayNanoseconds: UInt64?
    private(set) var loadDetailCount = 0
    private(set) var cancelledSlugs: [String] = []
    private(set) var slugs: [String] = []

    init(
        detail: PhucTvMovieDetail? = nil,
        loadDetailResult: Swift.Result<PhucTvMovieDetail, Error>? = nil,
        firstLoadDelayNanoseconds: UInt64? = nil
    ) {
        self.detail = detail
        self.firstLoadDelayNanoseconds = firstLoadDelayNanoseconds

        if let loadDetailResult {
            self.loadDetailResults = [loadDetailResult]
        } else if let detail {
            self.loadDetailResults = [.success(detail)]
        } else {
            self.loadDetailResults = []
        }
    }

    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }

    func loadDetail(slug: String) async throws -> PhucTvMovieDetail {
        loadDetailCount += 1
        slugs.append(slug)

        if loadDetailCount == 1, let firstLoadDelayNanoseconds {
            do {
                try await Task.sleep(nanoseconds: firstLoadDelayNanoseconds)
            } catch is CancellationError {
                cancelledSlugs.append(slug)
                throw CancellationError()
            }
        }

        guard !loadDetailResults.isEmpty else {
            throw StubError.failed
        }

        return try loadDetailResults.removeFirst().get()
    }

    func loadPreview(slug: String) async throws -> PhucTvMovieDetail {
        try await loadDetail(slug: slug)
    }

    func loadSearchFilters() async throws -> PhucTvSearchFilterData {
        .init(categories: [], countries: [])
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
        .init(records: [], pagination: .init(pageIndex: 1, pageSize: 20, pageCount: 1, totalRecords: 0))
    }

    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [PhucTvPlaySource] {
        []
    }

    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private actor DetailLikedMovieStoreSpy: PhucTvLikedMovieStoring {
    private var likedMovieIDs: Set<Int>
    private(set) var toggleCount = 0
    private(set) var isLikedCount = 0

    init(initialLikedIDs: Set<Int> = []) {
        self.likedMovieIDs = initialLikedIDs
    }

    func loadMovies() async throws -> [PhucTvMovieCard] {
        []
    }

    func loadIDs() async throws -> Set<Int> {
        likedMovieIDs
    }

    func isLiked(movieID: Int) async throws -> Bool {
        isLikedCount += 1
        return likedMovieIDs.contains(movieID)
    }

    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] {
        toggleCount += 1
        if likedMovieIDs.contains(movie.id) {
            likedMovieIDs.remove(movie.id)
        } else {
            likedMovieIDs.insert(movie.id)
        }
        return likedMovieIDs.map { id in
            PhucTvMovieCard(
                id: id,
                name: "Movie \(id)",
                otherName: "",
                avatar: "",
                bannerThumb: "",
                avatarThumb: "",
                description: "",
                banner: "",
                imageIcon: "",
                link: "",
                quantity: "",
                rating: "",
                year: 0,
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

    func toggleCountValue() -> Int {
        toggleCount
    }

    func isLikedCountValue() -> Int {
        isLikedCount
    }
}

private actor DetailPlaybackStoreSpy: PhucTvPlaybackPositionStoring {
    private let snapshotsByEpisodeID: [Int: PhucTvPlaybackProgressSnapshot?]
    private(set) var loadCount = 0

    init(snapshotsByEpisodeID: [Int: PhucTvPlaybackProgressSnapshot?] = [:]) {
        self.snapshotsByEpisodeID = snapshotsByEpisodeID
    }

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {}

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        loadCount += 1
        return snapshotsByEpisodeID[episodeID] ?? nil
    }

    func loadCountValue() -> Int {
        loadCount
    }
}

private enum StubError: Error {
    case failed
}
