import AVKit
import SwiftUI

struct PlayerView: View {
    @State private var viewModel: PlayerViewModel
    let router: AppRouter
    private let shouldLoadOnAppear: Bool

    init(
        movieID: Int,
        episodeID: Int,
        movieTitle: String,
        episodeLabel: String,
        repository: MotchillRepository,
        playbackPositionStore: MotchillPlaybackPositionStoring,
        router: AppRouter
    ) {
        _viewModel = State(
            initialValue: PlayerViewModel(
                movieID: movieID,
                episodeID: episodeID,
                movieTitle: movieTitle,
                episodeLabel: episodeLabel,
                repository: repository,
                playbackPositionStore: playbackPositionStore
            )
        )
        self.router = router
        self.shouldLoadOnAppear = true
    }

    init(viewModel: PlayerViewModel, router: AppRouter) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        PlayerScreen(viewModel: viewModel, router: router)
            .task {
                guard shouldLoadOnAppear else { return }
                await viewModel.load()
            }
            .onDisappear {
                Task {
                    await viewModel.persistProgress()
                    viewModel.stop()
                }
            }
    }
}

private struct PlayerScreen: View {
    let viewModel: PlayerViewModel
    let router: AppRouter

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let _ = viewModel.selectedSource {
                ZStack {
                    VideoPlayer(player: viewModel.player)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    PlayerOverlay(
                        viewModel: viewModel,
                        onBack: { router.pop() }
                    )
                    .opacity(viewModel.overlayVisible ? 1 : 0)
                }
            } else {
                PlayerLoadingState(
                    title: viewModel.movieTitle,
                    subtitle: viewModel.episodeLabel
                )
            }

            if case let .error(message) = viewModel.state {
                PlayerErrorOverlay(
                    message: message,
                    onRetry: {
                        Task { await viewModel.retry() }
                    },
                    onBack: { router.pop() }
                )
            } else if viewModel.state == .loading && viewModel.sources.isEmpty {
                PlayerLoadingOverlay(
                    title: viewModel.movieTitle,
                    subtitle: viewModel.episodeLabel
                )
            }
        }
        .onTapGesture {
            viewModel.handleOverlayTap()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PlayerLoadingState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
            ProgressView()
                .tint(AppTheme.accent)
        }
        .padding(24)
    }
}

private struct PlayerLoadingOverlay: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)
            Text("Đang tải player")
                .font(AppTheme.sectionTitleFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(24)
    }
}

private struct PlayerErrorOverlay: View {
    let message: String
    let onRetry: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                PlayerIconButton(icon: "chevron.left", label: "Back", onTap: onBack)
                Spacer()
            }

            Text("Không thể mở player")
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                Text("Thử lại")
                    .font(AppTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(24)
    }
}

private struct PlayerIconButton: View {
    let icon: String
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.56))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview("Player") {
    NavigationStack {
        PlayerView(
            viewModel: PlayerViewModel.previewLoaded(),
            router: AppRouter()
        )
    }
}
