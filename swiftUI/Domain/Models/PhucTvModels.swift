import Foundation

struct PhucTvSearchChoice: Codable, Hashable, Sendable {
    let value: String
    let label: String
}

struct PhucTvSimpleLabel: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let link: String
    let displayColumn: Int
}

struct PhucTvHomeSection: Codable, Hashable, Sendable, Identifiable {
    var id: String {
        key
    }
    let title: String
    let key: String
    let products: [PhucTvMovieCard]
    let isCarousel: Bool
}

/// A movie card model that handles null/missing values by providing default values during decoding.
/// - Remark: All properties are non-optional. Missing keys or null values from API are converted to defaults (empty string or zero).
struct PhucTvMovieCard: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let otherName: String
    let avatar: String
    let bannerThumb: String
    let avatarThumb: String
    let description: String
    let banner: String
    let imageIcon: String
    let link: String
    let quantity: String
    let rating: String
    let year: Int
    let statusTitle: String
    let statusRaw: String
    let statusText: String
    let director: String
    let time: String
    let trailer: String
    let showTimes: String
    let moreInfo: String
    let castString: String
    let episodesTotal: Int
    let viewNumber: Int
    let ratePoint: Double
    let photoUrls: [String]
    let previewPhotoUrls: [String]

    // MARK: - Computed Properties

    var displayTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var displaySubtitle: String {
        let other = otherName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !other.isEmpty {
            return other
        }
        return description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayPoster: String {
        let thumb = avatarThumb.trimmingCharacters(in: .whitespacesAndNewlines)
        return thumb.isEmpty ? avatar : thumb
    }

    var displayBanner: String {
        let bannerValue = banner.trimmingCharacters(in: .whitespacesAndNewlines)
        return bannerValue.isEmpty ? bannerThumb : bannerValue
    }

    static let empty = PhucTvMovieCard(
        id: 0, name: "", otherName: "", avatar: "", bannerThumb: "", avatarThumb: "",
        description: "", banner: "", imageIcon: "", link: "", quantity: "", rating: "",
        year: 0, statusTitle: "", statusRaw: "", statusText: "", director: "", time: "",
        trailer: "", showTimes: "", moreInfo: "", castString: "", episodesTotal: 0,
        viewNumber: 0, ratePoint: 0, photoUrls: [], previewPhotoUrls: []
    )
}

struct PhucTvNavbarItem: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let items: [PhucTvNavbarItem]
    let isExistChild: Bool
}

struct PhucTvPopupAdConfig: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let type: String
    let desktopLink: String
    let mobileLink: String
}

struct PhucTvMovieEpisode: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let episodeNumber: String
    let name: String
    let fullLink: String
    let status: String
    let type: String

    var label: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedEpisodeNumber = episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEpisodeNumber.isEmpty {
            return "Tập \(trimmedEpisodeNumber)"
        }

        return "Episode"
    }
}

struct PhucTvMovieDetail: Codable, Hashable, Sendable {
    let movie: PhucTvMovieCard
    let relatedMovies: [PhucTvMovieCard]
    let countries: [PhucTvSimpleLabel]
    let categories: [PhucTvSimpleLabel]
    let episodes: [PhucTvMovieEpisode]

    var id: Int { movie.id }
    var title: String { movie.name }
    var otherName: String { movie.otherName }
    var avatar: String { movie.avatar }
    var avatarThumb: String { movie.avatarThumb }
    var banner: String { movie.banner }
    var bannerThumb: String { movie.bannerThumb }
    var description: String { movie.description }
    var quality: String { movie.quantity }
    var statusTitle: String { movie.statusTitle }
    var statusRaw: String { movie.statusRaw }
    var statusText: String { movie.statusText }
    var director: String { movie.director }
    var time: String { movie.time }
    var trailer: String { movie.trailer }
    var showTimes: String { movie.showTimes }
    var moreInfo: String { movie.moreInfo }
    var castString: String { movie.castString }
    var year: Int { movie.year }
    var episodesTotal: Int { movie.episodesTotal }
    var viewNumber: Int { movie.viewNumber }
    var ratePoint: Double { movie.ratePoint }
    var photoUrls: [String] { movie.photoUrls }
    var previewPhotoUrls: [String] { movie.previewPhotoUrls }

