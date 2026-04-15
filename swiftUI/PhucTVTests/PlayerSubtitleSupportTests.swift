import XCTest
@testable import PhucTV

final class PlayerSubtitleSupportTests: XCTestCase {
    func testDecodeVTTCues() throws {
        let data = Data("""
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Hello world

        00:00:04.000 --> 00:00:05.500
        Next line
        """.utf8)

        let cues = try PlayerSubtitleLoader.decodeCues(from: data, fileExtension: "vtt")

        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0], PlayerSubtitleCue(startMillis: 1000, endMillis: 3000, text: "Hello world"))
        XCTAssertEqual(cues[1], PlayerSubtitleCue(startMillis: 4000, endMillis: 5500, text: "Next line"))
    }

    func testDecodeSRTCuesPreservesLineBreaks() throws {
        let data = Data("""
        1
        00:00:02,000 --> 00:00:04,000
        Line one
        Line two
        """.utf8)

        let cues = try PlayerSubtitleLoader.decodeCues(from: data, fileExtension: "srt")

        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].text, "Line one\nLine two")
    }

    func testResolverReturnsCueInsideRangeAndNilInGap() {
        let cues = [
            PlayerSubtitleCue(startMillis: 1000, endMillis: 3000, text: "First"),
            PlayerSubtitleCue(startMillis: 5000, endMillis: 7000, text: "Second"),
        ]

        let first = PlayerSubtitleResolver.resolve(positionMillis: 1800, cues: cues, hintIndex: nil)
        XCTAssertEqual(first.cueIndex, 0)
        XCTAssertEqual(first.text, "First")

        let gap = PlayerSubtitleResolver.resolve(positionMillis: 4200, cues: cues, hintIndex: first.cueIndex)
        XCTAssertNil(gap.cueIndex)
        XCTAssertNil(gap.text)

        let second = PlayerSubtitleResolver.resolve(positionMillis: 6200, cues: cues, hintIndex: gap.cueIndex)
        XCTAssertEqual(second.cueIndex, 1)
        XCTAssertEqual(second.text, "Second")
    }

    func testResolverCombinesAllOverlappingCueTextAtSamePosition() {
        let cues = [
            PlayerSubtitleCue(startMillis: 0, endMillis: 10_000, text: "[Music]"),
            PlayerSubtitleCue(startMillis: 2_000, endMillis: 4_000, text: "Hello there"),
            PlayerSubtitleCue(startMillis: 6_000, endMillis: 8_000, text: "Another line"),
        ]

        let overlapping = PlayerSubtitleResolver.resolve(positionMillis: 2_500, cues: cues, hintIndex: nil)
        XCTAssertEqual(overlapping.cueIndex, 1)
        XCTAssertEqual(overlapping.text, "[Music]\nHello there")

        let laterOverlap = PlayerSubtitleResolver.resolve(positionMillis: 6_500, cues: cues, hintIndex: overlapping.cueIndex)
        XCTAssertEqual(laterOverlap.cueIndex, 2)
        XCTAssertEqual(laterOverlap.text, "[Music]\nAnother line")
    }
}

@MainActor
final class PlayerViewModelSubtitleTests: XCTestCase {
    func testLoadRetainsIframeSourcesWhenDirectStreamsAreMissing() async {
        let iframeSource = makeSource(
            sourceId: 99,
            subtitle: "",
            tracks: [],
            isFrame: true,
            link: "https://example.com/embed-99"
        )
        let viewModel = makeViewModel(repositorySources: [iframeSource])

        await viewModel.load()

        if case .error = viewModel.state {
        } else {
            XCTFail("Expected iframe-only load to produce an error state.")
        }

        XCTAssertEqual(viewModel.sources.count, 1)
        XCTAssertEqual(viewModel.iframeSources.count, 1)
        XCTAssertTrue(viewModel.playableSources.isEmpty)
        XCTAssertTrue(viewModel.hasIframeOnlySources)
        XCTAssertEqual(viewModel.sources.first?.link, "https://example.com/embed-99")
        XCTAssertTrue(viewModel.errorMessage?.contains("iframe") ?? false)
    }

    func testApplyTrackSelectionDefaultsFallsBackToFirstSubtitleTrack() {
        let viewModel = makeViewModel()
        let fallbackTrack = makeTrack(kind: "subtitle", file: "https://example.com/fallback.vtt", label: "Fallback", isDefault: false)
        let source = makeSource(
            sourceId: 1,
            subtitle: "",
            tracks: [fallbackTrack]
        )

        viewModel.sources = [source]
        viewModel.selectedSourceIndex = 0

        viewModel.applyTrackSelectionDefaultsForSelectedSource()

        XCTAssertEqual(viewModel.selectedSubtitleTrack?.displayLabel, "Fallback")
        XCTAssertTrue(viewModel.hasSubtitleTracks)
        XCTAssertTrue(viewModel.isSubtitleEnabled)
    }

