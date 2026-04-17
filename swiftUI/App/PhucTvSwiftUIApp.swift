import SwiftUI

@main
struct PhucTvSwiftUIApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            AppShellView(dependencies: dependencies)
                .environment(\.appDependencies, dependencies)
                .onOpenURL { url in
                    dependencies.authManager.handle(url)
                }
        }
    }
}
