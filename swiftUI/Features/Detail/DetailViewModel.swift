import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {
    @ObservationIgnored
    private let repository: MotchillRepository
    @ObservationIgnored
    private let likedMovieStore: MotchillLikedMovieStoring
    @ObservationIgnored
    private let playbackPositionStore: MotchillPlaybackPositionStoring

    let movie: MotchillMovieCard

    var state: DetailScreenState = .idle
    var detail: MotchillMovieDetail?
    var selectedTab: DetailSectionTab?
    var isLiked = false
    var episodeProgressById: [Int: MotchillPlaybackProgressSnapshot] = [:]

    init(
        movie: MotchillMovieCard,
        repository: MotchillRepository,
        likedMovieStore: MotchillLikedMovieStoring,
        playbackPositionStore: MotchillPlaybackPositionStoring
    ) {
        self.movie = movie
        self.repository = repository
        self.likedMovieStore = likedMovieStore
        self.playbackPositionStore = playbackPositionStore
    }

    var movieDetail: MotchillMovieDetail? {
        detail
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
        detail?.availableTabs.isEmpty == false
    }

    var effectiveSelectedTab: DetailSectionTab {
        if let selectedTab, availableTabs.contains(selectedTab) {
            return selectedTab
        }
        return detail?.defaultTab ?? .synopsis
    }

    func load() async {
        state = .loading

        do {
            let slug = movie.link.isEmpty ? String(movie.id) : movie.link
            let detail = try await repository.loadDetail(slug: slug)
            self.detail = detail
            self.selectedTab = detail.defaultTab
            self.isLiked = try await likedMovieStore.isLiked(movieID: detail.id)
            self.episodeProgressById = await loadEpisodeProgress(for: detail)
            state = .loaded
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Detail load failed",
                metadata: [
                    "movie_id": String(movie.id),
                    "movie_slug": movie.link,
                ]
            )
            state = .error(message: error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }

    func selectTab(_ tab: DetailSectionTab) {
        guard availableTabs.contains(tab) else { return }
        selectedTab = tab
    }

    func toggleLike() async {
        guard let detail else { return }
        do {
            _ = try await likedMovieStore.toggle(movie: detail.movie)
            isLiked = try await likedMovieStore.isLiked(movieID: detail.id)
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Detail toggleLike failed",
                metadata: [
                    "movie_id": String(detail.id)
                ]
            )
        }
    }

    func refreshEpisodeProgress() async {
        guard let detail else { return }
        episodeProgressById = await loadEpisodeProgress(for: detail)
    }

    func backDropURL() -> String {
        detail?.displayBackdrop ?? movie.displayBanner
    }

    func trailerURL() -> String? {
        let trailer = nonEmpty(detail?.trailer) ?? nonEmpty(movie.trailer)
        return trailer
    }

    private func loadEpisodeProgress(for detail: MotchillMovieDetail) async -> [Int: MotchillPlaybackProgressSnapshot] {
        var result: [Int: MotchillPlaybackProgressSnapshot] = [:]
        for episode in detail.episodes {
            if let progress = try? await playbackPositionStore.load(movieID: detail.id, episodeID: episode.id) {
                result[episode.id] = progress
            }
        }
        return result
    }

    static func previewLoaded() -> DetailViewModel {
        DetailViewModel(
            movie: DetailMockData.movie,
            repository: PreviewDetailRepository(detail: DetailMockData.detail),
            likedMovieStore: PreviewLikedStore(isLiked: true),
            playbackPositionStore: PreviewPlaybackStore()
        )
    }

    static func previewLoading() -> DetailViewModel {
        DetailViewModel(
            movie: DetailMockData.movie,
            repository: PreviewDetailRepository(detail: DetailMockData.emptyDetail),
            likedMovieStore: PreviewLikedStore(isLiked: false),
            playbackPositionStore: PreviewPlaybackStore()
        )
    }

    static func previewError() -> DetailViewModel {
        DetailViewModel(
            movie: DetailMockData.movie,
            repository: PreviewDetailRepository(error: NSError(domain: "PreviewDetailRepository", code: 1)),
            likedMovieStore: PreviewLikedStore(isLiked: false),
            playbackPositionStore: PreviewPlaybackStore()
        )
    }
}

private struct PreviewDetailRepository: MotchillRepository {
    let detail: MotchillMovieDetail?
    let error: Error?

    init(detail: MotchillMovieDetail) {
        self.detail = detail
        self.error = nil
    }

    init(error: Error) {
        self.detail = nil
        self.error = error
    }

    func loadHome() async throws -> [MotchillHomeSection] { [] }
    func loadNavbar() async throws -> [MotchillNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> MotchillMovieDetail {
        if let error { throw error }
        return detail ?? DetailMockData.emptyDetail
    }
    func loadPreview(slug: String) async throws -> MotchillMovieDetail { try await loadDetail(slug: slug) }
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
    ) async throws -> [MotchillPlaySource] { [] }
    func loadPopupAd() async throws -> MotchillPopupAdConfig? { nil }
}

private struct PreviewLikedStore: MotchillLikedMovieStoring {
    let isLiked: Bool

    func loadMovies() async throws -> [MotchillMovieCard] { isLiked ? [DetailMockData.movie] : [] }
    func loadIDs() async throws -> Set<Int> { isLiked ? [DetailMockData.movie.id] : [] }
    func isLiked(movieID: Int) async throws -> Bool { isLiked && movieID == DetailMockData.movie.id }
    func toggle(movie: MotchillMovieCard) async throws -> [MotchillMovieCard] { [movie] }
}

private struct PreviewPlaybackStore: MotchillPlaybackPositionStoring {
    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
    }

    func load(movieID: Int, episodeID: Int) async throws -> MotchillPlaybackProgressSnapshot? {
        MotchillPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
    }
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

private func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
