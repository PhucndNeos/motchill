import XCTest
@testable import PhucTvSwiftUI

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadPopulatesLoadedState() async {
        let store = StubRemoteConfigStore()
        let client = StubRemoteConfigClient(
            result: .success(
                PhucTvRemoteConfig(
                    domain: "https://motchilltv.date",
                    key: "sB7hP!c9X3@rVn$5mGqT1eLzK!fU8dA2"
                )
            )
        )
        let repository = StubHomeRepository(
            result: .success(HomeMockData.loadedSections),
            onLoadHome: {
                XCTAssertEqual(client.loadCount, 1)
                XCTAssertNotNil(store.current)
            }
        )
        let viewModel = HomeViewModel(
            repository: repository,
            remoteConfigClient: client,
            remoteConfigStore: store
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.sections.count, HomeMockData.loadedSections.count)
        XCTAssertEqual(viewModel.heroMovies.count, 6)
        XCTAssertFalse(viewModel.contentSections.isEmpty)
        XCTAssertEqual(client.loadCount, 1)
        XCTAssertEqual(store.current?.domain, "https://motchilltv.date")
    }

    func testLoadShowsErrorStateOnFailure() async {
        let client = StubRemoteConfigClient()
        let repository = StubHomeRepository(result: .failure(StubError.failed))
        let viewModel = HomeViewModel(repository: repository, remoteConfigClient: client)

        await viewModel.load()

        if case let .error(message) = viewModel.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testLoadStopsWhenRemoteConfigFails() async {
        let client = StubRemoteConfigClient(result: .failure(StubError.failed))
        let repository = StubHomeRepository(result: .success(HomeMockData.loadedSections)) {
            XCTFail("Repository should not be called when remote config fails")
        }
        let viewModel = HomeViewModel(repository: repository, remoteConfigClient: client)

        await viewModel.load()

        if case .error = viewModel.state {
        } else {
            XCTFail("Expected error state")
        }
        XCTAssertEqual(client.loadCount, 1)
    }

    func testPreviewLoadedProvidesHeroMovies() {
        let viewModel = HomeViewModel.previewLoaded()

        XCTAssertEqual(viewModel.heroMovies.count, 6)
        XCTAssertEqual(viewModel.heroMovies.first?.id, HomeMockData.loadedSections[0].products.first?.id)
    }

    func testRetryRestoresLoadedPreviewState() async {
        let viewModel = HomeViewModel.previewError()

        XCTAssertNil(viewModel.loadedContent)

        await viewModel.retry()

        XCTAssertEqual(viewModel.sections.count, HomeMockData.loadedSections.count)
        XCTAssertEqual(viewModel.heroMovies.count, 6)
    }
}

private final class StubHomeRepository: PhucTvRepository, @unchecked Sendable {
    enum Result {
        case success([PhucTvHomeSection])
        case failure(Error)
    }

    let result: Result
    let onLoadHome: () -> Void

    init(result: Result, onLoadHome: @escaping () -> Void = {}) {
        self.result = result
        self.onLoadHome = onLoadHome
    }

    func loadHome() async throws -> [PhucTvHomeSection] {
        onLoadHome()
        switch result {
        case let .success(sections):
            return sections
        case let .failure(error):
            throw error
        }
    }

    func loadNavbar() async throws -> [PhucTvNavbarItem] { [] }
    func loadDetail(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }
    func loadPreview(slug: String) async throws -> PhucTvMovieDetail { throw StubError.failed }
    func loadSearchFilters() async throws -> PhucTvSearchFilterData { throw StubError.failed }
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
    ) async throws -> PhucTvSearchResults { throw StubError.failed }
    func loadEpisodeSources(
        movieID: Int,
        episodeID: Int,
        server: Int
    ) async throws -> [PhucTvPlaySource] { [] }
    func loadPopupAd() async throws -> PhucTvPopupAdConfig? { nil }
}

private enum StubError: Error {
    case failed
}

private final class StubRemoteConfigClient: PhucTvRemoteConfigLoading {
    private(set) var loadCount = 0
    let result: Swift.Result<PhucTvRemoteConfig, Error>

    init(result: Swift.Result<PhucTvRemoteConfig, Error> = .success(
        PhucTvRemoteConfig(
            domain: "https://motchilltv.date",
            key: "sB7hP!c9X3@rVn$5mGqT1eLzK!fU8dA2"
        )
    )) {
        self.result = result
    }

    func fetchRemoteConfig() async throws -> PhucTvRemoteConfig {
        loadCount += 1
        return try result.get()
    }
}

private final class StubRemoteConfigStore: PhucTvRemoteConfigStoring {
    private(set) var current: PhucTvRemoteConfig?

    func update(_ config: PhucTvRemoteConfig?) {
        current = config
    }

    func reset() {
        current = nil
    }
}
