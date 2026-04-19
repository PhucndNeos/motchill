import ComposableArchitecture
import Foundation

@Reducer
struct DetailFeature {
    enum CancelID {
        case load
        case refreshProgress
        case toggleLike
    }

    struct LoadError: Equatable, Sendable, Error {
        let message: String

        init(_ error: Error) {
            self.message = String(describing: error)
        }
    }

    struct LoadResult: Equatable, Sendable {
        let detail: PhucTvMovieDetail
        let isLiked: Bool
        let episodeProgressById: [Int: PhucTvPlaybackProgressSnapshot]
    }

    @ObservableState
    struct State: Equatable {
        var movie: PhucTvMovieCard
        var detail: PhucTvMovieDetail?
        var screenState: DetailScreenState = .idle
        var selectedTab: DetailSectionTab?
        var isLiked = false
        var episodeProgressById: [Int: PhucTvPlaybackProgressSnapshot] = [:]

        init(movie: PhucTvMovieCard = .empty) {
            self.movie = movie
        }

        var title: String {
            detail?.title ?? movie.displayTitle
        }

        var subtitle: String {
            nonEmpty(detail?.otherName) ?? movie.displaySubtitle
        }

        var summary: String {
            detail?.description ?? movie.description
        }

        var overviewText: String {
            nonEmpty(detail?.moreInfo) ?? summary
        }

        var metadataPills: [String] {
            [
                (detail?.year ?? 0) > 0 ? String(detail?.year ?? 0) : nil,
                (detail?.ratePoint ?? 0) > 0 ? String(format: "%.1f", detail?.ratePoint ?? 0) : nil,
                nonEmpty(detail?.quality),
                nonEmpty(detail?.statusText),
                nonEmpty(detail?.statusRaw),
                (detail?.viewNumber ?? 0) > 0 ? formatCount(detail?.viewNumber ?? 0) : nil,
                nonEmpty(detail?.time),
                (detail?.episodesTotal ?? 0) > 0 ? "\(detail?.episodesTotal ?? 0) eps" : nil
            ]
            .compactMap { $0 }
        }

        var availableTabs: [DetailSectionTab] {
            detail?.availableTabs ?? []
        }

        var hasRenderableContent: Bool {
            availableTabs.isEmpty == false
        }

        var effectiveSelectedTab: DetailSectionTab {
            if let selectedTab, availableTabs.contains(selectedTab) {
                return selectedTab
            }

            return detail?.defaultTab ?? .synopsis
        }

        var backDropURL: String {
            detail?.displayBackdrop ?? movie.displayBanner
        }

        var trailerURL: String? {
            nonEmpty(detail?.trailer) ?? nonEmpty(movie.trailer)
        }

        var primaryEpisode: PhucTvMovieEpisode? {
            detail?.episodes.first
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadResponse(Result<LoadResult, LoadError>)
        case retryTapped
        case tabSelected(DetailSectionTab)
        case likeToggled
        case likeToggleResponse(Result<Bool, LoadError>)
        case refreshEpisodeProgress
        case episodeProgressResponse([Int: PhucTvPlaybackProgressSnapshot])
        case playEpisodeTapped(PhucTvMovieEpisode)
        case backButtonTapped
        case searchTapped
        case relatedMovieTapped(PhucTvMovieCard)
    }

    @Dependency(\.phucTvRepository) var repository
    @Dependency(\.phucTvLikedMovieStore) var likedMovieStore
    @Dependency(\.phucTvPlaybackPositionStore) var playbackPositionStore

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.screenState != .loaded || state.detail == nil else {
                    return .send(.refreshEpisodeProgress)
                }
                state.screenState = .loading
                state.detail = nil
                state.selectedTab = nil
                state.isLiked = false
                state.episodeProgressById = [:]
                return loadDetail(for: state.movie)

            case .retryTapped:
                state.screenState = .loading
                state.detail = nil
                state.selectedTab = nil
                state.isLiked = false
                state.episodeProgressById = [:]
                return loadDetail(for: state.movie)

            case let .loadResponse(.success(response)):
                state.detail = response.detail
                state.screenState = .loaded
                state.selectedTab = response.detail.defaultTab
                state.isLiked = response.isLiked
                state.episodeProgressById = response.episodeProgressById
                return .none

            case let .loadResponse(.failure(error)):
                state.screenState = .error(message: error.message)
                return .none

            case let .tabSelected(tab):
                guard state.availableTabs.contains(tab) else {
                    return .none
                }
                state.selectedTab = tab
                return .none

