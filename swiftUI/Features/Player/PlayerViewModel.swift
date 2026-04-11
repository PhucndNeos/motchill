import AVFoundation
import AVKit
import Foundation
import Observation

enum PlayerScreenState: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

@MainActor
@Observable
final class PlayerViewModel {
    @ObservationIgnored
    private let repository: MotchillRepository
    @ObservationIgnored
    private let playbackPositionStore: MotchillPlaybackPositionStoring
    @ObservationIgnored
    let player = AVPlayer()
    @ObservationIgnored
    private var timeObserverToken: Any?
    @ObservationIgnored
    private var lastPersistedProgressBucket: Int64 = 0
    @ObservationIgnored
    private var overlayAutoHideTask: Task<Void, Never>?

    let movieID: Int
    let episodeID: Int
    let movieTitle: String
    let episodeLabel: String

    var state: PlayerScreenState = .idle
    var errorMessage: String?
    var sources: [MotchillPlaySource] = []
    var selectedSourceIndex = 0
    var selectedAudioTrack: MotchillPlayTrack?
    var selectedSubtitleTrack: MotchillPlayTrack?
    var currentPositionMillis: Int64 = 0
    var durationMillis: Int64 = 0
    var isPlaying = false
    var overlayVisible = true

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        repository: MotchillRepository,
        playbackPositionStore: MotchillPlaybackPositionStoring
    ) {
        self.movieID = movieID
        self.episodeID = episodeID
        self.movieTitle = movieTitle
        self.episodeLabel = episodeLabel
        self.repository = repository
        self.playbackPositionStore = playbackPositionStore
        player.automaticallyWaitsToMinimizeStalling = true
    }

    var playableSources: [MotchillPlaySource] {
        sources.playableDirectStreams
    }

    var selectedSource: MotchillPlaySource? {
        guard playableSources.indices.contains(selectedSourceIndex) else { return nil }
        return playableSources[selectedSourceIndex]
    }

    var sourceTitle: String {
        selectedSource?.displayName ?? "No source selected"
    }

    var availableAudioTracks: [MotchillPlayTrack] {
        selectedSource?.audioTracks ?? []
    }

    var availableSubtitleTracks: [MotchillPlayTrack] {
        selectedSource?.subtitleTracks ?? []
    }

    var progressFraction: Double {
        guard durationMillis > 0 else { return 0 }
        return min(max(Double(currentPositionMillis) / Double(durationMillis), 0), 1)
    }

    var seekStepMillis: Int64 {
        guard durationMillis > 0 else { return 10_000 }
        let scaled = Int64((Double(durationMillis) * 0.03).rounded())
        return min(max(scaled, 5_000), 30_000)
    }

    func load() async {
        state = .loading
        errorMessage = nil

        do {
            let fetchedSources = try await repository.loadEpisodeSources(
                movieID: movieID,
                episodeID: episodeID,
                server: 0
            )
            let playable = fetchedSources.playableDirectStreams
            guard !playable.isEmpty else {
                state = .error(message: "No direct stream source available.")
                errorMessage = "No direct stream source available."
                return
            }

            sources = playable
            selectedSourceIndex = 0

            if let selectedSource {
                selectedAudioTrack = selectedSource.defaultAudioTrack
                selectedSubtitleTrack = selectedSource.defaultSubtitleTrack
            }

            let resume = try? await playbackPositionStore.load(movieID: movieID, episodeID: episodeID)
            await loadPlayerItem(startingAt: resume?.positionMillis ?? 0)
            state = .loaded
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Player load failed",
                metadata: [
                    "movie_id": String(movieID),
                    "episode_id": String(episodeID),
                ]
            )
            let message = error.localizedDescription
            errorMessage = message
            state = .error(message: message)
        }
    }

    func retry() async {
        await load()
    }

    func selectSource(_ index: Int) {
        guard playableSources.indices.contains(index) else { return }
        selectedSourceIndex = index
        if let selectedSource {
            selectedAudioTrack = selectedSource.defaultAudioTrack
            selectedSubtitleTrack = selectedSource.defaultSubtitleTrack
            Task { [position = currentPositionMillis] in
                await loadPlayerItem(startingAt: position)
            }
        }
    }

    func handleOverlayTap() {
        if overlayVisible {
            hideOverlay()
        } else {
            showOverlayTemporarily()
        }
    }

    func showOverlayTemporarily() {
        overlayVisible = true
        scheduleOverlayAutoHide()
    }

    func hideOverlay() {
        overlayVisible = false
        cancelOverlayAutoHide()
    }

    func selectAudioTrack(_ track: MotchillPlayTrack?) {
        if let track, !availableAudioTracks.contains(track) {
            return
        }
        selectedAudioTrack = track
    }

    func selectSubtitleTrack(_ track: MotchillPlayTrack?) {
        if let track, !availableSubtitleTracks.contains(track) {
            return
        }
        selectedSubtitleTrack = track
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            Task { await persistProgress() }
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(by deltaMillis: Int64) {
        seek(to: currentPositionMillis + deltaMillis, playAfterSeek: true)
    }

    func seek(to positionMillis: Int64, playAfterSeek: Bool = true) {
        let clamped = max(positionMillis, 0)
        let seconds = Double(clamped) / 1000.0
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if playAfterSeek {
                    self.player.play()
                    self.isPlaying = true
                }
            }
        }
        currentPositionMillis = clamped
    }

    func stop() {
        player.pause()
        isPlaying = false
        detachTimeObserver()
        cancelOverlayAutoHide()
    }

    func persistProgress() async {
        guard durationMillis > 0 else { return }
        do {
            try await playbackPositionStore.save(
                movieID: movieID,
                episodeID: episodeID,
                positionMillis: currentPositionMillis,
                durationMillis: durationMillis
            )
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Player progress save failed",
                metadata: [
                    "movie_id": String(movieID),
                    "episode_id": String(episodeID),
                ]
            )
        }
    }

    private func loadPlayerItem(startingAt positionMillis: Int64) async {
        guard let selectedSource, let url = URL(string: selectedSource.link) else {
            state = .error(message: "Invalid playback URL.")
            errorMessage = "Invalid playback URL."
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        durationMillis = 0
        currentPositionMillis = max(positionMillis, 0)
        isPlaying = false
        detachTimeObserver()
        attachTimeObserver()

        if positionMillis > 0 {
            seek(to: positionMillis, playAfterSeek: false)
        }

        player.play()
        isPlaying = true
        showOverlayTemporarily()
    }

    private func attachTimeObserver() {
        guard timeObserverToken == nil else { return }
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let currentMillis = Int64((time.seconds * 1000).rounded())
                self.currentPositionMillis = max(currentMillis, 0)

                if let currentItem = self.player.currentItem {
                    let itemDuration = currentItem.duration.seconds
                    if itemDuration.isFinite && !itemDuration.isNaN {
                        self.durationMillis = max(Int64((itemDuration * 1000).rounded()), 0)
                    }
                }

                let bucket = self.currentPositionMillis / 10_000
                if bucket != self.lastPersistedProgressBucket {
                    self.lastPersistedProgressBucket = bucket
                    await self.persistProgress()
                }
            }
        }
    }

    private func detachTimeObserver() {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    private func scheduleOverlayAutoHide() {
        overlayAutoHideTask?.cancel()
        overlayAutoHideTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                self.overlayVisible = false
                self.overlayAutoHideTask = nil
            }
        }
    }

    private func cancelOverlayAutoHide() {
        overlayAutoHideTask?.cancel()
        overlayAutoHideTask = nil
    }

    static func previewLoaded() -> PlayerViewModel {
        PlayerViewModel(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            repository: PreviewPlayerRepository(sources: PlayerMockData.sources),
            playbackPositionStore: PreviewPlayerStore(progress: MotchillPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000))
        )
    }

    static func previewError() -> PlayerViewModel {
        PlayerViewModel(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            repository: PreviewPlayerRepository(error: NSError(domain: "PreviewPlayerRepository", code: 1)),
            playbackPositionStore: PreviewPlayerStore(progress: nil)
        )
    }
}

