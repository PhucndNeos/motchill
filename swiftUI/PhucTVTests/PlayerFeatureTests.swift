import AVFoundation
import ComposableArchitecture
import XCTest
@testable import PhucTV

@MainActor
final class PlayerFeatureTests: XCTestCase {
    func testLoadSuccessUsesResumeProgressAndKeepsPlayerIdentity() async {
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream-1080.m3u8",
            tracks: []
        )
        let repository = PlayerRepositorySpy(sources: [source])
        let remoteStore = RecordingPlaybackStore(
            loadResult: PhucTvPlaybackProgressSnapshot(positionMillis: 30_000, durationMillis: 120_000)
        )
        let store = makeStore(
            repository: repository,
            remoteStore: remoteStore
        )

        let player = store.state.player

        await store.send(.onAppear) {
            $0.screenState = .loading
            $0.sources = []
            $0.selectedSourceIndex = 0
            $0.selectedAudioTrack = nil
            $0.selectedSubtitleTrack = nil
            $0.currentPositionMillis = 0
            $0.durationMillis = 0
            $0.isPlaying = false
            $0.overlayVisible = true
            $0.currentSubtitleText = nil
        }

        await store.receive(.loadResponse(.success(.init(
            sources: [source],
            resumePositionMillis: 30_000
        )))) {
            $0.sources = [source]
            $0.selectedSourceIndex = 0
            $0.currentPositionMillis = 30_000
            $0.screenState = .loaded
            $0.overlayVisible = true
            $0.isPlaying = true
        }

        await store.receive(.showOverlayTemporarily)

        XCTAssertTrue(store.state.player === player)

        await store.send(.backButtonTapped) {
            $0.isPlaying = false
            $0.overlayVisible = false
            $0.currentSubtitleText = nil
            $0.selectedSubtitleTrack = nil
        }

        await store.receive(.closeRequested)

        let repositoryLoadCount = await repository.loadCount()
        let remoteLoadCount = await remoteStore.loadCount()
        let remoteSaveCount = await remoteStore.saveCount()

