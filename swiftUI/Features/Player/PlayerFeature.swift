import AVFoundation
import ComposableArchitecture
import Foundation
import Observation
import SwiftUI

enum PlayerScreenState: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

@Reducer
struct PlayerFeature {
    enum CancelID {
        case load
        case overlayAutoHide
        case subtitleLoad
        case timeObserver
    }

    struct LoadError: Equatable, Sendable, Error {
        let message: String

        init(_ error: Error) {
            message = String(describing: error)
        }
    }

    struct LoadResponse: Equatable, Sendable {
        let sources: [PhucTvPlaySource]
        let resumePositionMillis: Int64
    }

    struct SubtitleLoadResponse: Equatable, Sendable {
        let track: PhucTvPlayTrack
        let cues: [PlayerSubtitleCue]
    }

    @ObservableState
    struct State: Equatable {
        var movieID: Int
        var episodeID: Int
        var movieTitle: String
        var episodeLabel: String
        var summary: String

        var screenState: PlayerScreenState = .idle
        var sources: [PhucTvPlaySource] = []
        var selectedSourceIndex = 0
        var selectedAudioTrack: PhucTvPlayTrack?
        var selectedSubtitleTrack: PhucTvPlayTrack?
        var currentPositionMillis: Int64 = 0
        var durationMillis: Int64 = 0
        var isPlaying = false
        var overlayVisible = true
        var currentSubtitleText: String?

        @ObservationStateIgnored
        var player = AVPlayer()

        @ObservationStateIgnored
        var subtitleCues: [PlayerSubtitleCue] = []

        @ObservationStateIgnored
        var currentSubtitleCueIndex: Int?

        init(
            movieID: Int,
            episodeID: Int,
            movieTitle: String,
            episodeLabel: String,
            summary: String
        ) {
            self.movieID = movieID
            self.episodeID = episodeID
            self.movieTitle = movieTitle
            self.episodeLabel = episodeLabel
            self.summary = summary
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

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.movieID == rhs.movieID &&
            lhs.episodeID == rhs.episodeID &&
            lhs.movieTitle == rhs.movieTitle &&
            lhs.episodeLabel == rhs.episodeLabel &&
            lhs.summary == rhs.summary &&
            lhs.screenState == rhs.screenState &&
            lhs.sources == rhs.sources &&
            lhs.selectedSourceIndex == rhs.selectedSourceIndex &&
            lhs.selectedAudioTrack == rhs.selectedAudioTrack &&
            lhs.selectedSubtitleTrack == rhs.selectedSubtitleTrack &&
            lhs.currentPositionMillis == rhs.currentPositionMillis &&
            lhs.durationMillis == rhs.durationMillis &&
            lhs.isPlaying == rhs.isPlaying &&
            lhs.overlayVisible == rhs.overlayVisible &&
            lhs.currentSubtitleText == rhs.currentSubtitleText
        }
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case loadResponse(Result<LoadResponse, LoadError>)
        case retryTapped
        case backButtonTapped
        case playPauseTapped
        case seek(deltaMillis: Int64)
        case seekTo(positionMillis: Int64, playAfterSeek: Bool)
        case timeUpdated(CMTime)
        case overlayTapped
        case hideOverlay
        case showOverlayTemporarily
        case sourceSelected(PhucTvPlaySource)
        case subtitleSelected(PhucTvPlayTrack?)
        case subtitleLoaded(Result<SubtitleLoadResponse, LoadError>)
        case closeRequested
    }