            case .likeToggled:
                guard let detail = state.detail else {
                    return .none
                }
                return toggleLike(detail: detail)

            case let .likeToggleResponse(.success(isLiked)):
                state.isLiked = isLiked
                return .none

            case .likeToggleResponse(.failure):
                return .none

            case .refreshEpisodeProgress:
                guard let detail = state.detail else {
                    return .none
                }
                return refreshEpisodeProgress(detail: detail)

            case let .episodeProgressResponse(progressById):
                state.episodeProgressById = progressById
                return .none

            case .playEpisodeTapped, .backButtonTapped, .searchTapped, .relatedMovieTapped:
                return .none
            }
        }
    }

    private func loadDetail(for movie: PhucTvMovieCard) -> Effect<Action> {
        let repository = repository
        let likedMovieStore = likedMovieStore
        let playbackPositionStore = playbackPositionStore

        return .run { send in
            do {
                let slug = movie.link.isEmpty ? String(movie.id) : movie.link
                let detail = try await repository.loadDetail(slug: slug)

                async let likedTask: Bool = {
                    do {
                        return try await likedMovieStore.isLiked(movieID: detail.id)
                    } catch {
                        PhucTvLogger.shared.error(
                            error,
                            message: "Detail liked-state load failed",
                            metadata: [
                                "movie_id": String(detail.id)
                            ]
                        )
                        return false
                    }
                }()
                async let progressTask = loadEpisodeProgress(
                    for: detail,
                    playbackPositionStore: playbackPositionStore
                )

                let response = LoadResult(
                    detail: detail,
                    isLiked: await likedTask,
                    episodeProgressById: await progressTask
                )
                await send(.loadResponse(.success(response)))
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Detail load failed",
                    metadata: [
                        "movie_id": String(movie.id),
                        "movie_slug": movie.link,
                    ]
                )
                await send(.loadResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func toggleLike(detail: PhucTvMovieDetail) -> Effect<Action> {
        let likedMovieStore = likedMovieStore

        return .run { send in
            do {
                _ = try await likedMovieStore.toggle(movie: detail.movie)
                let isLiked = try await likedMovieStore.isLiked(movieID: detail.id)
                await send(.likeToggleResponse(.success(isLiked)))
            } catch is CancellationError {
                return
            } catch {
                PhucTvLogger.shared.error(
                    error,
                    message: "Detail toggleLike failed",
                    metadata: [
                        "movie_id": String(detail.id)
                    ]
                )
                await send(.likeToggleResponse(.failure(.init(error))))
            }
        }
        .cancellable(id: CancelID.toggleLike, cancelInFlight: true)
    }

    private func refreshEpisodeProgress(detail: PhucTvMovieDetail) -> Effect<Action> {
        let playbackPositionStore = playbackPositionStore

        return .run { send in
            let progressById = await loadEpisodeProgress(
                for: detail,
                playbackPositionStore: playbackPositionStore
            )
            await send(.episodeProgressResponse(progressById))
        }
        .cancellable(id: CancelID.refreshProgress, cancelInFlight: true)
    }

    private func loadEpisodeProgress(
        for detail: PhucTvMovieDetail,
        playbackPositionStore: PhucTvPlaybackPositionStoreClient
    ) async -> [Int: PhucTvPlaybackProgressSnapshot] {
        guard detail.episodes.isEmpty == false else {
            return [:]
        }

        var result: [Int: PhucTvPlaybackProgressSnapshot] = [:]
        await withTaskGroup(of: (Int, PhucTvPlaybackProgressSnapshot?).self) { group in
            for episode in detail.episodes {
                group.addTask {
                    do {
                        let snapshot = try await playbackPositionStore.load(
                            movieID: detail.id,
                            episodeID: episode.id
                        )
                        return (episode.id, snapshot)
                    } catch is CancellationError {
                        return (episode.id, nil)
                    } catch {
                        PhucTvLogger.shared.error(
                            error,
                            message: "Detail episode progress load failed",
                            metadata: [
                                "movie_id": String(detail.id),
                                "episode_id": String(episode.id),
                            ]
                        )
                        return (episode.id, nil)
                    }
                }
            }

            for await (episodeID, snapshot) in group {
                if let snapshot {
                    result[episodeID] = snapshot
                }
            }
        }

        return result
    }
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func formatCount(_ value: Int) -> String {
    switch value {
    case 1_000_000...:
        return String(format: "%.1fM", Double(value) / 1_000_000.0)
    case 1_000...:
        return String(format: "%.1fk", Double(value) / 1_000.0)
    default:
        return "\(value)"
    }
}