private enum PlayerMockData {
    static let sources: [MotchillPlaySource] = [
        MotchillPlaySource(
            sourceId: 1,
            serverName: "Server 1",
            link: "https://example.com/stream-1080.m3u8",
            subtitle: "",
            type: 0,
            isFrame: false,
            quality: "1080p",
            tracks: [
                MotchillPlayTrack(kind: "audio", file: "https://example.com/audio-en.m3u8", label: "English", isDefault: true),
                MotchillPlayTrack(kind: "subtitle", file: "https://example.com/sub-en.vtt", label: "English", isDefault: true)
            ]
        ),
        MotchillPlaySource(
            sourceId: 2,
            serverName: "Server 2",
            link: "https://example.com/stream-720.m3u8",
            subtitle: "https://example.com/sub-vi.vtt",
            type: 0,
            isFrame: false,
            quality: "720p",
            tracks: []
        )
    ]
}

private struct PreviewPlayerRepository: MotchillRepository {
    let sources: [MotchillPlaySource]
    let error: Error?

    init(sources: [MotchillPlaySource]) {
        self.sources = sources
        self.error = nil
    }

    init(error: Error) {
        self.sources = []
        self.error = error
    }

    func loadHome() async throws -> [MotchillHomeSection] { [] }
    func loadNavbar() async throws -> [MotchillNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> MotchillMovieDetail { DetailMockData.detail }
    func loadPreview(slug: String) async throws -> MotchillMovieDetail { DetailMockData.detail }
    func loadSearchFilters() async throws -> MotchillSearchFilterData { MotchillSearchFilterData(categories: [], countries: []) }
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
    ) async throws -> MotchillSearchResults {
        MotchillSearchResults(records: [], pagination: MotchillSearchPagination(pageIndex: 1, pageSize: 1, pageCount: 1, totalRecords: 0))
    }
    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [MotchillPlaySource] {
        if let error { throw error }
        return sources
    }
    func loadPopupAd() async throws -> MotchillPopupAdConfig? { nil }
}

private struct PreviewPlayerStore: MotchillPlaybackPositionStoring {
    let progress: MotchillPlaybackProgressSnapshot?

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
    }

    func load(movieID: Int, episodeID: Int) async throws -> MotchillPlaybackProgressSnapshot? {
        progress
    }
}
