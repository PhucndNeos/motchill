import SwiftUI

@main
struct PhucTvSwiftUIApp: App {
    private let dependencies = AppDependencies(container: .shared)

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(\.appDependencies, dependencies)
        }
    }
}
