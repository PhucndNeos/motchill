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
