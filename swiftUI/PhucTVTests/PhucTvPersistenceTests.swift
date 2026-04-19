import XCTest
@testable import PhucTV

final class PhucTvPersistenceTests: XCTestCase {
    func testPreferredEpisodeScrollTargetChoosesLastWatchedEpisode() {
        let detail = DetailMockData.detail
        let target = preferredEpisodeScrollTargetID(
            detail: detail,
            episodeProgressById: [
                detail.episodes[0].id: PhucTvPlaybackProgressSnapshot(positionMillis: 30_000, durationMillis: 120_000),
                detail.episodes[2].id: PhucTvPlaybackProgressSnapshot(positionMillis: 60_000, durationMillis: 120_000)
            ]
        )

        XCTAssertEqual(target, detail.episodes[2].id)
    }

    func testPreferredEpisodeScrollTargetReturnsNilWithoutWatchedEpisodes() {
        let detail = DetailMockData.detail
        let target = preferredEpisodeScrollTargetID(
            detail: detail,
            episodeProgressById: [
                detail.episodes[1].id: PhucTvPlaybackProgressSnapshot(positionMillis: 0, durationMillis: 120_000)
            ]
        )

        XCTAssertNil(target)
    }
}
