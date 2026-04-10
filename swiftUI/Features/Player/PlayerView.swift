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
                VideoPlayer(player: viewModel.player)
                    .ignoresSafeArea()
                    .overlay(alignment: .topLeading) {
                        PlayerTopBar(
                            movieTitle: viewModel.movieTitle,
                            episodeLabel: viewModel.episodeLabel,
                            sourceName: viewModel.sourceTitle,
                            onBack: { router.pop() }
                        )
                    }
                    .overlay(alignment: .bottomLeading) {
                        if !viewModel.playableSources.isEmpty {
                            PlayerBlurChipRow(height: 54) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(Array(viewModel.playableSources.enumerated()), id: \.element.id) { index, source in
                                            Button(action: { viewModel.selectSource(index) }) {
                                                Text(source.displayName)
                                                    .font(AppTheme.captionFont.weight(.semibold))
                                                    .foregroundStyle(index == viewModel.selectedSourceIndex ? Color.white : AppTheme.textPrimary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(index == viewModel.selectedSourceIndex ? AppTheme.accent.opacity(0.20) : Color.white.opacity(0.05))
                                                    )
                                                    .overlay(
                                                        Capsule(style: .continuous)
                                                            .stroke(index == viewModel.selectedSourceIndex ? AppTheme.accent.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
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
    }
}

private struct PlayerTopBar: View {
    let movieTitle: String
    let episodeLabel: String
    let sourceName: String
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PlayerIconButton(icon: "chevron.left", label: "Back", onTap: onBack)

            VStack(alignment: .leading, spacing: 6) {
                Text(movieTitle)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(episodeLabel)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("•")
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(sourceName)
                        .font(AppTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(20)
    }
}

private struct PlayerBlurChipRow<Content: View>: View {
    let content: Content
    let height: CGFloat?

    init(height: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.height = height
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.36))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private func formatDuration(_ positionMs: Int64) -> String {
    let totalSeconds = max(positionMs, 0) / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview("Player") {
    NavigationStack {
        PlayerView(
            viewModel: PlayerViewModel.previewLoaded(),
            router: AppRouter()
        )
    }
}