    var displayBackdrop: String {
        if !movie.banner.isEmpty {
            return movie.banner
        }
        if !movie.avatar.isEmpty {
            return movie.avatar
        }
        if !movie.bannerThumb.isEmpty {
            return movie.bannerThumb
        }
        return movie.avatarThumb
    }
}

struct PhucTvSearchFacetOption: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let slug: String

    var hasID: Bool { id > 0 }
}

struct PhucTvSearchFilterData: Codable, Hashable, Sendable {
    let categories: [PhucTvSearchFacetOption]
    let countries: [PhucTvSearchFacetOption]
}

struct PhucTvSearchPagination: Codable, Hashable, Sendable {
    let pageIndex: Int
    let pageSize: Int
    let pageCount: Int
    let totalRecords: Int

    var hasPreviousPage: Bool { pageIndex > 1 }
    var hasNextPage: Bool { pageIndex < pageCount }
}

struct PhucTvSearchResults: Codable, Hashable, Sendable {
    let records: [PhucTvMovieCard]
    let pagination: PhucTvSearchPagination
}

struct PhucTvPlayTrack: Codable, Hashable, Sendable {
    let kind: String
    let file: String
    let label: String
    let isDefault: Bool

    var displayLabel: String {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            return trimmedLabel
        }

        let trimmedFile = file.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFile.isEmpty {
            return trimmedFile
        }

        let trimmedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedKind.isEmpty ? "Track" : trimmedKind
    }

    var isAudio: Bool {
        matchesTrackKind(kind, expectedHints: Self.audioKindHints)
    }

    var isSubtitle: Bool {
        matchesTrackKind(kind, expectedHints: Self.subtitleKindHints) || looksLikeSubtitleFile(file)
    }

    private static let audioKindHints = [
        "audio",
        "dub",
        "voice",
        "aac",
        "mp4a",
    ]

    private static let subtitleKindHints = [
        "subtitle",
        "sub",
        "caption",
        "captions",
        "cc",
        "text",
    ]
}

struct PhucTvPlaySource: Codable, Hashable, Identifiable, Sendable {
    let sourceId: Int
    let serverName: String
    let link: String
    let subtitle: String
    let type: Int
    let isFrame: Bool
    let quality: String
    let tracks: [PhucTvPlayTrack]

    var id: String { link }

    var displayName: String {
        var parts: [String] = []

        let trimmedServerName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedServerName.isEmpty {
            parts.append(trimmedServerName)
        }

        let trimmedQuality = quality.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuality.isEmpty {
            parts.append(trimmedQuality)
        }

        parts.append(isFrame ? "iframe" : "stream")
        return parts.joined(separator: " • ")
    }

    var actionButtonTitle: String {
        let trimmedServerName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedServerName.isEmpty {
            return trimmedServerName
        }

        return displayName
    }

    var audioTracks: [PhucTvPlayTrack] {
        tracks.filter { $0.isAudio }
    }

    var subtitleTracks: [PhucTvPlayTrack] {
        var explicit = tracks.filter { $0.isSubtitle }
        if explicit.isEmpty {
            let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSubtitle.isEmpty, looksLikeSubtitleFile(trimmedSubtitle) {
                explicit.append(
                    PhucTvPlayTrack(
                        kind: "subtitle",
                        file: trimmedSubtitle,
                        label: "Subtitle",
                        isDefault: true
                    )
                )
            }
        }
        return explicit
    }

