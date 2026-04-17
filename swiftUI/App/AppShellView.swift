import SwiftUI

struct AppShellView: View {
    @State private var authManager: PhucTvSupabaseAuthManager
    @State private var router = AppRouter()
    @State private var showAuthSheet = false

    init(dependencies: AppDependencies) {
        _authManager = State(initialValue: dependencies.authManager)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(router: router)
            .navigationDestination(for: AppRoute.self, destination: destinationView)
            .overlay(alignment: .top) {
                if let hint = authManager.signInHint {
                    AuthBanner(
                        message: hint,
                        buttonTitle: authManager.isAuthenticated ? nil : "Đăng nhập",
                        onButtonTap: {
                            showAuthSheet = true
                        }
                    )
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthView(authManager: authManager)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView(router: router)
        case .search(let routeInput):
            SearchView(router: router, routeInput: routeInput)
        case .detail(let movie):
            DetailView(movie: movie, router: router)
        case .player(let movieID, let episodeID, let movieTitle, let episodeLabel):
            PlayerView(
                movieID: movieID,
                episodeID: episodeID,
                movieTitle: movieTitle,
                episodeLabel: episodeLabel,
                router: router
            )
        }
    }
}

private struct AuthBanner: View {
    let message: String
    let buttonTitle: String?
    let onButtonTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let buttonTitle {
                Button(buttonTitle, action: onButtonTap)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
            }
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
