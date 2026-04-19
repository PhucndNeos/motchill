import ComposableArchitecture
import Foundation
import Testing

@testable import PhucTV

@MainActor
struct HomeFeatureTests {
    init() {
        uncheckedUseMainSerialExecutor = true
    }

    @Test
    func onTaskLoadsHomeAndSeedsSelection() async {
        let remoteConfig = PhucTvRemoteConfig(
            domain: "https://motchilltv.date",
            key: "remote-config-key"
        )
        let remoteConfigStore = RemoteConfigStoreSpy()
        let repository = HomeRepositorySpy(
            results: [.success(HomeMockData.loadedSections)]
        ) {
            #expect(remoteConfigStore.current?.domain == remoteConfig.domain)
        }

        let store = makeStore(
            repository: repository,
            remoteConfigResult: .success(remoteConfig),
            remoteConfigStore: remoteConfigStore
        )

        await store.send(.onTask)

        await store.receive(.loadResponse(.success(HomeMockData.loadedSections))) {
            $0.status = .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
            $0.selectedSection = HomeMockData.loadedSections.first
            $0.selectedMovie = HomeMockData.loadedSections.first?.products.first
        }

        #expect(repository.loadHomeCount == 1)
        #expect(remoteConfigStore.current?.domain == remoteConfig.domain)
        #expect(store.state.sections.count == HomeMockData.loadedSections.count)
        #expect(store.state.heroMovies.count == 6)
        #expect(store.state.contentSections.count == 3)
        #expect(store.state.selectedSection?.id == HomeMockData.loadedSections.first?.id)
        #expect(store.state.selectedMovie?.id == HomeMockData.loadedSections.first?.products.first?.id)
    }

    @Test
    func remoteConfigFailureStopsRepositoryLoad() async {
        let remoteConfigStore = RemoteConfigStoreSpy()
        let repository = HomeRepositorySpy(
            results: [.success(HomeMockData.loadedSections)]
        )
        let store = makeStore(
            repository: repository,
            remoteConfigResult: .failure(StubError.failed),
            remoteConfigStore: remoteConfigStore
        )

        await store.send(.onTask)

        await store.receive(.loadResponse(.failure(.init(StubError.failed)))) {
            $0.status = .error(message: "failed")
        }

        #expect(repository.loadHomeCount == 0)
        #expect(remoteConfigStore.current == nil)
        #expect(store.state.status == .error(message: "failed"))
    }

    @Test
    func repositoryFailureSetsErrorState() async {
        let remoteConfigStore = RemoteConfigStoreSpy()
        let repository = HomeRepositorySpy(
            results: [.failure(StubError.failed)]
        )
        let store = makeStore(
            repository: repository,
            remoteConfigResult: .success(
                PhucTvRemoteConfig(domain: "https://motchilltv.date", key: "remote-config-key")
            ),
            remoteConfigStore: remoteConfigStore
        )

        await store.send(.onTask)

        await store.receive(.loadResponse(.failure(.init(StubError.failed)))) {
            $0.status = .error(message: "failed")
        }

        #expect(repository.loadHomeCount == 1)
        #expect(remoteConfigStore.current?.domain == "https://motchilltv.date")
    }

    @Test
    func retryReloadsAfterFailure() async {
        let remoteConfigStore = RemoteConfigStoreSpy()
        let repository = HomeRepositorySpy(
            results: [
                .failure(StubError.failed),
                .success(HomeMockData.loadedSections)
            ]
        )
        let store = makeStore(
            repository: repository,
            remoteConfigResult: .success(
                PhucTvRemoteConfig(domain: "https://motchilltv.date", key: "remote-config-key")
            ),
            remoteConfigStore: remoteConfigStore
        )

        await store.send(.onTask)
        await store.receive(.loadResponse(.failure(.init(StubError.failed)))) {
            $0.status = .error(message: "failed")
        }

        await store.send(.retryTapped) {
            $0.status = .loading
        }

        await store.receive(.loadResponse(.success(HomeMockData.loadedSections))) {
            $0.status = .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
            $0.selectedSection = HomeMockData.loadedSections.first
            $0.selectedMovie = HomeMockData.loadedSections.first?.products.first
        }

        #expect(repository.loadHomeCount == 2)
        #expect(store.state.status == .loaded(HomeFeedContent(sections: HomeMockData.loadedSections)))
    }

