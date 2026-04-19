import ComposableArchitecture
import Foundation
import Supabase

private enum PhucTvLiveDependencyFactory {
    static let configuration = AppConfiguration()

    static let remoteConfigClient: PhucTvRemoteConfigLoading = PhucTvRemoteConfigClient()
    static let remoteConfigStore: PhucTvRemoteConfigStoring = PhucTvRemoteConfigStore.shared
    static let repository: PhucTvRepository = DefaultPhucTvRepository(
        apiClient: PhucTvAPIClient(configuration: configuration)
    )
    static let supabaseClient: SupabaseClient? = makeSupabaseClient(configuration: configuration)
    static let authManager: PhucTvSupabaseAuthManager = PhucTvSupabaseAuthManager(client: supabaseClient)
    static let screenIdleManager: ScreenIdleManaging = LiveScreenIdleManager()
}

@DependencyClient
struct PhucTvRemoteConfigLoadingClient: Sendable {
    var fetchRemoteConfig: @Sendable () async throws -> PhucTvRemoteConfig = {
        PhucTvRemoteConfig(domain: "", key: "")
    }
}

extension PhucTvRemoteConfigLoadingClient: DependencyKey {
    static let liveValue = Self(
        fetchRemoteConfig: {
            try await PhucTvLiveDependencyFactory.remoteConfigClient.fetchRemoteConfig()
        }
    )

