import ComposableArchitecture
import SwiftUI

@main
struct PhucTvSwiftUIApp: App {
    private let store: StoreOf<AppFeature>

    init() {
        let dependencies = AppDependencies.live()
        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.configurePhucTvDependencies(dependencies)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(store: store)
                .onOpenURL { url in
                    store.send(.openURL(url))
                }
        }
    }
}
