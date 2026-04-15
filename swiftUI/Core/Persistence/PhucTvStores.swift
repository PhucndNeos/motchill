import Foundation

protocol PhucTvLikedMovieStoring: Sendable {
    func loadMovies() async throws -> [PhucTvMovieCard]
    func loadIDs() async throws -> Set<Int>
    func isLiked(movieID: Int) async throws -> Bool
    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard]
}

protocol PhucTvPlaybackPositionStoring: Sendable {
    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot?

    func delete(movieID: Int, episodeID: Int) async throws
}

extension PhucTvPlaybackPositionStoring {
    // Default no-op — remote stores do not need local deletion logic.
    func delete(movieID: Int, episodeID: Int) async throws {}
}

struct PhucTvLegacyLocalDataPayload: Sendable {
    let likedMovies: [PhucTvMovieCard]
    let playbackPositions: [PhucTvLegacyPlaybackPosition]

    var isEmpty: Bool {
        likedMovies.isEmpty && playbackPositions.isEmpty
    }
}

struct PhucTvLegacyPlaybackPosition: Sendable {
    let movieID: Int
    let episodeID: Int
    let snapshot: PhucTvPlaybackProgressSnapshot
}

extension UserDefaults {
    func phucTvLoadLegacyDataPayload() throws -> PhucTvLegacyLocalDataPayload {
        let likedMovies = try phucTvLoadLegacyLikedMovies()
        let playbackPositions = try phucTvLoadLegacyPlaybackPositions()
        return PhucTvLegacyLocalDataPayload(
            likedMovies: likedMovies,
            playbackPositions: playbackPositions
        )
    }

    func phucTvClearLegacyData() {
        removeObject(forKey: UserDefaultsPhucTvLikedMovieStore.moviesKey)
        removeObject(forKey: UserDefaultsPhucTvLikedMovieStore.movieIDsKey)

        for key in dictionaryRepresentation().keys where key.hasPrefix(UserDefaultsPhucTvPlaybackPositionStore.keyPrefix) {
            removeObject(forKey: key)
        }
    }

    private func phucTvLoadLegacyLikedMovies() throws -> [PhucTvMovieCard] {
        let encodedMovies = array(forKey: UserDefaultsPhucTvLikedMovieStore.moviesKey) as? [Data] ?? []
        if !encodedMovies.isEmpty {
            return try encodedMovies.map { try JSONDecoder().decode(PhucTvMovieCard.self, from: $0) }
        }

        let ids = array(forKey: UserDefaultsPhucTvLikedMovieStore.movieIDsKey) as? [Int] ?? []
        return ids.map { movieID in
            PhucTvMovieCard(
                id: movieID,
                name: "Movie \(movieID)",
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
            )
        }
    }

    private func phucTvLoadLegacyPlaybackPositions() throws -> [PhucTvLegacyPlaybackPosition] {
        dictionaryRepresentation()
            .compactMap { key, value in
                guard key.hasPrefix(UserDefaultsPhucTvPlaybackPositionStore.keyPrefix) else {
                    return nil
                }
                guard
                    let data = value as? Data,
                    let record = UserDefaultsPhucTvPlaybackPositionStore.record(from: key, data: data)
                else {
                    return nil
                }
                return record
            }
    }
}

actor UserDefaultsPhucTvLikedMovieStore: PhucTvLikedMovieStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadMovies() async throws -> [PhucTvMovieCard] {
        let encodedMovies = defaults.array(forKey: Self.moviesKey) as? [Data] ?? []
        if !encodedMovies.isEmpty {
            return try encodedMovies.map { try JSONDecoder().decode(PhucTvMovieCard.self, from: $0) }
        }

        let ids = defaults.array(forKey: Self.movieIDsKey) as? [Int] ?? []
        return ids.map { movieID in
            PhucTvMovieCard(
                id: movieID,
                name: "Movie \(movieID)",
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
            )
        }
    }

    func loadIDs() async throws -> Set<Int> {
        Set(try await loadMovies().map(\.id))
    }

    func isLiked(movieID: Int) async throws -> Bool {
        try await loadIDs().contains(movieID)
    }

    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] {
        var current = try await loadMovies()
        if let index = current.firstIndex(where: { $0.id == movie.id }) {
            current.remove(at: index)
        } else {
            current.append(movie)
        }
        try saveMovies(current)
        return current
    }

    private func saveMovies(_ movies: [PhucTvMovieCard]) throws {
        let data = try movies.map { try JSONEncoder().encode($0) }
        defaults.set(data, forKey: Self.moviesKey)
        defaults.set(movies.map(\.id), forKey: Self.movieIDsKey)
    }

    static let moviesKey = "liked_movies"
    static let movieIDsKey = "liked_movie_ids"
}

actor UserDefaultsPhucTvPlaybackPositionStore: PhucTvPlaybackPositionStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
        let snapshot = PhucTvPlaybackProgressSnapshot(
            positionMillis: positionMillis,
            durationMillis: max(durationMillis, 0)
        )
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: Self.key(movieID: movieID, episodeID: episodeID))
    }

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        guard let data = defaults.data(forKey: Self.key(movieID: movieID, episodeID: episodeID)) else {
            return nil
        }
        return try JSONDecoder().decode(PhucTvPlaybackProgressSnapshot.self, from: data)
    }

    func delete(movieID: Int, episodeID: Int) async throws {
        defaults.removeObject(forKey: Self.key(movieID: movieID, episodeID: episodeID))
    }

    static let keyPrefix = "playback_position:"

    static func key(movieID: Int, episodeID: Int) -> String {
        "\(keyPrefix)\(movieID):\(episodeID)"
    }

    static func record(from key: String, data: Data) -> PhucTvLegacyPlaybackPosition? {
        let prefix = keyPrefix
        guard key.hasPrefix(prefix) else { return nil }
        let raw = key.dropFirst(prefix.count)
        let components = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2,
              let movieID = Int(components[0]),
              let episodeID = Int(components[1]) else {
            return nil
        }
        guard let snapshot = try? JSONDecoder().decode(PhucTvPlaybackProgressSnapshot.self, from: data) else {
            return nil
        }
        return PhucTvLegacyPlaybackPosition(
            movieID: movieID,
            episodeID: episodeID,
            snapshot: snapshot
        )
    }
}
