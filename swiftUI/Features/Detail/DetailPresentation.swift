import Foundation

enum DetailSectionTab: Hashable, Sendable {
    case episodes
    case synopsis
    case information
    case classification
    case gallery
    case related

    var label: String {
        switch self {
        case .episodes: return "Episodes"
        case .synopsis: return "Synopsis"
        case .information: return "Information"
        case .classification: return "Classification"
        case .gallery: return "Gallery"
        case .related: return "Related"
        }
    }
}

enum DetailScreenState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

extension PhucTvMovieDetail {
    var availableTabs: [DetailSectionTab] {
        var tabs: [DetailSectionTab] = []
        if !episodes.isEmpty { tabs.append(.episodes) }
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { tabs.append(.synopsis) }
        if hasInformation { tabs.append(.information) }
        if !countries.isEmpty || !categories.isEmpty { tabs.append(.classification) }
        if !photoUrls.isEmpty || !previewPhotoUrls.isEmpty { tabs.append(.gallery) }
        if !relatedMovies.isEmpty { tabs.append(.related) }
        return tabs
    }

    var hasInformation: Bool {
        !director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !castString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !showTimes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !moreInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !trailer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !statusRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var defaultTab: DetailSectionTab {
        let tabs = availableTabs
        if tabs.isEmpty { return .synopsis }
        if tabs.contains(.episodes) { return .episodes }
        return tabs.first ?? .synopsis
    }
}
