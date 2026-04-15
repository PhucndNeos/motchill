import Foundation
import Supabase

private struct PhucTvLikedMovieRow: Codable, Sendable {
    let userID: UUID
    let movieID: Int
    let movieSnapshot: PhucTvMovieCard
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case movieID = "movie_id"
        case movieSnapshot = "movie_snapshot"
        case createdAt = "created_at"
    }
}

private struct PhucTvPlaybackPositionRow: Codable, Sendable {
    let userID: UUID
    let movieID: Int
    let episodeID: Int
    let positionMillis: Int64
    let durationMillis: Int64
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case movieID = "movie_id"
        case episodeID = "episode_id"
        case positionMillis = "position_ms"
        case durationMillis = "duration_ms"
        case updatedAt = "updated_at"
    }
}

actor SupabaseLikedMovieStore: PhucTvLikedMovieStoring {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func loadMovies() async throws -> [PhucTvMovieCard] {
        guard let rows = try await loadRowsIfAuthenticated() else { return [] }
        return rows.map(\.movieSnapshot)
    }

    func loadIDs() async throws -> Set<Int> {
        Set(try await loadMovies().map(\.id))
    }

    func isLiked(movieID: Int) async throws -> Bool {
        try await loadIDs().contains(movieID)
    }

    func toggle(movie: PhucTvMovieCard) async throws -> [PhucTvMovieCard] {
        let client = try requireClient()
        let session = try await client.auth.session
        let userID = session.user.id

        let existingRows: [PhucTvLikedMovieRow] = try await client
            .from("liked_movies")
            .select()
            .eq("movie_id", value: movie.id)
            .execute()
            .value

        if existingRows.contains(where: { $0.userID == userID }) {
            try await client
                .from("liked_movies")
                .delete()
                .eq("user_id", value: userID)
                .eq("movie_id", value: movie.id)
                .execute()
        } else {
            let row = PhucTvLikedMovieRow(
                userID: userID,
                movieID: movie.id,
                movieSnapshot: movie,
                createdAt: nil
            )
            try await client
                .from("liked_movies")
                .upsert(row, onConflict: "user_id,movie_id")
                .execute()
        }

        return try await loadMovies()
    }

    func importLegacyMovies(_ movies: [PhucTvMovieCard]) async throws {
        guard let client = client else { return }
        guard let session = try? await client.auth.session else { return }
        guard !movies.isEmpty else { return }

        let rows = movies.map { movie in
            PhucTvLikedMovieRow(
                userID: session.user.id,
                movieID: movie.id,
                movieSnapshot: movie,
                createdAt: nil
            )
        }

        try await client
            .from("liked_movies")
            .upsert(rows, onConflict: "user_id,movie_id")
            .execute()
    }

    private func loadRowsIfAuthenticated() async throws -> [PhucTvLikedMovieRow]? {
        guard let client else { return nil }
        do {
            let session = try await client.auth.session
            return try await client
                .from("liked_movies")
                .select()
                .eq("user_id", value: session.user.id)
                .execute()
                .value
        } catch {
            return nil
        }
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            throw PhucTvSupabaseStoreError.missingConfiguration
        }
        return client
    }
}

actor SupabasePlaybackPositionStore: PhucTvPlaybackPositionStoring {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func save(
        movieID: Int,
        episodeID: Int,
        positionMillis: Int64,
        durationMillis: Int64
    ) async throws {
        guard let client = client else { return }
        guard let session = try? await client.auth.session else { return }

        let row = PhucTvPlaybackPositionRow(
            userID: session.user.id,
            movieID: movieID,
            episodeID: episodeID,
            positionMillis: max(positionMillis, 0),
            durationMillis: max(durationMillis, 0),
            updatedAt: nil
        )

        try await client
            .from("playback_positions")
            .upsert(row, onConflict: "user_id,movie_id,episode_id")
            .execute()
    }

    func load(movieID: Int, episodeID: Int) async throws -> PhucTvPlaybackProgressSnapshot? {
        guard let client = client else { return nil }
        guard let session = try? await client.auth.session else { return nil }

        let rows: [PhucTvPlaybackPositionRow] = try await client
            .from("playback_positions")
            .select()
            .eq("user_id", value: session.user.id)
            .eq("movie_id", value: movieID)
            .eq("episode_id", value: episodeID)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        return PhucTvPlaybackProgressSnapshot(
            positionMillis: row.positionMillis,
            durationMillis: row.durationMillis
        )
    }

    func importLegacyPositions(_ positions: [PhucTvLegacyPlaybackPosition]) async throws {
        guard let client = client else { return }
        guard let session = try? await client.auth.session else { return }
        guard !positions.isEmpty else { return }

        let rows = positions.map { position in
            PhucTvPlaybackPositionRow(
                userID: session.user.id,
                movieID: position.movieID,
                episodeID: position.episodeID,
                positionMillis: max(position.snapshot.positionMillis, 0),
                durationMillis: max(position.snapshot.durationMillis, 0),
                updatedAt: nil
            )
        }

        try await client
            .from("playback_positions")
            .upsert(rows, onConflict: "user_id,movie_id,episode_id")
            .execute()
    }
}

private enum PhucTvSupabaseStoreError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase is not configured."
        }
    }
}
