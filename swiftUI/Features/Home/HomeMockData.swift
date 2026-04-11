import Foundation

enum HomeMockData {
    private static let dunePoster = "https://upload.wikimedia.org/wikipedia/en/thumb/5/52/Dune_Part_Two_poster.jpeg/250px-Dune_Part_Two_poster.jpeg"
    private static let oppenheimerPoster = "https://upload.wikimedia.org/wikipedia/en/thumb/4/4a/Oppenheimer_%28film%29.jpg/250px-Oppenheimer_%28film%29.jpg"
    private static let batmanPoster = "https://upload.wikimedia.org/wikipedia/en/f/ff/The_Batman_%28film%29_poster.jpg"
    private static let arrivalPoster = "https://upload.wikimedia.org/wikipedia/en/d/df/Arrival%2C_Movie_Poster.jpg"
    private static let spiderVersePoster = "https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Spider-Man-_Across_the_Spider-Verse_poster.jpg/250px-Spider-Man-_Across_the_Spider-Verse_poster.jpg"
    private static let topGunPoster = "https://upload.wikimedia.org/wikipedia/en/thumb/1/13/Top_Gun_Maverick_Poster.jpg/250px-Top_Gun_Maverick_Poster.jpg"

    static let loadedSections: [MotchillHomeSection] = [
        section(
            title: "Slide",
            key: "slide",
            movies: [
                movie(
                    id: 1,
                    name: "Dune: Part Two",
                    otherName: "2024",
                    description: "A war of bloodlines and prophecy pushes the desert planet into a new era of power.",
                    banner: dunePoster,
                    avatar: dunePoster,
                    rating: "8.8",
                    year: 2024,
                    statusTitle: "Featured",
                    quality: "4K"
                ),
                movie(
                    id: 2,
                    name: "Oppenheimer",
                    otherName: "2023",
                    description: "The story of the physicist behind the atomic age and the moral cost that followed.",
                    banner: oppenheimerPoster,
                    avatar: oppenheimerPoster,
                    rating: "8.6",
                    year: 2023,
                    statusTitle: "Trending",
                    quality: "4K"
                ),
                movie(
                    id: 3,
                    name: "The Batman",
                    otherName: "2022",
                    description: "A vigilante chases a hidden conspiracy through Gotham's rain-soaked underworld.",
                    banner: batmanPoster,
                    avatar: batmanPoster,
                    rating: "8.0",
                    year: 2022,
                    statusTitle: "Popular",
                    quality: "HD"
                ),
                movie(
                    id: 4,
                    name: "Arrival",
                    otherName: "2016",
                    description: "A linguist tries to understand a message from visitors before the world fractures.",
                    banner: arrivalPoster,
                    avatar: arrivalPoster,
                    rating: "7.9",
                    year: 2016,
                    statusTitle: "Classic",
                    quality: "HD"
                ),
                movie(
                    id: 5,
                    name: "Spider-Man: Across the Spider-Verse",
                    otherName: "2023",
                    description: "Miles crosses dimensions again while a bigger multiverse conflict closes in.",
                    banner: spiderVersePoster,
                    avatar: spiderVersePoster,
                    rating: "8.7",
                    year: 2023,
                    statusTitle: "Top pick",
                    quality: "4K"
                ),
                movie(
                    id: 6,
                    name: "Top Gun: Maverick",
                    otherName: "2022",
                    description: "A veteran pilot returns to train the next generation for an impossible mission.",
                    banner: topGunPoster,
                    avatar: topGunPoster,
                    rating: "8.3",
                    year: 2022,
                    statusTitle: "Action",
                    quality: "4K"
                )
            ]
        ),
        section(
            title: "Mới và nổi bật",
            key: "featured",
            movies: [
                movie(
                    id: 101,
                    name: "A Quiet Signal",
                    otherName: "Drama • 2026",
                    description: "A suspenseful feature built around a disappearing broadcast and a family that keeps hearing the same signal.",
                    banner: placeholderImage(seed: "a-quiet-signal-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "a-quiet-signal-avatar", width: 900, height: 1350),
                    rating: "8.8",
                    year: 2026,
                    statusTitle: "Now showing",
                    quality: "4K"
                ),
                movie(
                    id: 102,
                    name: "After the Rain",
                    otherName: "Romance • Limited series",
                    description: "Two people reconnect through a city-wide blackout and the cassette tape that starts everything again.",
                    banner: placeholderImage(seed: "after-the-rain-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "after-the-rain-avatar", width: 900, height: 1350),
                    rating: "8.3",
                    year: 2025,
                    statusTitle: "Trending",
                    quality: "HD"
                ),
                movie(
                    id: 103,
                    name: "Neon Harbor",
                    otherName: "Sci-Fi • Action",
                    description: "An ex-courier races through a flooded metro to protect the last map of the old city.",
                    banner: placeholderImage(seed: "neon-harbor-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "neon-harbor-avatar", width: 900, height: 1350),
                    rating: "9.1",
                    year: 2025,
                    statusTitle: "Hot",
                    quality: "4K"
                )
            ]
        ),
        section(
            title: "Đang thịnh hành",
            key: "trending",
            movies: [
                movie(
                    id: 201,
                    name: "Winter Glass",
                    otherName: "Mystery • 6 episodes",
                    description: "An architect finds hidden rooms inside an apartment block that should not exist.",
                    banner: placeholderImage(seed: "winter-glass-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "winter-glass-avatar", width: 900, height: 1350),
                    rating: "8.4",
                    year: 2024,
                    statusTitle: "Series",
                    quality: "HD"
                ),
                movie(
                    id: 202,
                    name: "Signal Lost",
                    otherName: "Thriller • 2024",
                    description: "A rescue pilot traces a missing flight using only fragments of a broken radio transmission.",
                    banner: placeholderImage(seed: "signal-lost-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "signal-lost-avatar", width: 900, height: 1350),
                    rating: "8.0",
                    year: 2024,
                    statusTitle: "Completed",
                    quality: "Full HD"
                ),
                movie(
                    id: 203,
                    name: "Paper Moon City",
                    otherName: "Animation • Family",
                    description: "A child builds a city of paper, then discovers it has its own weather system.",
                    banner: placeholderImage(seed: "paper-moon-city-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "paper-moon-city-avatar", width: 900, height: 1350),
                    rating: "8.7",
                    year: 2023,
                    statusTitle: "Popular",
                    quality: "HD"
                ),
                movie(
                    id: 204,
                    name: "Harbor Lights",
                    otherName: "Crime drama",
                    description: "A night ferry crew becomes the only witness to a perfect disappearance.",
                    banner: placeholderImage(seed: "harbor-lights-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "harbor-lights-avatar", width: 900, height: 1350),
                    rating: "7.9",
                    year: 2022,
                    statusTitle: "Series",
                    quality: "HD"
                )
            ]
        ),
        section(
            title: "Gợi ý cho bạn",
            key: "recommended",
            movies: [
                movie(
                    id: 301,
                    name: "Blue Minute",
                    otherName: "Slice of life",
                    description: "A gentle city film about small choices and the people who keep showing up.",
                    banner: placeholderImage(seed: "blue-minute-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "blue-minute-avatar", width: 900, height: 1350),
                    rating: "8.2",
                    year: 2026,
                    statusTitle: "New",
                    quality: "HD"
                ),
                movie(
                    id: 302,
                    name: "Glass District",
                    otherName: "Action • Heist",
                    description: "A crew of former rivals plans one last job beneath a city of mirrored towers.",
                    banner: placeholderImage(seed: "glass-district-banner", width: 1600, height: 2400),
                    avatar: placeholderImage(seed: "glass-district-avatar", width: 900, height: 1350),
                    rating: "8.9",
                    year: 2025,
                    statusTitle: "Popular",
                    quality: "4K"
                )
            ]
        )
    ]

    static let emptySections: [MotchillHomeSection] = []

    static func section(title: String, key: String, movies: [MotchillMovieCard]) -> MotchillHomeSection {
        MotchillHomeSection(
            title: title,
            key: key,
            products: movies,
            isCarousel: true
        )
    }

    static func movie(
        id: Int,
        name: String,
        otherName: String,
        description: String,
        banner: String,
        avatar: String,
        rating: String,
        year: Int,
        statusTitle: String,
        quality: String
    ) -> MotchillMovieCard {
        MotchillMovieCard(
            id: id,
            name: name,
            otherName: otherName,
            avatar: avatar,
            bannerThumb: banner,
            avatarThumb: avatar,
            description: description,
            banner: banner,
            imageIcon: "",
            link: "/movie/\(id)",
            quantity: quality,
            rating: rating,
            year: year,
            statusTitle: statusTitle,
            statusRaw: statusTitle.lowercased(),
            statusText: statusTitle,
            director: "",
            time: "120m",
            trailer: "",
            showTimes: "",
            moreInfo: description,
            castString: "",
            episodesTotal: 1,
            viewNumber: 0,
            ratePoint: Double(rating) ?? 0,
            photoUrls: [],
            previewPhotoUrls: []
        )
    }

    private static func placeholderImage(seed: String, width: Int, height: Int) -> String {
        "https://picsum.photos/seed/\(seed)/\(width)/\(height)"
    }
}