    @Dependency(\.phucTvRepository) var repository
    @Dependency(\.phucTvPlaybackPositionStore) var playbackPositionStore
    @Dependency(\.phucTvPlayerSubtitleLoader) var subtitleLoader
    @Dependency(\.phucTvScreenIdleManager) var screenIdleManager

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedSourceIndex):
                return selectSource(at: state.selectedSourceIndex, state: &state)

            case .binding:
                return .none

            case .onAppear:
                screenIdleManager.disableAutoLock()

                guard state.screenState == .idle else {
                    return .none
                }

                state.screenState = .loading
                state.sources = []
                state.selectedSourceIndex = 0
                state.selectedAudioTrack = nil
                state.selectedSubtitleTrack = nil
                state.currentPositionMillis = 0
                state.durationMillis = 0
                state.isPlaying = false
                state.overlayVisible = true
                state.currentSubtitleText = nil
                state.subtitleCues = []
                state.currentSubtitleCueIndex = nil

                return loadEpisodeSources(movieID: state.movieID, episodeID: state.episodeID)

            case .retryTapped:
                state.screenState = .loading
                state.sources = []
                state.selectedSourceIndex = 0
                state.selectedAudioTrack = nil
                state.selectedSubtitleTrack = nil
                state.currentPositionMillis = 0
                state.durationMillis = 0
                state.isPlaying = false
                state.overlayVisible = true
                state.currentSubtitleText = nil
                state.subtitleCues = []
                state.currentSubtitleCueIndex = nil

                return loadEpisodeSources(movieID: state.movieID, episodeID: state.episodeID)

            case let .loadResponse(.success(response)):
                state.sources = response.sources
                state.selectedSourceIndex = 0
                state.durationMillis = 0
                state.isPlaying = false
                state.overlayVisible = true
                state.currentSubtitleText = nil
                state.subtitleCues = []
                state.currentSubtitleCueIndex = nil

                guard let selectedSource = state.selectedSource else {
                    let message: String
                    if state.hasIframeOnlySources {
                        message = "Không có nguồn phát trực tiếp. Chọn một iframe bên dưới để mở trong WebView."
                    } else {
                        message = "No direct stream source available."
                    }

                    state.screenState = .error(message: message)
                    return .none
                }

                applyTrackSelectionDefaultsForSelectedSource(&state)
                state.currentPositionMillis = max(response.resumePositionMillis, 0)
                state.isPlaying = true
                state.screenState = .loaded

                let subtitleTrack = state.selectedSubtitleTrack
                return .merge(
                    startPlayback(
                        player: state.player,
                        source: selectedSource,
                        resumePositionMillis: state.currentPositionMillis
                    ),
                    subtitleTrack.map { Effect.send(.subtitleSelected($0)) } ?? .none
                )

            case let .loadResponse(.failure(error)):
                state.screenState = .error(message: error.message)
                return .none

            case .backButtonTapped:
                state.isPlaying = false
                state.overlayVisible = false
                state.currentSubtitleText = nil
                state.subtitleCues = []
                state.currentSubtitleCueIndex = nil
                state.selectedSubtitleTrack = nil

                return .merge(
                    .cancel(id: CancelID.load),
                    .cancel(id: CancelID.overlayAutoHide),
                    .cancel(id: CancelID.subtitleLoad),
                    .cancel(id: CancelID.timeObserver),
                    .run { [player = state.player, movieID = state.movieID, episodeID = state.episodeID, positionMillis = state.currentPositionMillis, durationMillis = state.durationMillis, screenIdleManager = screenIdleManager] send in
                        await MainActor.run {
                            player.pause()
                            screenIdleManager.enableAutoLock()
                        }

                        await syncProgressToRemote(
                            movieID: movieID,
                            episodeID: episodeID,
                            positionMillis: positionMillis,
                            durationMillis: durationMillis
                        )

                        await send(.closeRequested)
                    }
                )

            case .overlayTapped:
                if state.overlayVisible {
                    state.overlayVisible = false
                    return .cancel(id: CancelID.overlayAutoHide)
                } else {
                    return .send(.showOverlayTemporarily)
                }

            case .showOverlayTemporarily:
                state.overlayVisible = true
                return .run { send in
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    guard !Task.isCancelled else { return }
                    await send(.hideOverlay)
                }
                .cancellable(id: CancelID.overlayAutoHide, cancelInFlight: true)

            case .hideOverlay:
                state.overlayVisible = false
                return .cancel(id: CancelID.overlayAutoHide)

            case .playPauseTapped:
                guard state.screenState == .loaded, state.selectedSource != nil else {
                    return .none
                }

                if state.isPlaying {
                    state.isPlaying = false
                    return .merge(
                        pausePlayer(player: state.player),
                        syncProgressToRemoteEffect(
                            movieID: state.movieID,
                            episodeID: state.episodeID,
                            positionMillis: state.currentPositionMillis,
                            durationMillis: state.durationMillis
                        )
                    )
                } else {
                    state.isPlaying = true
                    return playPlayer(player: state.player)
                }

            case let .seek(deltaMillis):
                return .send(.seekTo(
                    positionMillis: state.currentPositionMillis + deltaMillis,
                    playAfterSeek: true
                ))

            case let .seekTo(positionMillis, playAfterSeek):
                let clamped = max(positionMillis, 0)
                state.currentPositionMillis = clamped
                if playAfterSeek {
                    state.isPlaying = true
                }
                updateSubtitleText(for: clamped, state: &state)

                return .merge(
                    seekPlayerEffect(
                        player: state.player,
                        positionMillis: clamped,
                        playAfterSeek: playAfterSeek
                    ),
                    syncProgressToRemoteEffect(
                        movieID: state.movieID,
                        episodeID: state.episodeID,
                        positionMillis: clamped,
                        durationMillis: state.durationMillis
                    )
                )

            case let .timeUpdated(time):
                let currentMillis = Int64((time.seconds * 1000).rounded())
                state.currentPositionMillis = max(currentMillis, 0)

                if let currentItem = state.player.currentItem {
                    let itemDuration = currentItem.duration.seconds
                    if itemDuration.isFinite && !itemDuration.isNaN {
                        state.durationMillis = max(Int64((itemDuration * 1000).rounded()), 0)
                    }
                }

                updateSubtitleText(for: state.currentPositionMillis, state: &state)
                return .none

            case let .sourceSelected(source):
                guard let nextIndex = state.playableSources.firstIndex(where: { $0.id == source.id }) else {
                    return .none
                }

                guard state.selectedSource?.id != source.id else {
                    return .none
                }

                state.selectedSourceIndex = nextIndex
                return selectSource(at: nextIndex, state: &state)

            case let .subtitleSelected(track):
                if let track {
                    guard state.availableSubtitleTracks.contains(track) else {
                        return .none
                    }

                    state.selectedSubtitleTrack = track
                    state.subtitleCues = []
                    state.currentSubtitleCueIndex = nil
                    state.currentSubtitleText = nil

                    return loadSubtitleCues(track: track)
                } else {
                    state.selectedSubtitleTrack = nil
                    state.subtitleCues = []
                    state.currentSubtitleCueIndex = nil
                    state.currentSubtitleText = nil
                    return .cancel(id: CancelID.subtitleLoad)
                }

            case let .subtitleLoaded(.success(response)):
                guard state.selectedSubtitleTrack == response.track else {
                    return .none
                }

                state.subtitleCues = response.cues
                state.currentSubtitleCueIndex = nil
                updateSubtitleText(for: state.currentPositionMillis, state: &state)
                return .none

            case let .subtitleLoaded(.failure(error)):
                PhucTvLogger.shared.error(
                    error,
                    message: "Subtitle load failed",
                    metadata: [
                        "movie_id": String(state.movieID),
                        "episode_id": String(state.episodeID)
                    ]
                )
                state.selectedSubtitleTrack = nil
                state.subtitleCues = []
                state.currentSubtitleCueIndex = nil
                state.currentSubtitleText = nil
                return .cancel(id: CancelID.subtitleLoad)

            case .closeRequested:
                return .none
            }
        }
    }

    private func loadEpisodeSources(movieID: Int, episodeID: Int) -> Effect<Action> {
        let repository = repository
        let playbackStore = playbackPositionStore

        return .run { send in
            do {
                let fetchedSources = try await repository.loadEpisodeSources(
                    movieID: movieID,
                    episodeID: episodeID,
                    server: 0
                )
                let remoteSnapshot = try? await playbackStore.load(movieID: movieID, episodeID: episodeID)
                let resumePositionMillis = remoteSnapshot?.positionMillis ?? 0

                await send(.loadResponse(.success(.init(
                    sources: fetchedSources,
                    resumePositionMillis: resumePositionMillis
                ))))
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Player load failed",
                    metadata: [
                        "movie_id": String(movieID),
                        "episode_id": String(episodeID)
                    ]
                )
                await send(.loadResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func loadSubtitleCues(track: PhucTvPlayTrack) -> Effect<Action> {
        let subtitleLoader = subtitleLoader

        return .run { send in
            do {
                let cues = try await subtitleLoader.loadCues(track)
                await send(.subtitleLoaded(.success(.init(track: track, cues: cues))))
            } catch is CancellationError {
                return
            } catch {
                await send(.subtitleLoaded(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.subtitleLoad, cancelInFlight: true)
    }

    private func startPlayback(
        player: AVPlayer,
        source: PhucTvPlaySource,
        resumePositionMillis: Int64
    ) -> Effect<Action> {
        .run { send in
            guard let url = URL(string: source.link) else {
                await send(.loadResponse(.failure(.init(NSError(
                    domain: "PlayerFeature",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid playback URL."]
                )))))
                return
            }

            await MainActor.run {
                let item = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: item)
                player.automaticallyWaitsToMinimizeStalling = true
            }

            if resumePositionMillis > 0 {
                await performSeek(
                    player: player,
                    positionMillis: resumePositionMillis,
                    playAfterSeek: false
                )
            }

            await MainActor.run {
                player.play()
            }

            await send(.showOverlayTemporarily)

            let stream = await MainActor.run { makePeriodicTimeStream(player: player) }
            for await time in stream {
                await send(.timeUpdated(time))
            }
        }
        .cancellable(id: CancelID.timeObserver, cancelInFlight: true)
    }

    private func pausePlayer(player: AVPlayer) -> Effect<Action> {
        .run { _ in
            await MainActor.run {
                player.pause()
            }
        }
    }

    private func playPlayer(player: AVPlayer) -> Effect<Action> {
        .run { _ in
            await MainActor.run {
                player.play()
            }
        }
    }

    private func seekPlayerEffect(
        player: AVPlayer,
        positionMillis: Int64,
        playAfterSeek: Bool
    ) -> Effect<Action> {
        .run { _ in
            await performSeek(
                player: player,
                positionMillis: positionMillis,
                playAfterSeek: playAfterSeek
            )
        }
    }

    @MainActor
    private func performSeek(
        player: AVPlayer,
        positionMillis: Int64,
        playAfterSeek: Bool
    ) async {
        let time = CMTime(
            seconds: Double(positionMillis) / 1_000.0,
            preferredTimescale: 600
        )

        await withCheckedContinuation { continuation in
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }

        if playAfterSeek {
            player.play()
        }
    }

    private func syncProgressToRemoteEffect(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) -> Effect<Action> {
        .run { _ in
            await syncProgressToRemote(
                movieID: movieID,
                episodeID: episodeID,
                positionMillis: positionMillis,
                durationMillis: durationMillis
            )
        }
    }

    private func syncProgressToRemote(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async {
        guard durationMillis > 0 else {
            return
        }

        let playbackStore = playbackPositionStore

        let remoteSnapshot = try? await playbackStore.load(movieID: movieID, episodeID: episodeID)
        let remotePosition = remoteSnapshot?.positionMillis ?? 0

        guard positionMillis >= remotePosition else {
            return
        }

        do {
            try await playbackStore.save(
                movieID,
                episodeID,
                positionMillis,
                durationMillis
            )
        } catch {
            PhucTvLogger.shared.error(
                error,
                message: "Player remote progress sync failed",
                metadata: [
                    "movie_id": String(movieID),
                    "episode_id": String(episodeID)
                ]
            )
        }
    }

    @MainActor
    private func makePeriodicTimeStream(player: AVPlayer) -> AsyncStream<CMTime> {
        AsyncStream { continuation in
            let token = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                queue: .main
            ) { time in
                continuation.yield(time)
            }

            final class TokenBox: @unchecked Sendable {
                let token: Any

                init(_ token: Any) {
                    self.token = token
                }
            }

            let box = TokenBox(token)

            continuation.onTermination = { _ in
                player.removeTimeObserver(box.token)
            }
        }
    }

    private func selectSource(at index: Int, state: inout State) -> Effect<Action> {
        guard state.playableSources.indices.contains(index) else {
            return .none
        }

        let selectedSource = state.playableSources[index]

        state.selectedSourceIndex = index
        state.currentSubtitleText = nil
        state.subtitleCues = []
        state.currentSubtitleCueIndex = nil
        applyTrackSelectionDefaultsForSelectedSource(&state)
        state.isPlaying = true

        let subtitleTrack = state.selectedSubtitleTrack
        let resumePositionMillis = state.currentPositionMillis

        return .merge(
            .cancel(id: CancelID.subtitleLoad),
            syncProgressToRemoteEffect(
                movieID: state.movieID,
                episodeID: state.episodeID,
                positionMillis: resumePositionMillis,
                durationMillis: state.durationMillis
            ),
            startPlayback(
                player: state.player,
                source: selectedSource,
                resumePositionMillis: resumePositionMillis
            ),
            subtitleTrack.map { Effect.send(.subtitleSelected($0)) } ?? .none
        )
    }

    private func updateSubtitleText(for positionMillis: Int64, state: inout State) {
        let resolution = PlayerSubtitleResolver.resolve(
            positionMillis: positionMillis,
            cues: state.subtitleCues,
            hintIndex: state.currentSubtitleCueIndex
        )
        state.currentSubtitleCueIndex = resolution.cueIndex
        state.currentSubtitleText = resolution.text
    }

    private func applyTrackSelectionDefaultsForSelectedSource(_ state: inout State) {
        state.selectedAudioTrack = state.selectedSource?.defaultAudioTrack

        if let track = state.defaultSubtitleTrackForSelectedSource {
            state.selectedSubtitleTrack = track
            state.subtitleCues = []
            state.currentSubtitleCueIndex = nil
            state.currentSubtitleText = nil
        } else {
            state.selectedSubtitleTrack = nil
            state.subtitleCues = []
            state.currentSubtitleCueIndex = nil
            state.currentSubtitleText = nil
        }
    }
}

struct PlayerFeatureView: View {
    @Bindable var store: StoreOf<PlayerFeature>

    var body: some View {
        PlayerView(store: store)
    }
}
