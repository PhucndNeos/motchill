import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    @ObservationIgnored
    private let repository: MotchillRepository
    var selectedMovie: MotchillMovieCard?
    var selectedSection: MotchillHomeSection?
    var state: HomeScreenState

    init(
        repository: MotchillRepository,
        state: HomeScreenState = .loading
    ) {
        self.repository = repository
        self.state = state
    }

    var loadedContent: HomeFeedContent? {
        if case let .loaded(content) = state {
            return content
        }
        return nil
    }

    var sections: [MotchillHomeSection] {
        loadedContent?.sections ?? []
    }

    var heroSection: MotchillHomeSection? {
        sections.first(where: { $0.key == "slide" }) ?? sections.first
    }

    var heroMovies: [MotchillMovieCard] {
        Array(heroSection?.products.prefix(6) ?? [])
    }

    var contentSections: [MotchillHomeSection] {
        guard sections.contains(where: { $0.key == "slide" }) else {
            return sections
        }

        return sections.filter { $0.key != "slide" }
    }

    var hasRenderableContent: Bool {
        sections.contains(where: { !$0.products.isEmpty })
    }

    func load() async {
        state = .loading

        do {
            let sections = try await repository.loadHome()
            if sections.isEmpty {
                state = .empty
            } else {
                state = .loaded(HomeFeedContent(sections: sections))
                if selectedSection == nil {
                    selectedSection = sections.first
                }
                if selectedMovie == nil {
                    selectedMovie = selectedSection?.products.first
                }
            }
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Home load failed",
                metadata: [
                    "state": "home",
                ]
            )
            state = .error(message: error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }

    static func previewLoaded() -> HomeViewModel {
        HomeViewModel(
            repository: PreviewHomeRepository(sections: HomeMockData.loadedSections),
            state: .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
        )
    }

    static func previewLoading() -> HomeViewModel {
        HomeViewModel(
            repository: PreviewHomeRepository(sections: HomeMockData.emptySections),
            state: .loading
        )
    }

    static func previewEmpty() -> HomeViewModel {
        HomeViewModel(
            repository: PreviewHomeRepository(sections: HomeMockData.emptySections),
            state: .empty
        )
    }

    static func previewError() -> HomeViewModel {
        HomeViewModel(
            repository: PreviewHomeRepository(sections: HomeMockData.loadedSections),
            state: .error(message: "Không thể tải nội dung ngay lúc này.")
        )
    }
}

private struct PreviewHomeRepository: MotchillRepository {
    let sections: [MotchillHomeSection]

    func loadHome() async throws -> [MotchillHomeSection] {
        sections
    }

    func loadNavbar() async throws -> [MotchillNavbarItem] {
        []
    }

    func loadDetail(slug: String) async throws -> MotchillMovieDetail {
        throw NSError(domain: "PreviewHomeRepository", code: 1)
    }

    func loadPreview(slug: String) async throws -> MotchillMovieDetail {
        throw NSError(domain: "PreviewHomeRepository", code: 1)
    }

    func loadSearchFilters() async throws -> MotchillSearchFilterData {
        throw NSError(domain: "PreviewHomeRepository", code: 1)
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
    ) async throws -> MotchillSearchResults {
        throw NSError(domain: "PreviewHomeRepository", code: 1)
    }

    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [MotchillPlaySource] {
        throw NSError(domain: "PreviewHomeRepository", code: 1)
    }

    func loadPopupAd() async throws -> MotchillPopupAdConfig? {
        nil
    }
}
