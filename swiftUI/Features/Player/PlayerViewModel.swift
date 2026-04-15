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
    private let repository: PhucTvRepository
    @ObservationIgnored
    private let localStore: PhucTvPlaybackPositionStoring
    @ObservationIgnored
    private let remoteStore: PhucTvPlaybackPositionStoring?
    @ObservationIgnored
    private let subtitleLoader: PlayerSubtitleLoading
    @ObservationIgnored
    let player = AVPlayer()
    @ObservationIgnored
    private var timeObserverToken: Any?
    @ObservationIgnored
    private var lastPersistedProgressBucket: Int64 = 0
    @ObservationIgnored
    private var overlayAutoHideTask: Task<Void, Never>?
    @ObservationIgnored
    private var subtitleLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var subtitleCues: [PlayerSubtitleCue] = []
    @ObservationIgnored
    private var currentSubtitleCueIndex: Int?
    @ObservationIgnored
    private var lastSubtitleText: String?

    let movieID: Int
    let episodeID: Int
    let movieTitle: String
    let episodeLabel: String

    var state: PlayerScreenState = .idle
    var errorMessage: String?
    var sources: [PhucTvPlaySource] = []
    var selectedSourceIndex = 0
    var selectedAudioTrack: PhucTvPlayTrack?
    var selectedSubtitleTrack: PhucTvPlayTrack?
    var currentPositionMillis: Int64 = 0
    var durationMillis: Int64 = 0
    var isPlaying = false
    var overlayVisible = true
    var currentSubtitleText: String?

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        repository: PhucTvRepository,
        localStore: PhucTvPlaybackPositionStoring,
        remoteStore: PhucTvPlaybackPositionStoring? = nil,
        subtitleLoader: PlayerSubtitleLoading = PlayerSubtitleLoader()
    ) {
        self.movieID = movieID
        self.episodeID = episodeID
        self.movieTitle = movieTitle
        self.episodeLabel = episodeLabel
        self.repository = repository
        self.localStore = localStore
        self.remoteStore = remoteStore
        self.subtitleLoader = subtitleLoader
        player.automaticallyWaitsToMinimizeStalling = true
    }

    var playableSources: [PhucTvPlaySource] {
        sources.playableDirectStreams
    }

    var iframeSources: [PhucTvPlaySource] {
        sources.filter(\.isFrame)
    }

    var hasIframeOnlySources: Bool {
        playableSources.isEmpty && !iframeSources.isEmpty
    }

    var selectedSource: PhucTvPlaySource? {
        guard playableSources.indices.contains(selectedSourceIndex) else { return nil }
        return playableSources[selectedSourceIndex]
    }

    var sourceTitle: String {
        selectedSource?.displayName ?? "No source selected"
    }

    var availableAudioTracks: [PhucTvPlayTrack] {
        selectedSource?.audioTracks ?? []
    }

    var availableSubtitleTracks: [PhucTvPlayTrack] {
        selectedSource?.subtitleTracks ?? []
    }

    var hasSubtitleTracks: Bool {
        !availableSubtitleTracks.isEmpty
    }

    var isSubtitleEnabled: Bool {
        selectedSubtitleTrack != nil
    }

    var defaultSubtitleTrackForSelectedSource: PhucTvPlayTrack? {
        selectedSource?.defaultSubtitleTrack ?? selectedSource?.subtitleTracks.first
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
        clearSubtitleRuntime(clearSelection: true)

        do {
            let fetchedSources = try await repository.loadEpisodeSources(
                movieID: movieID,
                episodeID: episodeID,
                server: 0
            )
            sources = fetchedSources

            let playable = fetchedSources.playableDirectStreams
            guard !playable.isEmpty else {
                let message: String
                if fetchedSources.contains(where: { $0.isFrame }) {
                    message = "Không có nguồn phát trực tiếp. Chọn một iframe bên dưới để mở trong WebView."
                } else {
                    message = "No direct stream source available."
                }
                state = .error(message: message)
                errorMessage = message
                return
            }

            selectedSourceIndex = 0
            applyTrackSelectionDefaultsForSelectedSource()

            // Keep remote as the source of truth for resume. Local storage is only
            // used as a write buffer until the next explicit sync point.
            let remoteSnapshot = try? await remoteStore?.load(movieID: movieID, episodeID: episodeID)
            let resumeMillis = remoteSnapshot?.positionMillis ?? 0
            await loadPlayerItem(startingAt: resumeMillis)
            state = .loaded
        } catch {
            PhucTvLogger.shared.error(
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
        applyTrackSelectionDefaultsForSelectedSource()

        Task { [position = currentPositionMillis] in
            await persistProgress()
            await syncProgressToRemote()
            await loadPlayerItem(startingAt: position)
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

    func selectAudioTrack(_ track: PhucTvPlayTrack?) {
        if let track, !availableAudioTracks.contains(track) {
            return
        }
        selectedAudioTrack = track
    }

    func selectSubtitleTrack(_ track: PhucTvPlayTrack?) {
        if let track, !availableSubtitleTracks.contains(track) {
            return
        }

        if let track {
            selectedSubtitleTrack = track
            loadSubtitleCues(for: track)
        } else {
            clearSubtitleRuntime(clearSelection: true)
        }
    }

    func toggleSubtitle() {
        if isSubtitleEnabled {
            clearSubtitleRuntime(clearSelection: true)
        } else if let track = defaultSubtitleTrackForSelectedSource {
            selectedSubtitleTrack = track
            loadSubtitleCues(for: track)
        }
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            Task {
                await persistProgress()
                await syncProgressToRemote()
            }
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(by deltaMillis: Int64) {
        seek(to: currentPositionMillis + deltaMillis, playAfterSeek: true)
    }

    func seek(to positionMillis: Int64, playAfterSeek: Bool = true) {
        seek(to: positionMillis, playAfterSeek: playAfterSeek, syncProgress: true)
    }

    private func seek(to positionMillis: Int64, playAfterSeek: Bool, syncProgress: Bool) {
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
                self.syncSubtitleTextIfNeeded(at: clamped)
                guard syncProgress else { return }
                await self.persistProgress()
                await self.syncProgressToRemote()
            }
        }
        currentPositionMillis = clamped
        syncSubtitleTextIfNeeded(at: clamped)
    }

    func stop() {
        player.pause()
        isPlaying = false
        detachTimeObserver()
        cancelOverlayAutoHide()
        clearSubtitleRuntime(clearSelection: true)
        Task { await syncProgressToRemote() }
    }

    /// Writes current progress to the local store only (fast, no network).
    /// Called periodically by the time observer and before stop/sync.
    func persistProgress() async {
        guard durationMillis > 0 else { return }
        do {
            try await localStore.save(
                movieID: movieID,
                episodeID: episodeID,
                positionMillis: currentPositionMillis,
                durationMillis: durationMillis
            )
        } catch {
            PhucTvLogger.shared.error(
                error,
                message: "Player local progress save failed",
                metadata: [
                    "movie_id": String(movieID),
                    "episode_id": String(episodeID),
                ]
            )
        }
    }

    /// Syncs the current position to the remote store using max-wins logic,
    /// then deletes the local row so it is not re-uploaded on next launch.
    /// If the remote save fails, the local row is kept so the startup migrator
    /// can retry. If the remote is already ahead, local is still deleted
    /// (remote is the canonical source).
    private func syncProgressToRemote() async {
        guard durationMillis > 0, let remoteStore else { return }

        let remoteSnapshot = try? await remoteStore.load(movieID: movieID, episodeID: episodeID)
        let remotePosition = remoteSnapshot?.positionMillis ?? 0

        if currentPositionMillis >= remotePosition {
            // Local is ahead or equal — push to remote.
            do {
                try await remoteStore.save(
                    movieID: movieID,
                    episodeID: episodeID,
                    positionMillis: currentPositionMillis,
                    durationMillis: durationMillis
                )
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Player remote progress sync failed — local kept for retry",
                    metadata: [
                        "movie_id": String(movieID),
                        "episode_id": String(episodeID),
                    ]
                )
                return // Keep local so the startup migrator can retry.
            }
        }
        // Remote is now up-to-date (either we just pushed, or it was already ahead).
        // Delete the local row — it is no longer needed.
        try? await localStore.delete(movieID: movieID, episodeID: episodeID)
    }

    func applyTrackSelectionDefaultsForSelectedSource() {
        selectedAudioTrack = selectedSource?.defaultAudioTrack

        if let track = defaultSubtitleTrackForSelectedSource {
            selectedSubtitleTrack = track
            loadSubtitleCues(for: track)
        } else {
            clearSubtitleRuntime(clearSelection: true)
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
            seek(to: positionMillis, playAfterSeek: false, syncProgress: false)
        }

        player.play()
        isPlaying = true
        syncSubtitleTextIfNeeded(at: currentPositionMillis)
        showOverlayTemporarily()
    }

    private func attachTimeObserver() {
        guard timeObserverToken == nil else { return }
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
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

                self.syncSubtitleTextIfNeeded(at: self.currentPositionMillis)

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

    private func loadSubtitleCues(for track: PhucTvPlayTrack) {
        subtitleLoadTask?.cancel()
        subtitleCues = []
        currentSubtitleCueIndex = nil
        publishSubtitleText(nil)

        let trackToLoad = track
        subtitleLoadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let cues = try await self.subtitleLoader.loadCues(for: trackToLoad)
                guard !Task.isCancelled else { return }
                guard self.selectedSubtitleTrack == trackToLoad else { return }

                self.subtitleCues = cues
                self.currentSubtitleCueIndex = nil
                self.lastSubtitleText = nil
                self.syncSubtitleTextIfNeeded(at: self.currentPositionMillis)
            } catch {
                guard !Task.isCancelled else { return }
                guard self.selectedSubtitleTrack == trackToLoad else { return }

                PhucTvLogger.shared.error(
                    error,
                    message: "Subtitle load failed",
                    metadata: [
                        "movie_id": String(self.movieID),
                        "episode_id": String(self.episodeID),
                        "subtitle_label": trackToLoad.displayLabel,
                        "subtitle_url": trackToLoad.file,
                    ]
                )
                self.clearSubtitleRuntime(clearSelection: false)
                self.selectedSubtitleTrack = nil
            }
        }
    }

    private func syncSubtitleTextIfNeeded(at positionMillis: Int64) {
        let resolution = PlayerSubtitleResolver.resolve(
            positionMillis: positionMillis,
            cues: subtitleCues,
            hintIndex: currentSubtitleCueIndex
        )
        currentSubtitleCueIndex = resolution.cueIndex
        publishSubtitleText(resolution.text)
    }

    private func clearSubtitleRuntime(clearSelection: Bool) {
        subtitleLoadTask?.cancel()
        subtitleLoadTask = nil
        subtitleCues = []
        currentSubtitleCueIndex = nil
        publishSubtitleText(nil)

        if clearSelection {
            selectedSubtitleTrack = nil
        }
    }

    private func publishSubtitleText(_ text: String?) {
        guard currentSubtitleText != text else {
            lastSubtitleText = text
            return
        }
        lastSubtitleText = text
        currentSubtitleText = text
    }

    static func previewLoaded() -> PlayerViewModel {
        let viewModel = PlayerViewModel(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            repository: PreviewPlayerRepository(sources: PlayerMockData.sources),
            localStore: PreviewPlayerStore(progress: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000))
        )
        viewModel.sources = PlayerMockData.sources
        viewModel.selectedSourceIndex = 0
        viewModel.applyTrackSelectionDefaultsForSelectedSource()
        viewModel.state = .loaded
        viewModel.currentPositionMillis = 120_000
        viewModel.durationMillis = 600_000
        return viewModel
    }

    static func previewError() -> PlayerViewModel {
        let viewModel = PlayerViewModel(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            repository: PreviewPlayerRepository(error: NSError(domain: "PreviewPlayerRepository", code: 1)),
            localStore: PreviewPlayerStore(progress: nil)
        )
        viewModel.state = .error(message: "Không thể nạp nguồn phát trong preview.")
        viewModel.errorMessage = "Không thể nạp nguồn phát trong preview."
        return viewModel
    }

    static func previewIframeOnlyError() -> PlayerViewModel {
        let viewModel = PlayerViewModel(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            repository: PreviewPlayerRepository(sources: PlayerMockData.iframeSources),
            localStore: PreviewPlayerStore(progress: nil)
        )
        viewModel.sources = PlayerMockData.iframeSources
        viewModel.state = .error(message: "Không có nguồn phát trực tiếp. Chọn một iframe bên dưới để mở trong WebView.")
        viewModel.errorMessage = "Không có nguồn phát trực tiếp. Chọn một iframe bên dưới để mở trong WebView."
        return viewModel
    }
}

