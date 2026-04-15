import Foundation

protocol PhucTvLegacyLocalDataMigrating: Sendable {
    func migrateIfNeeded() async
}

actor PhucTvLegacyLocalDataMigrator: PhucTvLegacyLocalDataMigrating {
    private let defaults: UserDefaults
    private let likedMovieStore: SupabaseLikedMovieStore
    private let playbackPositionStore: SupabasePlaybackPositionStore
    private var isRunning = false

    init(
        defaults: UserDefaults = .standard,
        likedMovieStore: SupabaseLikedMovieStore,
        playbackPositionStore: SupabasePlaybackPositionStore
    ) {
        self.defaults = defaults
        self.likedMovieStore = likedMovieStore
        self.playbackPositionStore = playbackPositionStore
    }

    func migrateIfNeeded() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        do {
            let payload = try defaults.phucTvLoadLegacyDataPayload()
            guard !payload.isEmpty else { return }

            // Liked movies: bulk import then clear — no conflict risk.
            if !payload.likedMovies.isEmpty {
                try await likedMovieStore.importLegacyMovies(payload.likedMovies)
                defaults.removeObject(forKey: UserDefaultsPhucTvLikedMovieStore.moviesKey)
                defaults.removeObject(forKey: UserDefaultsPhucTvLikedMovieStore.movieIDsKey)
                PhucTvLogger.shared.info(
                    "Migrated liked movies to Supabase.",
                    metadata: ["count": "\(payload.likedMovies.count)"]
                )
            }

            // Playback positions: row-by-row with max-wins.
            // Each row is deleted immediately after a successful sync so it is
            // never re-uploaded on the next launch. Rows that fail to sync are
            // kept in UserDefaults and retried on the next launch.
            var syncedCount = 0
            var skippedCount = 0
            for position in payload.playbackPositions {
                do {
                    let remoteSnapshot = try? await playbackPositionStore.load(
                        movieID: position.movieID,
                        episodeID: position.episodeID
                    )
                    let remotePosition = remoteSnapshot?.positionMillis ?? 0

                    if position.snapshot.positionMillis > remotePosition {
                        try await playbackPositionStore.save(
                            movieID: position.movieID,
                            episodeID: position.episodeID,
                            positionMillis: position.snapshot.positionMillis,
                            durationMillis: position.snapshot.durationMillis
                        )
                        syncedCount += 1
                    } else {
                        // Remote is equal or ahead — local row is stale, no upload needed.
                        skippedCount += 1
                    }

                    // Delete the local row regardless: either we just pushed it, or remote
                    // already had a better value and local is now stale.
                    defaults.removeObject(
                        forKey: UserDefaultsPhucTvPlaybackPositionStore.key(
                            movieID: position.movieID,
                            episodeID: position.episodeID
                        )
                    )
                } catch {
                    // Leave this row in UserDefaults so the next launch can retry.
                    PhucTvLogger.shared.warning(
                        "Failed to sync playback position to Supabase — will retry on next launch.",
                        metadata: [
                            "movie_id": "\(position.movieID)",
                            "episode_id": "\(position.episodeID)",
                            "error": String(describing: error)
                        ]
                    )
                }
            }

            PhucTvLogger.shared.info(
                "Playback position migration complete.",
                metadata: [
                    "synced": "\(syncedCount)",
                    "skipped_remote_ahead": "\(skippedCount)"
                ]
            )
        } catch {
            PhucTvLogger.shared.warning(
                "Failed to load legacy local data for migration.",
                metadata: ["error": String(describing: error)]
            )
        }
    }
}