    func testToggleSubtitleClearsAndRestoresDefaultTrack() async {
        let track = makeTrack(kind: "subtitle", file: "https://example.com/default.vtt", label: "Default", isDefault: true)
        let viewModel = makeViewModel(loader: StubSubtitleLoader(cues: [
            PlayerSubtitleCue(startMillis: 0, endMillis: 1_000, text: "Hello"),
        ]))
        viewModel.sources = [makeSource(sourceId: 1, subtitle: "", tracks: [track])]
        viewModel.selectedSourceIndex = 0
        viewModel.selectedSubtitleTrack = track
        viewModel.currentSubtitleText = "Visible"

        viewModel.toggleSubtitle()

        XCTAssertNil(viewModel.selectedSubtitleTrack)
        XCTAssertNil(viewModel.currentSubtitleText)

        viewModel.toggleSubtitle()
        await Task.yield()

        XCTAssertEqual(viewModel.selectedSubtitleTrack?.displayLabel, "Default")
    }

    func testSelectSourceWithoutSubtitleClearsSubtitleState() {
        let subtitleTrack = makeTrack(kind: "subtitle", file: "https://example.com/sub.vtt", label: "VI", isDefault: true)
        let viewModel = makeViewModel()
        viewModel.sources = [
            makeSource(sourceId: 1, subtitle: "", tracks: [subtitleTrack]),
            makeSource(sourceId: 2, subtitle: "", tracks: []),
        ]
        viewModel.selectedSourceIndex = 0
        viewModel.selectedSubtitleTrack = subtitleTrack
        viewModel.currentSubtitleText = "Existing subtitle"

        viewModel.selectSource(1)

        XCTAssertEqual(viewModel.selectedSource?.sourceId, 2)
        XCTAssertNil(viewModel.selectedSubtitleTrack)
        XCTAssertNil(viewModel.currentSubtitleText)
        XCTAssertFalse(viewModel.hasSubtitleTracks)
    }

    func testActionButtonTitleUsesServerNameFallback() {
        let namedSource = makeSource(
            sourceId: 1,
            serverName: "Server A",
            subtitle: "",
            tracks: [],
            isFrame: true,
            link: "https://example.com/embed-a"
        )
        let unnamedSource = makeSource(
            sourceId: 2,
            serverName: "   ",
            subtitle: "",
            tracks: [],
            isFrame: true,
            link: "https://example.com/embed-b",
            quality: "1080p"
        )

        XCTAssertEqual(namedSource.actionButtonTitle, "Server A")
        XCTAssertTrue(unnamedSource.actionButtonTitle.contains("iframe"))
    }

    private func makeViewModel(
        loader: PlayerSubtitleLoading = StubSubtitleLoader(),
        repositorySources: [PhucTvPlaySource] = []
    ) -> PlayerViewModel {
        PlayerViewModel(
            movieID: 1,
            episodeID: 1,
            movieTitle: "Movie",
            episodeLabel: "Episode 1",
            repository: StubPlayerRepository(sources: repositorySources),
            localStore: StubPlaybackStore(),
            remoteStore: nil,
            subtitleLoader: loader
        )
    }

    private func makeSource(
        sourceId: Int,
        serverName: String = "",
        subtitle: String,
        tracks: [PhucTvPlayTrack],
        isFrame: Bool = false,
        link: String = "",
        quality: String = ""
    ) -> PhucTvPlaySource {
        PhucTvPlaySource(
            sourceId: sourceId,
            serverName: serverName.isEmpty ? "Server \(sourceId)" : serverName,
            link: link.isEmpty ? "https://example.com/\(sourceId).m3u8" : link,
            subtitle: subtitle,
            type: 0,
            isFrame: isFrame,
            quality: quality.isEmpty ? "1080p" : quality,
            tracks: tracks
        )
    }

    private func makeTrack(
        kind: String,
        file: String,
        label: String,
        isDefault: Bool
    ) -> PhucTvPlayTrack {
        PhucTvPlayTrack(
            kind: kind,
            file: file,
            label: label,
            isDefault: isDefault
        )
    }
}

private struct StubSubtitleLoader: PlayerSubtitleLoading {
    var cues: [PlayerSubtitleCue] = []

    func loadCues(for track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue] {
        cues
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

private struct StubPlaybackStore: PhucTvPlaybackPositionStoring {
    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
    }

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        nil
    }
}
