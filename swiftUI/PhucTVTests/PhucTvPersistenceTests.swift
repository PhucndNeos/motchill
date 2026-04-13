import XCTest
@testable import PhucTvSwiftUI

final class PhucTvPersistenceTests: XCTestCase {
    func testLikedMovieStoreRoundTripsCards() async throws {
        let suiteName = "PhucTvSwiftUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsPhucTvLikedMovieStore(defaults: defaults)
        let movie = PhucTvMovieCard(
            id: 99,
            name: "Liked Movie",
            otherName: "",
            avatar: "avatar",
            bannerThumb: "",
            avatarThumb: "",
            description: "",
            banner: "",
            imageIcon: "",
            link: "/movie/liked",
            quantity: "HD",
            rating: "9.1",
            year: 2024,
            statusTitle: "Now",
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

        let afterToggle = try await store.toggle(movie: movie)

        XCTAssertEqual(afterToggle.map(\.id), [99])
        let loadedIDs = try await store.loadIDs()
        XCTAssertEqual(loadedIDs, Set([99]))

        let isLikedAfterFirstToggle = try await store.isLiked(movieID: 99)
        XCTAssertTrue(isLikedAfterFirstToggle)

        let afterSecondToggle = try await store.toggle(movie: movie)
        XCTAssertTrue(afterSecondToggle.isEmpty)
        let isLikedAfterSecondToggle = try await store.isLiked(movieID: 99)
        XCTAssertFalse(isLikedAfterSecondToggle)
    }

    func testPlaybackPositionStoreRoundTripsSnapshots() async throws {
        let suiteName = "PhucTvSwiftUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsPhucTvPlaybackPositionStore(defaults: defaults)
        try await store.save(movieID: 10, episodeID: 7, positionMillis: 1_200, durationMillis: 6_000)

        let snapshot = try await store.load(movieID: 10, episodeID: 7)

        XCTAssertEqual(snapshot?.positionMillis, 1_200)
        XCTAssertEqual(snapshot?.durationMillis, 6_000)
        XCTAssertEqual(snapshot?.progressFraction ?? 0, 0.2, accuracy: 0.0001)
    }
}