    var hasAudioTracks: Bool { !audioTracks.isEmpty }
    var hasSubtitleTracks: Bool { !subtitleTracks.isEmpty }
    var defaultAudioTrack: PhucTvPlayTrack? { audioTracks.first(where: { $0.isDefault }) }
    var defaultSubtitleTrack: PhucTvPlayTrack? { subtitleTracks.first(where: { $0.isDefault }) }
    var isStream: Bool { !isFrame }
}

struct PhucTvPlaybackProgressSnapshot: Codable, Hashable, Sendable {
    let positionMillis: Int64
    let durationMillis: Int64

    var progressFraction: Double {
        guard durationMillis > 0 else { return 0 }
        let fraction = Double(positionMillis) / Double(durationMillis)
        return min(max(fraction, 0), 1)
    }
}

extension Array where Element == PhucTvPlaySource {
    var playableDirectStreams: [PhucTvPlaySource] {
        filter(\.isStream)
    }
}

private func matchesTrackKind(_ kind: String, expected: String) -> Bool {
    kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains(expected.lowercased())
}

private func matchesTrackKind(_ kind: String, expectedHints: [String]) -> Bool {
    let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalizedKind.isEmpty else { return false }
    return expectedHints.contains { normalizedKind.contains($0) }
}

private func looksLikeSubtitleFile(_ file: String) -> Bool {
    let extensionValue = file
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: ".")
        .last
        .map(String.init)
        .map { $0.lowercased() } ?? ""

    return [
        "srt",
        "vtt",
        "ass",
        "ssa",
        "sub",
        "ttml",
        "dfxp",
    ].contains(extensionValue)
}

// MARK: - Safe Decoding Extensions

extension KeyedDecodingContainer {
    func decode(_ type: String.Type, forKey key: Key, default defaultValue: String) -> String {
        (try? decode(String.self, forKey: key)) ?? defaultValue
    }

    func decode(_ type: Int.Type, forKey key: Key, default defaultValue: Int) -> Int {
        (try? decode(Int.self, forKey: key)) ?? defaultValue
    }

    func decode(_ type: Double.Type, forKey key: Key, default defaultValue: Double) -> Double {
        (try? decode(Double.self, forKey: key)) ?? defaultValue
    }

    func decode(_ type: Bool.Type, forKey key: Key, default defaultValue: Bool) -> Bool {
        (try? decode(Bool.self, forKey: key)) ?? defaultValue
    }

    func decode<T: Decodable>(_ type: [T].Type, forKey key: Key, default defaultValue: [T]) -> [T] {
        (try? decode([T].self, forKey: key)) ?? defaultValue
    }
}

extension PhucTvSearchChoice {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = container.decode(String.self, forKey: .value, default: "")
        label = container.decode(String.self, forKey: .label, default: "")
    }
}

extension PhucTvSimpleLabel {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        name = container.decode(String.self, forKey: .name, default: "")
        link = container.decode(String.self, forKey: .link, default: "")
        displayColumn = container.decode(Int.self, forKey: .displayColumn, default: 0)
    }
}

extension PhucTvHomeSection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decode(String.self, forKey: .title, default: "")
        key = container.decode(String.self, forKey: .key, default: UUID().uuidString)
        products = container.decode([PhucTvMovieCard].self, forKey: .products, default: [])
        isCarousel = container.decode(Bool.self, forKey: .isCarousel, default: false)
    }
}

