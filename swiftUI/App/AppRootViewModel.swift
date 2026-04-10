import Observation
import Foundation

@Observable
final class AppRootViewModel {
    let heroTitle = "Motchill SwiftUI"
    let heroSubtitle = "Native iOS shell, phase 0."
    let heroDetail = "MVVM with @Observable, Kingfisher for images, and a structure that mirrors the Android foundation."

    let launchTargets: [AppRoute] = [
        .home,
        .search,
        .player,
    ]

    let footnote = "iOS 18+ · standalone workspace"
}