        XCTAssertEqual(repositoryLoadCount, 1)
        XCTAssertEqual(remoteLoadCount, 1)
        XCTAssertEqual(remoteSaveCount, 0)
    }

    func testLoadFailureProducesErrorState() async {
        let repository = PlayerRepositorySpy(error: StubError.failed)
        let store = makeStore(repository: repository)

        await store.send(.onAppear) {
            $0.screenState = .loading
        }

        await store.receive(.loadResponse(.failure(.init(StubError.failed)))) {
            $0.screenState = .error(message: "failed")
        }

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
        }

        await store.receive(.closeRequested)
    }

    func testRetryCancelsInFlightLoad() async {
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream-1080.m3u8",
            tracks: []
        )
        let repository = PlayerRepositorySpy(
            sources: [source, source],
            delayNanoseconds: 100_000_000
        )
        let store = makeStore(repository: repository)

        await store.send(.onAppear) {
            $0.screenState = .loading
        }

        await store.send(.retryTapped)

        await store.receive(.loadResponse(.success(.init(
            sources: [source],
            resumePositionMillis: 0
        )))) {
            $0.sources = [source]
            $0.screenState = .loaded
            $0.overlayVisible = true
            $0.isPlaying = true
        }

        await store.receive(.showOverlayTemporarily)

        let retryLoadCount = await repository.loadCount()
        let cancelledLoadCount = await repository.cancelledLoadCount()

        XCTAssertGreaterThanOrEqual(retryLoadCount, 2)
        XCTAssertGreaterThanOrEqual(cancelledLoadCount, 1)

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
        }

        await store.receive(.closeRequested)
    }

    func testSourceSelectionPersistsProgressBeforeReload() async {
        let firstSource = makeSource(
            sourceId: 1,
            link: "https://example.com/stream-1.m3u8",
            tracks: []
        )
        let secondSource = makeSource(
            sourceId: 2,
            link: "https://example.com/stream-2.m3u8",
            tracks: []
        )
        let remoteStore = RecordingPlaybackStore()
        let store = makeStore(
            repository: PlayerRepositorySpy(sources: [firstSource, secondSource]),
            remoteStore: remoteStore,
            state: makeLoadedState(
                sources: [firstSource, secondSource],
                selectedSourceIndex: 0,
                currentPositionMillis: 45_000,
                durationMillis: 90_000,
                isPlaying: true
            )
        )
        let player = store.state.player

        await store.send(.sourceSelected(secondSource)) {
            $0.selectedSourceIndex = 1
            $0.isPlaying = true
            $0.currentSubtitleText = nil
            $0.selectedSubtitleTrack = nil
        }

        await store.receive(.showOverlayTemporarily)

        XCTAssertTrue(store.state.player === player)

        try? await Task.sleep(nanoseconds: 150_000_000)

        let remoteSaveCount = await remoteStore.saveCount()
        let remoteLoadCount = await remoteStore.loadCount()

        XCTAssertEqual(remoteLoadCount, 1)
        XCTAssertEqual(remoteSaveCount, 1)

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
        }

        await store.receive(.closeRequested)
    }

    func testSubtitleSelectionLoadsCuesAndUpdatesSubtitleText() async {
        let track = makeTrack(kind: "subtitle", file: "https://example.com/sub.vtt", label: "English", isDefault: true)
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream.m3u8",
            tracks: [track]
        )
        let loader = SubtitleLoaderSpy(cues: [
            PlayerSubtitleCue(startMillis: 1_000, endMillis: 3_000, text: "Hello world")
        ])
        let store = makeStore(
            repository: PlayerRepositorySpy(sources: [source]),
            subtitleLoader: loader,
            state: makeLoadedState(
                sources: [source],
                selectedSourceIndex: 0,
                currentPositionMillis: 1_500,
                durationMillis: 120_000,
                isPlaying: true
            )
        )

        await store.send(.subtitleSelected(track)) {
            $0.selectedSubtitleTrack = track
            $0.currentSubtitleText = nil
        }

        await store.receive(.subtitleLoaded(.success(.init(
            track: track,
            cues: [PlayerSubtitleCue(startMillis: 1_000, endMillis: 3_000, text: "Hello world")]
        )))) {
            $0.currentSubtitleText = "Hello world"
        }

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
            $0.selectedSubtitleTrack = nil
            $0.currentSubtitleText = nil
        }

        await store.receive(.closeRequested)
    }

    func testOverlayTapTogglesVisibility() async {
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream.m3u8",
            tracks: []
        )
        let store = makeStore(
            repository: PlayerRepositorySpy(sources: [source]),
            state: makeLoadedState(
                sources: [source],
                selectedSourceIndex: 0,
                currentPositionMillis: 0,
                durationMillis: 120_000,
                isPlaying: true
            )
        )

        await store.send(.overlayTapped) {
            $0.overlayVisible = false
        }

        await store.send(.overlayTapped)

        await store.receive(.showOverlayTemporarily) {
            $0.overlayVisible = true
        }

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
        }

        await store.receive(.closeRequested)
    }

    func testPlayPausePauseSyncsProgressToRemote() async {
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream.m3u8",
            tracks: []
        )
        let remoteStore = RecordingPlaybackStore()
        let store = makeStore(
            repository: PlayerRepositorySpy(sources: [source]),
            remoteStore: remoteStore,
            state: makeLoadedState(
                sources: [source],
                selectedSourceIndex: 0,
                currentPositionMillis: 11_000,
                durationMillis: 120_000,
                isPlaying: true
            )
        )

        await store.send(.playPauseTapped) {
            $0.isPlaying = false
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let remoteLoadCount = await remoteStore.loadCount()
        let remoteSaveCount = await remoteStore.saveCount()

        XCTAssertEqual(remoteLoadCount, 1)
        XCTAssertEqual(remoteSaveCount, 1)
    }

    func testBackButtonCleansTransientRuntime() async {
        let track = makeTrack(kind: "subtitle", file: "https://example.com/sub.vtt", label: "English", isDefault: true)
        let source = makeSource(
            sourceId: 1,
            link: "https://example.com/stream.m3u8",
            tracks: [track]
        )
        let remoteStore = RecordingPlaybackStore()
        let store = makeStore(
            repository: PlayerRepositorySpy(sources: [source]),
            remoteStore: remoteStore,
            state: makeLoadedState(
                sources: [source],
                selectedSourceIndex: 0,
                currentPositionMillis: 1_500,
                durationMillis: 120_000,
                isPlaying: true,
                selectedSubtitleTrack: track,
                currentSubtitleText: "Hello world"
            )
        )

        await store.send(.backButtonTapped) {
            $0.overlayVisible = false
            $0.isPlaying = false
            $0.selectedSubtitleTrack = nil
            $0.currentSubtitleText = nil
        }

        await store.receive(.closeRequested)

        let remoteLoadCount = await remoteStore.loadCount()
        let remoteSaveCount = await remoteStore.saveCount()

        XCTAssertEqual(remoteLoadCount, 1)
        XCTAssertEqual(remoteSaveCount, 1)
    }

    private func makeStore(
        repository: PlayerRepositorySpy,
        remoteStore: RecordingPlaybackStore = RecordingPlaybackStore(),
        subtitleLoader: SubtitleLoaderSpy = SubtitleLoaderSpy(),
        state: PlayerFeature.State = PlayerFeature.State(
            movieID: 1,
            episodeID: 1,
            movieTitle: "Movie",
            episodeLabel: "Episode 1",
            summary: "Summary"
        )
    ) -> TestStore<PlayerFeature.State, PlayerFeature.Action> {
        TestStore(initialState: state) {
            PlayerFeature()
        } withDependencies: {
            $0.phucTvRepository.loadEpisodeSources = { movieID, episodeID, server in
                try await repository.loadEpisodeSources(movieID: movieID, episodeID: episodeID, server: server)
            }
            $0.phucTvPlaybackPositionStore.save = { movieID, episodeID, positionMillis, durationMillis in
                try await remoteStore.save(movieID: movieID, episodeID: episodeID, positionMillis: positionMillis, durationMillis: durationMillis)
            }
            $0.phucTvPlaybackPositionStore.load = { movieID, episodeID in
                try await remoteStore.load(movieID: movieID, episodeID: episodeID)
            }
            $0.phucTvPlaybackPositionStore.delete = { movieID, episodeID in
                try await remoteStore.delete(movieID: movieID, episodeID: episodeID)
            }
            $0.phucTvPlayerSubtitleLoader.loadCues = { track in
                try await subtitleLoader.loadCues(for: track)
            }
            $0.phucTvScreenIdleManager.disableAutoLock = {}
            $0.phucTvScreenIdleManager.enableAutoLock = {}
            $0.phucTvScreenIdleManager.reset = {}
        }
    }

    private func makeLoadedState(
        sources: [PhucTvPlaySource],
        selectedSourceIndex: Int,
        currentPositionMillis: Int64,
        durationMillis: Int64,
        isPlaying: Bool,
        selectedSubtitleTrack: PhucTvPlayTrack? = nil,
        currentSubtitleText: String? = nil
    ) -> PlayerFeature.State {
        var state = PlayerFeature.State(
            movieID: 1,
            episodeID: 1,
            movieTitle: "Movie",
            episodeLabel: "Episode 1",
            summary: "Summary"
        )
        state.screenState = .loaded
        state.sources = sources
        state.selectedSourceIndex = selectedSourceIndex
        state.currentPositionMillis = currentPositionMillis
        state.durationMillis = durationMillis
        state.isPlaying = isPlaying
        state.overlayVisible = true
        state.selectedSubtitleTrack = selectedSubtitleTrack
        state.currentSubtitleText = currentSubtitleText
        return state
    }

    private func makeSource(
        sourceId: Int,
        link: String,
        tracks: [PhucTvPlayTrack],
        isFrame: Bool = false
    ) -> PhucTvPlaySource {
        PhucTvPlaySource(
            sourceId: sourceId,
            serverName: "Server \(sourceId)",
            link: link,
            subtitle: "",
            type: 0,
            isFrame: isFrame,
            quality: "1080p",
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

private enum StubError: Error {
    case failed
}

private actor PlayerRepositorySpy {
    private var sourcesQueue: [Result<[PhucTvPlaySource], Error>]
    private let delayNanoseconds: UInt64?
    private(set) var loadCallCount = 0
    private(set) var cancelledCallCount = 0

    init(
        sources: [PhucTvPlaySource] = [],
        error: Error? = nil,
        delayNanoseconds: UInt64? = nil
    ) {
        self.delayNanoseconds = delayNanoseconds
        if let error {
            self.sourcesQueue = [.failure(error)]
        } else {
            self.sourcesQueue = sources.map { .success([$0]) }
        }
    }

    func loadEpisodeSources(movieID: Int, episodeID: Int, server: Int) async throws -> [PhucTvPlaySource] {
        loadCallCount += 1
        if let delayNanoseconds {
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch is CancellationError {
                cancelledCallCount += 1
                throw CancellationError()
            }
        }

        guard !sourcesQueue.isEmpty else {
            return []
        }

        return try sourcesQueue.removeFirst().get()
    }

    func loadCount() -> Int {
        loadCallCount
    }

    func cancelledLoadCount() -> Int {
        cancelledCallCount
    }
}

private actor RecordingPlaybackStore {
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

    func deleteCount() -> Int {
        deleteCallCount
    }
}

private actor SubtitleLoaderSpy {
    private let cues: [PlayerSubtitleCue]

    init(cues: [PlayerSubtitleCue] = []) {
        self.cues = cues
    }

    func loadCues(for track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue] {
        cues
    }
}