extension PhucTvMovieCard {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        name = container.decode(String.self, forKey: .name, default: "")
        otherName = container.decode(String.self, forKey: .otherName, default: "")
        avatar = container.decode(String.self, forKey: .avatar, default: "")
        bannerThumb = container.decode(String.self, forKey: .bannerThumb, default: "")
        avatarThumb = container.decode(String.self, forKey: .avatarThumb, default: "")
        description = container.decode(String.self, forKey: .description, default: "")
        banner = container.decode(String.self, forKey: .banner, default: "")
        imageIcon = container.decode(String.self, forKey: .imageIcon, default: "")
        link = container.decode(String.self, forKey: .link, default: "")
        quantity = container.decode(String.self, forKey: .quantity, default: "")
        rating = container.decode(String.self, forKey: .rating, default: "")
        year = container.decode(Int.self, forKey: .year, default: 0)
        statusTitle = container.decode(String.self, forKey: .statusTitle, default: "")
        statusRaw = container.decode(String.self, forKey: .statusRaw, default: "")
        statusText = container.decode(String.self, forKey: .statusText, default: "")
        director = container.decode(String.self, forKey: .director, default: "")
        time = container.decode(String.self, forKey: .time, default: "")
        trailer = container.decode(String.self, forKey: .trailer, default: "")
        showTimes = container.decode(String.self, forKey: .showTimes, default: "")
        moreInfo = container.decode(String.self, forKey: .moreInfo, default: "")
        castString = container.decode(String.self, forKey: .castString, default: "")
        episodesTotal = container.decode(Int.self, forKey: .episodesTotal, default: 0)
        viewNumber = container.decode(Int.self, forKey: .viewNumber, default: 0)
        ratePoint = container.decode(Double.self, forKey: .ratePoint, default: 0.0)
        photoUrls = container.decode([String].self, forKey: .photoUrls, default: [])
        previewPhotoUrls = container.decode([String].self, forKey: .previewPhotoUrls, default: [])
    }
}

extension PhucTvNavbarItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        name = container.decode(String.self, forKey: .name, default: "")
        slug = container.decode(String.self, forKey: .slug, default: "")
        items = container.decode([PhucTvNavbarItem].self, forKey: .items, default: [])
        isExistChild = container.decode(Bool.self, forKey: .isExistChild, default: false)
    }
}

extension PhucTvPopupAdConfig {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        name = container.decode(String.self, forKey: .name, default: "")
        type = container.decode(String.self, forKey: .type, default: "")
        desktopLink = container.decode(String.self, forKey: .desktopLink, default: "")
        mobileLink = container.decode(String.self, forKey: .mobileLink, default: "")
    }
}

extension PhucTvMovieEpisode {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        episodeNumber = container.decode(String.self, forKey: .episodeNumber, default: "")
        name = container.decode(String.self, forKey: .name, default: "")
        fullLink = container.decode(String.self, forKey: .fullLink, default: "")
        status = container.decode(String.self, forKey: .status, default: "")
        type = container.decode(String.self, forKey: .type, default: "")
    }
}

extension PhucTvSearchFacetOption {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(Int.self, forKey: .id, default: 0)
        name = container.decode(String.self, forKey: .name, default: "")
        slug = container.decode(String.self, forKey: .slug, default: "")
    }
}

extension PhucTvSearchPagination {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageIndex = container.decode(Int.self, forKey: .pageIndex, default: 1)
        pageSize = container.decode(Int.self, forKey: .pageSize, default: 20)
        pageCount = container.decode(Int.self, forKey: .pageCount, default: 1)
        totalRecords = container.decode(Int.self, forKey: .totalRecords, default: 0)
    }
}

extension PhucTvPlayTrack {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = container.decode(String.self, forKey: .kind, default: "")
        file = container.decode(String.self, forKey: .file, default: "")
        label = container.decode(String.self, forKey: .label, default: "")
        isDefault = container.decode(Bool.self, forKey: .isDefault, default: false)
    }
}

extension PhucTvPlaySource {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = container.decode(Int.self, forKey: .sourceId, default: 0)
        serverName = container.decode(String.self, forKey: .serverName, default: "")
        link = container.decode(String.self, forKey: .link, default: "")
        subtitle = container.decode(String.self, forKey: .subtitle, default: "")
        type = container.decode(Int.self, forKey: .type, default: 0)
        isFrame = container.decode(Bool.self, forKey: .isFrame, default: false)
        quality = container.decode(String.self, forKey: .quality, default: "")
        tracks = container.decode([PhucTvPlayTrack].self, forKey: .tracks, default: [])
    }
}
