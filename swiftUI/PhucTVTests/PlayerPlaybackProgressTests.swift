import XCTest
@testable import PhucTV

@MainActor
final class PlayerPlaybackProgressTests: XCTestCase {
    func testLoadUsesRemoteProgressWithoutConsultingLocalStore() async {
        let localStore = RecordingPlaybackStore(
            loadResult: PhucTvPlaybackProgressSnapshot(positionMillis: 90_000, durationMillis: 120_000)
        )
        let remoteStore = RecordingPlaybackStore(
            loadResult: PhucTvPlaybackProgressSnapshot(positionMillis: 30_000, durationMillis: 120_000)
        )
        let viewModel = PlayerViewModel(
            movieID: 1,
            episodeID: 1,
            movieTitle: "Movie",
            episodeLabel: "Episode 1",
            repository: StubPlayerRepository(
                sources: [
                    makeSource(
                        sourceId: 1,
                        link: "https://example.com/stream.m3u8",
                        tracks: []
                    )
                ]
            ),
            localStore: localStore,
            remoteStore: remoteStore,
            subtitleLoader: StubSubtitleLoader()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.currentPositionMillis, 30_000)
        let localLoadCount = await localStore.loadCount()
        let remoteLoadCount = await remoteStore.loadCount()
        XCTAssertEqual(localLoadCount, 0)
        XCTAssertEqual(remoteLoadCount, 1)
    }

    func testSelectSourceSyncsCurrentProgressBeforeReload() async {
        let localStore = RecordingPlaybackStore()
        let remoteStore = RecordingPlaybackStore()
        let viewModel = PlayerViewModel(
            movieID: 1,
            episodeID: 1,
            movieTitle: "Movie",
            episodeLabel: "Episode 1",
            repository: StubPlayerRepository(
                sources: [
                    makeSource(
                        sourceId: 1,
                        link: "https://example.com/stream-1.m3u8",
                        tracks: []
                    ),
                    makeSource(
                        sourceId: 2,
                        link: "https://example.com/stream-2.m3u8",
                        tracks: []
                    )
                ]
            ),
            localStore: localStore,
            remoteStore: remoteStore,
            subtitleLoader: StubSubtitleLoader()
        )
        viewModel.sources = [
            makeSource(sourceId: 1, link: "https://example.com/stream-1.m3u8", tracks: []),
            makeSource(sourceId: 2, link: "https://example.com/stream-2.m3u8", tracks: [])
        ]
        viewModel.selectedSourceIndex = 0
        viewModel.currentPositionMillis = 45_000
        viewModel.durationMillis = 90_000

        viewModel.selectSource(1)
        for _ in 0..<20 {
            let localSaveCount = await localStore.saveCount()
            let remoteSaveCount = await remoteStore.saveCount()
            if localSaveCount == 1 && remoteSaveCount == 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let localSaveCount = await localStore.saveCount()
        let remoteSaveCount = await remoteStore.saveCount()
        let remoteSavedPosition = await remoteStore.savedSnapshots().first?.positionMillis
        XCTAssertEqual(localSaveCount, 1)
        XCTAssertEqual(remoteSaveCount, 1)
        XCTAssertEqual(remoteSavedPosition, 45_000)
    }

    private func makeSource(
        sourceId: Int,
        link: String,
        tracks: [PhucTvPlayTrack]
    ) -> PhucTvPlaySource {
        PhucTvPlaySource(
            sourceId: sourceId,
            serverName: "Server \(sourceId)",
            link: link,
            subtitle: "",
            type: 0,
            isFrame: false,
            quality: "1080p",
            tracks: tracks
        )
    }
}

private struct StubPlayerRepository: PhucTvRepository {
    let sources: [PhucTvPlaySource]

    init(sources: [PhucTvPlaySource] = []) {
        self.sources = sources
    }

    func loadHome() async throws -> [PhucTvHomeSection] { [] }
    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { DetailMockData.detail }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { DetailMockData.detail }
    func loadSearchFilters() async throws -> PhucTvSearchFilterData { PhucTvSearchFilterData(categories: [], countries: []) }
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
        PhucTvSearchResults(records: [], pagination: PhucTvSearchPagination(pageIndex: 1, pageSize: 1, pageCount: 1, totalRecords: 0))
    }
    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [PhucTvPlaySource] { sources }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private struct StubSubtitleLoader: PlayerSubtitleLoading {
    func loadCues(for track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue] {
        []
    }
}

private actor RecordingPlaybackStore: PhucTvPlaybackPositionStoring {
    private let loadResult: PhucTvPlaybackProgressSnapshot?
    private(set) var saveCallCount = 0
    private(set) var loadCallCount = 0
    private(set) var deleteCallCount = 0
    private var savedRows: [(movieID: Int, episodeID: Int, positionMillis: Int64, durationMillis: Int64)] = []

    init(loadResult: PhucTvPlaybackProgressSnapshot? = nil) {
        self.loadResult = loadResult
    }

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
        saveCallCount += 1
        savedRows.append((movieID, episodeID, positionMillis, durationMillis))
    }

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        loadCallCount += 1
        return loadResult
    }

    func delete(movieID: Int, episodeID: Int) async throws {
        deleteCallCount += 1
    }

    func saveCount() -> Int {
        saveCallCount
    }

    func loadCount() -> Int {
        loadCallCount
    }

    func savedSnapshots() -> [PhucTvPlaybackProgressSnapshot] {
        savedRows.map { row in
            PhucTvPlaybackProgressSnapshot(
                positionMillis: row.positionMillis,
                durationMillis: row.durationMillis
            )
        }
    }
}
