import Foundation

struct HomeFeedContent: Equatable {
    let sections: [MotchillHomeSection]

    var heroSection: MotchillHomeSection? {
        sections.first(where: { $0.key == "slide" }) ?? sections.first
    }

    var contentSections: [MotchillHomeSection] {
        guard sections.contains(where: { $0.key == "slide" }) else {
            return sections
        }

        return sections.filter { $0.key != "slide" }
    }
    
    func section(withKey key: String) -> MotchillHomeSection? {
        sections.first(where: { $0.key == key })
    }    
}

enum HomeScreenState: Equatable {
    case loading
    case loaded(HomeFeedContent)
    case empty
    case error(message: String)
}