    @Test
    func sectionSelectionRebindsMovieToCurrentSection() async {
        let store = makeLoadedStore()
        let targetSection = HomeMockData.loadedSections[1]

        await store.send(\.binding.selectedSection, targetSection) {
            $0.selectedSection = targetSection
            $0.selectedMovie = targetSection.products.first
        }

        #expect(store.state.selectedSection?.id == targetSection.id)
        #expect(store.state.selectedMovie?.id == targetSection.products.first?.id)
    }

    @Test
    func reloadRebindsSelectionToFreshInstances() async {
        let remoteConfigStore = RemoteConfigStoreSpy()
        let repository = HomeRepositorySpy(
            results: [
                .success(HomeMockData.loadedSections),
                .success(HomeMockData.loadedSections)
            ]
        )
        let store = makeStore(
            repository: repository,
            remoteConfigResult: .success(
                PhucTvRemoteConfig(domain: "https://motchilltv.date", key: "remote-config-key")
            ),
            remoteConfigStore: remoteConfigStore
        )

        await store.send(.onTask)

        await store.receive(.loadResponse(.success(HomeMockData.loadedSections))) {
            $0.status = .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
            $0.selectedSection = HomeMockData.loadedSections.first
            $0.selectedMovie = HomeMockData.loadedSections.first?.products.first
        }

        let targetSection = HomeMockData.loadedSections[2]
        let targetMovie = targetSection.products[1]

        await store.send(\.binding.selectedSection, targetSection) {
            $0.selectedSection = targetSection
            $0.selectedMovie = targetSection.products.first
        }

        await store.send(\.binding.selectedMovie, targetMovie) {
            $0.selectedMovie = targetMovie
        }

        await store.send(.retryTapped) {
            $0.status = .loading
        }

        await store.receive(.loadResponse(.success(HomeMockData.loadedSections))) {
            $0.status = .loaded(HomeFeedContent(sections: HomeMockData.loadedSections))
            $0.selectedSection = HomeMockData.loadedSections[2]
            $0.selectedMovie = HomeMockData.loadedSections[2].products[1]
        }

        #expect(store.state.selectedSection?.id == targetSection.id)
        #expect(store.state.selectedMovie?.id == targetMovie.id)
    }

    private func makeStore(
        repository: HomeRepositorySpy,
        remoteConfigResult: Swift.Result<PhucTvRemoteConfig, Error>,
        remoteConfigStore: RemoteConfigStoreSpy
    ) -> TestStore<HomeFeature.State, HomeFeature.Action> {
        let remoteConfigClient = PhucTvRemoteConfigLoadingClient(
            fetchRemoteConfig: {
                try remoteConfigResult.get()
            }
        )

        return TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test(repository: repository))
            $0.phucTvRemoteConfigClient = remoteConfigClient
            $0.phucTvRemoteConfigStore = .init(
                current: { remoteConfigStore.current },
                update: { remoteConfigStore.update($0) },
                reset: { remoteConfigStore.reset() }
            )
        }
    }

    private func makeLoadedStore() -> TestStore<HomeFeature.State, HomeFeature.Action> {
        let store = TestStore(initialState: HomeFeature.State.previewLoaded()) {
            HomeFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(AppDependencies.test())
        }

        return store
    }
}

private final class HomeRepositorySpy: PhucTvRepository, @unchecked Sendable {
    var results: [Swift.Result<[PhucTvHomeSection], Error>]
    private(set) var loadHomeCount = 0
    let onLoadHome: () -> Void

    init(
        results: [Swift.Result<[PhucTvHomeSection], Error>],
        onLoadHome: @escaping () -> Void = {}
    ) {
        self.results = results
        self.onLoadHome = onLoadHome
    }

    func loadHome() async throws -> [PhucTvHomeSection] {
        loadHomeCount += 1
        onLoadHome()
        guard !results.isEmpty else {
            throw StubError.failed
        }
        return try results.removeFirst().get()
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

private final class RemoteConfigStoreSpy: @unchecked Sendable {
    private(set) var current: PhucTvRemoteConfig?

    func update(_ config: PhucTvRemoteConfig?) {
        current = config
    }

    func reset() {
        current = nil
    }
}

private enum StubError: Error {
    case failed
}
