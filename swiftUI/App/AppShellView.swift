import ComposableArchitecture
import SwiftUI

struct AppShellView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .overlay(alignment: .topTrailing) {
                    if let banner = store.authBanner {
                        AuthBanner(
                            message: banner.message,
                            buttonTitle: banner.buttonTitle,
                            onButtonTap: { store.send(.authBannerButtonTapped) }
                        )
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        } destination: { store in
            switch store.case {
            case .search(let store):
                SearchView(store: store)
            case .detail(let store):
                DetailView(store: store)
            case .player(let store):
                PlayerFeatureView(store: store)
            }
        }
        .sheet(item: $store.scope(state: \.$auth, action: \.auth)) { store in
            AuthView(store: store)
        }
        .task {
            await store.send(.task).finish()
        }
    }
}

private struct AuthBanner: View {
    let message: String
    let buttonTitle: String
    let onButtonTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)

            Button(buttonTitle, action: onButtonTap)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }
}