private enum PlayerMockData {
    static let sources: [PhucTvPlaySource] = [
        PhucTvPlaySource(
            sourceId: 1,
            serverName: "Server 1",
            link: "https://example.com/stream-1080.m3u8",
            subtitle: "",
            type: 0,
            isFrame: false,
            quality: "1080p",
            tracks: [
                PhucTvPlayTrack(kind: "audio", file: "https://example.com/audio-en.m3u8", label: "English", isDefault: true),
                PhucTvPlayTrack(kind: "subtitle", file: "https://example.com/sub-en.vtt", label: "English", isDefault: true)
            ]
        ),
        PhucTvPlaySource(
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

    static let iframeSources: [PhucTvPlaySource] = [
        PhucTvPlaySource(
            sourceId: 11,
            serverName: "Iframe 1",
            link: "https://example.com/embed-1",
            subtitle: "",
            type: 0,
            isFrame: true,
            quality: "720p",
            tracks: []
        ),
        PhucTvPlaySource(
            sourceId: 12,
            serverName: "Iframe 2",
            link: "https://example.com/embed-2",
            subtitle: "",
            type: 0,
            isFrame: true,
            quality: "1080p",
            tracks: []
        )
    ]
}

private struct PreviewPlayerRepository: PhucTvRepository {
    let sources: [PhucTvPlaySource]
    let error: Error?

    init(sources: [PhucTvPlaySource]) {
        self.sources = sources
        self.error = nil
    }

    init(error: Error) {
        self.sources = []
        self.error = error
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
    ) async throws -> [PhucTvPlaySource] {
        if let error { throw error }
        return sources
    }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private struct PreviewPlayerStore: PhucTvPlaybackPositionStoring {
    let progress: PhucTvPlaybackProgressSnapshot?

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
    }

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        progress
    }
}