    static let previewValue = Self(
        fetchRemoteConfig: {
            PhucTvRemoteConfig(domain: "https://preview.example.com", key: "preview")
        }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvRemoteConfigClient: PhucTvRemoteConfigLoadingClient {
        get { self[PhucTvRemoteConfigLoadingClient.self] }
        set { self[PhucTvRemoteConfigLoadingClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvRemoteConfigStoreClient: Sendable {
    var current: @Sendable () -> PhucTvRemoteConfig? = { nil }
    var update: @Sendable (PhucTvRemoteConfig?) -> Void = { _ in }
    var reset: @Sendable () -> Void = {}
}

extension PhucTvRemoteConfigStoreClient: DependencyKey {
    static let liveValue = Self(
        current: { PhucTvLiveDependencyFactory.remoteConfigStore.current },
        update: { PhucTvLiveDependencyFactory.remoteConfigStore.update($0) },
        reset: { PhucTvLiveDependencyFactory.remoteConfigStore.reset() }
    )

    static let previewValue = Self(
        current: { nil },
        update: { _ in },
        reset: {}
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvRemoteConfigStore: PhucTvRemoteConfigStoreClient {
        get { self[PhucTvRemoteConfigStoreClient.self] }
        set { self[PhucTvRemoteConfigStoreClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvRepositoryClient: Sendable {
    var loadHome: @Sendable () async throws -> [PhucTvHomeSection] = { [] }
    var loadNavbar: @Sendable () async throws -> [PhucTvNavbarItem] = { [] }
    var loadDetail: @Sendable (_ slug: String) async throws -> PhucTvMovieDetail = { _ in Self.placeholderMovieDetail }
    var loadPreview: @Sendable (_ slug: String) async throws -> PhucTvMovieDetail = { _ in Self.placeholderMovieDetail }
    var loadSearchFilters: @Sendable () async throws -> PhucTvSearchFilterData = {
        .init(categories: [], countries: [])
    }
    var loadSearchResults: @Sendable (
        _ categoryId: Int?,
        _ countryId: Int?,
        _ typeRaw: String,
        _ year: String,
        _ orderBy: String,
        _ isChieuRap: Bool,
        _ is4k: Bool,
        _ search: String,
        _ pageNumber: Int
    ) async throws -> PhucTvSearchResults = { _, _, _, _, _, _, _, _, _ in
        .init(records: [], pagination: .init(pageIndex: 1, pageSize: 20, pageCount: 1, totalRecords: 0))
    }
    var loadEpisodeSources: @Sendable (_ movieID: Int, _ episodeID: Int, _ server: Int) async throws -> [PhucTvPlaySource] = { _, _, _ in [] }
    var loadPopupAd: @Sendable () async throws -> PhucTvPopupAdConfig? = { nil }

    private static let placeholderMovieDetail = PhucTvMovieDetail(
        movie: PhucTvMovieCard(
            id: 0,
            name: "Placeholder",
            otherName: "",
            avatar: "",
            bannerThumb: "",
            avatarThumb: "",
            description: "",
            banner: "",
            imageIcon: "",
            link: "",
            quantity: "",
            rating: "",
            year: 0,
            statusTitle: "",
            statusRaw: "",
            statusText: "",
            director: "",
            time: "",
            trailer: "",
            showTimes: "",
            moreInfo: "",
            castString: "",
            episodesTotal: 0,
            viewNumber: 0,
            ratePoint: 0,
            photoUrls: [],
            previewPhotoUrls: []
        ),
        relatedMovies: [],
        countries: [],
        categories: [],
        episodes: []
    )
}

extension PhucTvRepositoryClient: DependencyKey {
    static let liveValue = Self(
        loadHome: { try await PhucTvLiveDependencyFactory.repository.loadHome() },
        loadNavbar: { try await PhucTvLiveDependencyFactory.repository.loadNavbar() },
        loadDetail: { try await PhucTvLiveDependencyFactory.repository.loadDetail(slug: $0) },
        loadPreview: { try await PhucTvLiveDependencyFactory.repository.loadPreview(slug: $0) },
        loadSearchFilters: { try await PhucTvLiveDependencyFactory.repository.loadSearchFilters() },
        loadSearchResults: { categoryId, countryId, typeRaw, year, orderBy, isChieuRap, is4k, search, pageNumber in
            try await PhucTvLiveDependencyFactory.repository.loadSearchResults(
                categoryId: categoryId,
                countryId: countryId,
                typeRaw: typeRaw,
                year: year,
                orderBy: orderBy,
                isChieuRap: isChieuRap,
                is4k: is4k,
                search: search,
                pageNumber: pageNumber
            )
        },
        loadEpisodeSources: { movieID, episodeID, server in
            try await PhucTvLiveDependencyFactory.repository.loadEpisodeSources(
                movieID: movieID,
                episodeID: episodeID,
                server: server
            )
        },
        loadPopupAd: { try await PhucTvLiveDependencyFactory.repository.loadPopupAd() }
    )

    static let previewValue = Self(
        loadHome: { try await AppDependencies.preview().repository.loadHome() },
        loadNavbar: { try await AppDependencies.preview().repository.loadNavbar() },
        loadDetail: { try await AppDependencies.preview().repository.loadDetail(slug: $0) },
        loadPreview: { try await AppDependencies.preview().repository.loadPreview(slug: $0) },
        loadSearchFilters: { try await AppDependencies.preview().repository.loadSearchFilters() },
        loadSearchResults: { categoryId, countryId, typeRaw, year, orderBy, isChieuRap, is4k, search, pageNumber in
            try await AppDependencies.preview().repository.loadSearchResults(
                categoryId: categoryId,
                countryId: countryId,
                typeRaw: typeRaw,
                year: year,
                orderBy: orderBy,
                isChieuRap: isChieuRap,
                is4k: is4k,
                search: search,
                pageNumber: pageNumber
            )
        },
        loadEpisodeSources: { movieID, episodeID, server in
            try await AppDependencies.preview().repository.loadEpisodeSources(
                movieID: movieID,
                episodeID: episodeID,
                server: server
            )
        },
        loadPopupAd: { try await AppDependencies.preview().repository.loadPopupAd() }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvRepository: PhucTvRepositoryClient {
        get { self[PhucTvRepositoryClient.self] }
        set { self[PhucTvRepositoryClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvLikedMovieStoreClient: Sendable {
    var loadMovies: @Sendable () async throws -> [PhucTvMovieCard] = { [] }
    var loadIDs: @Sendable () async throws -> Set<Int> = { [] }
    var isLiked: @Sendable (_ movieID: Int) async throws -> Bool = { _ in false }
    var toggle: @Sendable (_ movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] = { movie in [movie] }
}

extension PhucTvLikedMovieStoreClient: DependencyKey {
    static let liveValue = Self(
        loadMovies: { try await SupabaseLikedMovieStore(client: PhucTvLiveDependencyFactory.supabaseClient).loadMovies() },
        loadIDs: { try await SupabaseLikedMovieStore(client: PhucTvLiveDependencyFactory.supabaseClient).loadIDs() },
        isLiked: { try await SupabaseLikedMovieStore(client: PhucTvLiveDependencyFactory.supabaseClient).isLiked(movieID: $0) },
        toggle: { try await SupabaseLikedMovieStore(client: PhucTvLiveDependencyFactory.supabaseClient).toggle(movie: $0) }
    )

    static let previewValue = Self(
        loadMovies: { try await SupabaseLikedMovieStore(client: AppDependencies.preview().supabaseClient).loadMovies() },
        loadIDs: { try await SupabaseLikedMovieStore(client: AppDependencies.preview().supabaseClient).loadIDs() },
        isLiked: { try await SupabaseLikedMovieStore(client: AppDependencies.preview().supabaseClient).isLiked(movieID: $0) },
        toggle: { try await SupabaseLikedMovieStore(client: AppDependencies.preview().supabaseClient).toggle(movie: $0) }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvLikedMovieStore: PhucTvLikedMovieStoreClient {
        get { self[PhucTvLikedMovieStoreClient.self] }
        set { self[PhucTvLikedMovieStoreClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvPlaybackPositionStoreClient: Sendable {
    var save: @Sendable (_ movieID: Int, _ episodeID: Int, _ positionMillis: Int64, _ durationMillis: Int64) async throws -> Void = { _, _, _, _ in }
    var load: @Sendable (_ movieID: Int, _ episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? = { _, _ in nil }
    var delete: @Sendable (_ movieID: Int, _ episodeID: Int) async throws -> Void = { _, _ in }
}

extension PhucTvPlaybackPositionStoreClient: DependencyKey {
    static let liveValue = Self(
        save: { movieID, episodeID, positionMillis, durationMillis in
            try await SupabasePlaybackPositionStore(client: PhucTvLiveDependencyFactory.supabaseClient).save(
                movieID: movieID,
                episodeID: episodeID,
                positionMillis: positionMillis,
                durationMillis: durationMillis
            )
        },
        load: { movieID, episodeID in
            try await SupabasePlaybackPositionStore(client: PhucTvLiveDependencyFactory.supabaseClient).load(movieID: movieID, episodeID: episodeID)
        },
        delete: { movieID, episodeID in
            try await SupabasePlaybackPositionStore(client: PhucTvLiveDependencyFactory.supabaseClient).delete(movieID: movieID, episodeID: episodeID)
        }
    )

    static let previewValue = Self(
        save: { _, _, _, _ in },
        load: { _, _ in nil },
        delete: { _, _ in }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvPlaybackPositionStore: PhucTvPlaybackPositionStoreClient {
        get { self[PhucTvPlaybackPositionStoreClient.self] }
        set { self[PhucTvPlaybackPositionStoreClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvPlayerSubtitleLoaderClient: Sendable {
    var loadCues: @Sendable (_ track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue] = { _ in [] }
}

extension PhucTvPlayerSubtitleLoaderClient: DependencyKey {
    static let liveValue = Self(
        loadCues: { track in
            try await PlayerSubtitleLoader().loadCues(for: track)
        }
    )

    static let previewValue = Self(
        loadCues: { _ in [] }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvPlayerSubtitleLoader: PhucTvPlayerSubtitleLoaderClient {
        get { self[PhucTvPlayerSubtitleLoaderClient.self] }
        set { self[PhucTvPlayerSubtitleLoaderClient.self] = newValue }
    }
}

@DependencyClient
struct PhucTvAuthManagerClient: Sendable {
    var isAuthenticated: @Sendable () -> Bool = { false }
    var userSummary: @Sendable () -> PhucTvSupabaseUserSummary? = { nil }
    var signInHint: @Sendable () -> String? = { nil }
    var sendOTP: @Sendable (_ email: String) async throws -> Void = { _ in }
    var verifyOTP: @Sendable (_ email: String, _ token: String) async throws -> Void = { _, _ in }
    var refreshSessionState: @Sendable () async -> Void = {}
    var signOut: @Sendable () async -> Void = {}
    var handle: @Sendable (URL) -> Void = { _ in }
}

extension PhucTvAuthManagerClient: DependencyKey {
    static let liveValue = Self(
        isAuthenticated: { PhucTvLiveDependencyFactory.authManager.isAuthenticated },
        userSummary: { PhucTvLiveDependencyFactory.authManager.userSummary },
        signInHint: { PhucTvLiveDependencyFactory.authManager.signInHint },
        sendOTP: { email in try await PhucTvLiveDependencyFactory.authManager.sendOTP(email: email) },
        verifyOTP: { email, token in try await PhucTvLiveDependencyFactory.authManager.verifyOTP(email: email, token: token) },
        refreshSessionState: { await PhucTvLiveDependencyFactory.authManager.refreshSessionState() },
        signOut: { await PhucTvLiveDependencyFactory.authManager.signOut() },
        handle: { PhucTvLiveDependencyFactory.authManager.handle($0) }
    )

    static let previewValue = Self(
        isAuthenticated: { AppDependencies.preview().authManager.isAuthenticated },
        userSummary: { AppDependencies.preview().authManager.userSummary },
        signInHint: { AppDependencies.preview().authManager.signInHint },
        sendOTP: { _ in },
        verifyOTP: { _, _ in },
        refreshSessionState: { await AppDependencies.preview().authManager.refreshSessionState() },
        signOut: { await AppDependencies.preview().authManager.signOut() },
        handle: { AppDependencies.preview().authManager.handle($0) }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvAuthManager: PhucTvAuthManagerClient {
        get { self[PhucTvAuthManagerClient.self] }
        set { self[PhucTvAuthManagerClient.self] = newValue }
    }
}

@DependencyClient
struct ScreenIdleManagerClient: Sendable {
    var disableAutoLock: @Sendable () -> Void = {}
    var enableAutoLock: @Sendable () -> Void = {}
    var reset: @Sendable () -> Void = {}
}

extension ScreenIdleManagerClient: DependencyKey {
    static let liveValue = Self(
        disableAutoLock: { PhucTvLiveDependencyFactory.screenIdleManager.disableAutoLock() },
        enableAutoLock: { PhucTvLiveDependencyFactory.screenIdleManager.enableAutoLock() },
        reset: { PhucTvLiveDependencyFactory.screenIdleManager.reset() }
    )

    static let previewValue = Self(
        disableAutoLock: { AppDependencies.preview().screenIdleManager.disableAutoLock() },
        enableAutoLock: { AppDependencies.preview().screenIdleManager.enableAutoLock() },
        reset: { AppDependencies.preview().screenIdleManager.reset() }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var phucTvScreenIdleManager: ScreenIdleManagerClient {
        get { self[ScreenIdleManagerClient.self] }
        set { self[ScreenIdleManagerClient.self] = newValue }
    }
}

extension PhucTvRepositoryClient {
    init(_ dependencies: AppDependencies) {
        self.init(
            loadHome: { try await dependencies.repository.loadHome() },
            loadNavbar: { try await dependencies.repository.loadNavbar() },
            loadDetail: { try await dependencies.repository.loadDetail(slug: $0) },
            loadPreview: { try await dependencies.repository.loadPreview(slug: $0) },
            loadSearchFilters: { try await dependencies.repository.loadSearchFilters() },
            loadSearchResults: { categoryId, countryId, typeRaw, year, orderBy, isChieuRap, is4k, search, pageNumber in
                try await dependencies.repository.loadSearchResults(
                    categoryId: categoryId,
                    countryId: countryId,
                    typeRaw: typeRaw,
                    year: year,
                    orderBy: orderBy,
                    isChieuRap: isChieuRap,
                    is4k: is4k,
                    search: search,
                    pageNumber: pageNumber
                )
            },
            loadEpisodeSources: { movieID, episodeID, server in
                try await dependencies.repository.loadEpisodeSources(
                    movieID: movieID,
                    episodeID: episodeID,
                    server: server
                )
            },
            loadPopupAd: { try await dependencies.repository.loadPopupAd() }
        )
    }
}

extension PhucTvLikedMovieStoreClient {
    init(_ dependencies: AppDependencies) {
        self.init(
            loadMovies: { try await dependencies.likedMovieStore.loadMovies() },
            loadIDs: { try await dependencies.likedMovieStore.loadIDs() },
            isLiked: { try await dependencies.likedMovieStore.isLiked(movieID: $0) },
            toggle: { try await dependencies.likedMovieStore.toggle(movie: $0) }
        )
    }
}

extension PhucTvPlaybackPositionStoreClient {
    init(_ dependencies: AppDependencies) {
        self.init(
            save: { movieID, episodeID, positionMillis, durationMillis in
                try await dependencies.playbackPositionStore.save(
                    movieID: movieID,
                    episodeID: episodeID,
                    positionMillis: positionMillis,
                    durationMillis: durationMillis
                )
            },
            load: { movieID, episodeID in
                try await dependencies.playbackPositionStore.load(movieID: movieID, episodeID: episodeID)
            },
            delete: { movieID, episodeID in
                try await dependencies.playbackPositionStore.delete(movieID: movieID, episodeID: episodeID)
            }
        )
    }
}

extension PhucTvAuthManagerClient {
    init(_ dependencies: AppDependencies) {
        self.init(
            isAuthenticated: { dependencies.authManager.isAuthenticated },
            userSummary: { dependencies.authManager.userSummary },
            signInHint: { dependencies.authManager.signInHint },
            sendOTP: { email in try await dependencies.authManager.sendOTP(email: email) },
            verifyOTP: { email, token in try await dependencies.authManager.verifyOTP(email: email, token: token) },
            refreshSessionState: { await dependencies.authManager.refreshSessionState() },
            signOut: { await dependencies.authManager.signOut() },
            handle: { dependencies.authManager.handle($0) }
        )
    }
}

extension ScreenIdleManagerClient {
    init(_ dependencies: AppDependencies) {
        self.init(
            disableAutoLock: { dependencies.screenIdleManager.disableAutoLock() },
            enableAutoLock: { dependencies.screenIdleManager.enableAutoLock() },
            reset: { dependencies.screenIdleManager.reset() }
        )
    }
}

extension DependencyValues {
    mutating func configurePhucTvDependencies(_ dependencies: AppDependencies) {
        phucTvRepository = .init(dependencies)
        phucTvLikedMovieStore = .init(dependencies)
        phucTvPlaybackPositionStore = .init(dependencies)
        phucTvAuthManager = .init(dependencies)
        phucTvRemoteConfigClient = .liveValue
        phucTvRemoteConfigStore = .liveValue
        phucTvScreenIdleManager = .init(dependencies)
    }
}
