import SwiftUI
import UIKit

struct DetailScreen: View {
    @State private var viewModel: DetailViewModel
    let router: AppRouter
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init(viewModel: DetailViewModel, router: AppRouter) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
    }

    var body: some View {
        ZStack {
            DetailBackground()
                .ignoresSafeArea()

            loadedContent
            stateOverlay
        }
        .toolbar {            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleLike) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.isLiked ? Color.red.opacity(0.95) : AppTheme.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            (viewModel.isLiked ? Color.red.opacity(0.18) : Color.white.opacity(0.06)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: viewModel.movie.id) {
            guard viewModel.state == .idle else { return }
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if viewModel.state == .loaded, viewModel.hasRenderableContent {
            if isPad {
                DetailsIpadScreen(
                    viewModel: viewModel,
                    router: router,
                    onToggleLike: toggleLike,
                    onOpenTrailer: openTrailer,
                    onOpenEpisode: openEpisode
                )
            } else {
                DetailLoadedContent(
                    viewModel: viewModel,
                    router: router,
                    onToggleLike: toggleLike,
                    onOpenTrailer: openTrailer,
                    onOpenEpisode: openEpisode
                )
            }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.state {
        case .idle, .loading:
            FeatureStateOverlay(
                descriptor: .loading(
                    title: "Đang tải nội dung",
                    message: "Chờ một lát để nạp thông tin chi tiết của phim.",
                    errorCode: "DETAIL_LOADING"
                ),
                onRetry: retry
            )
        case .error(let message):
            FeatureStateOverlay(
                descriptor: .failure(
                    title: "Không thể tải chi tiết",
                    message: message,
                    errorCode: "DETAIL_LOAD_FAIL",
                    icon: .server,
                    secondaryTitle: "Quay lại"
                ),
                onRetry: retry,
                onSecondary: closeDetail
            )
        case .loaded:
            if !viewModel.hasRenderableContent {
                FeatureStateOverlay(
                    descriptor: .empty(
                        title: "Chưa có nội dung",
                        message: "Trang chi tiết hiện chưa có section nào để hiển thị. Bạn có thể thử quay lại hoặc tìm kiếm nội dung khác.",
                        errorCode: "DETAIL_EMPTY",
                        secondaryTitle: "Tìm kiếm"
                    ),
                    onRetry: retry,
                    onSecondary: openSearch
                )
            }
        }
    }

    private func retry() {
        makeAsyncAction { await viewModel.retry() }()
    }

    private func toggleLike() {
        Task { await viewModel.toggleLike() }
    }

    private func closeDetail() {
        router.pop()
    }

    private func openSearch() {
        router.push(.search())
    }

    private func openTrailer() {
        openExternalURL(viewModel.trailerURL())
    }

    private func openEpisode(_ episode: PhucTvMovieEpisode) {
        router.push(
            .player(
                movieID: viewModel.detail?.id ?? viewModel.movie.id,
                episodeID: episode.id,
                movieTitle: viewModel.title,
                episodeLabel: episode.label
            )
        )
    }
}

private struct DetailLoadedContent: View {
    let viewModel: DetailViewModel
    let router: AppRouter
    let onToggleLike: () -> Void
    let onOpenTrailer: () -> Void
    let onOpenEpisode: (PhucTvMovieEpisode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeroSection(
                    viewModel: viewModel,
                    router: router,
                    onToggleLike: onToggleLike,
                    onOpenTrailer: onOpenTrailer,
                    onOpenEpisode: {
                        guard let episode = viewModel.detail?.episodes.first else { return }
                        onOpenEpisode(episode)
                    }
                )

                DetailOverviewCard(
                    viewModel: viewModel,
                    onOpenTrailer: onOpenTrailer
                )

                if !viewModel.availableTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailTabStrip(
                            tabs: viewModel.availableTabs,
                            selectedTab: viewModel.effectiveSelectedTab,
                            onTabSelected: viewModel.selectTab
                        )

                        DetailSectionCard {
                            DetailTabBody(
                                detail: viewModel.detail,
                                selectedTab: viewModel.effectiveSelectedTab,
                                episodeProgressById: viewModel.episodeProgressById,
                                onOpenEpisode: onOpenEpisode,
                                onOpenDetail: { router.push(.detail($0)) },
                                onOpenSearch: { router.push(.search()) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailHeroSection: View {
    let viewModel: DetailViewModel
    let router: AppRouter
    let onToggleLike: () -> Void
    let onOpenTrailer: () -> Void
    let onOpenEpisode: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: detailURL(viewModel.backDropURL()), cornerRadius: 0)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.16),
                            Color.black.opacity(0.56),
                            Color(red: 0.05, green: 0.05, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    if !viewModel.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(viewModel.subtitle)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }

                    DetailMetaRow(pills: viewModel.metadataPills)

                    HStack(spacing: 10) {
                        Button(action: onOpenEpisode) {
                            FeaturePrimaryAction(text: "Xem ngay", systemImage: "play.fill")
                        }
                        .buttonStyle(.plain)

                        Button(action: onOpenTrailer) {
                            FeatureSecondaryAction(text: "Trailer", systemImage: "film")
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.selectTab(.information) }) {
                            DetailHeroAction(text: "Thông tin", systemImage: "info.circle", filled: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct DetailOverviewCard: View {
    let viewModel: DetailViewModel
    let onOpenTrailer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                DetailMiniLabel(text: "Overview")
                Spacer(minLength: 12)

                if viewModel.trailerURL() != nil {
                    Button(action: onOpenTrailer) {
                        Text("Trailer")
                            .font(AppTheme.captionFont.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(viewModel.overviewText)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailMetadataRow: View {
    let pills: [String]

    var body: some View {
        if pills.isEmpty {
            EmptyView()
        } else {
            FlowWrapLayout(items: pills) { pill in
                DetailMetaPill(text: pill)
            }
        }
    }
}

private struct DetailTabStrip: View {
    let tabs: [DetailSectionTab]
    let selectedTab: DetailSectionTab
    let onTabSelected: (DetailSectionTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    DetailTabChip(
                        label: tab.label,
                        selected: tab == selectedTab,
                        onTap: { onTabSelected(tab) }
                    )
                }
            }
        }
    }
}

@MainActor
@ViewBuilder
private func DetailTabBody(
    detail: PhucTvMovieDetail?,
    selectedTab: DetailSectionTab,
    episodeProgressById: [Int: PhucTvPlaybackProgressSnapshot],
    onOpenEpisode: @escaping (PhucTvMovieEpisode) -> Void,
    onOpenDetail: @escaping (PhucTvMovieCard) -> Void,
    onOpenSearch: @escaping () -> Void
) -> some View {
    if let detail {
        switch selectedTab {
        case .episodes:
            DetailEpisodesTab(detail: detail, episodeProgressById: episodeProgressById, onOpenEpisode: onOpenEpisode)
        case .synopsis:
            DetailSynopsisTab(detail: detail)
        case .information:
            DetailInformationTab(detail: detail)
        case .classification:
            DetailClassificationTab(detail: detail)
        case .gallery:
            DetailGalleryTab(detail: detail)
        case .related:
            DetailRelatedTab(detail: detail, onOpenDetail: onOpenDetail, onOpenSearch: onOpenSearch)
        }
    }
}

private struct DetailEpisodesTab: View {
    let detail: PhucTvMovieDetail
    let episodeProgressById: [Int: PhucTvPlaybackProgressSnapshot]
    let onOpenEpisode: (PhucTvMovieEpisode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(text: "Episodes")

            if detail.episodes.isEmpty {
                Text("No episodes available yet.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(detail.episodes.enumerated()), id: \.element.id) { index, episode in
                        Button(action: { onOpenEpisode(episode) }) {
                            DetailEpisodeRow(
                                movie: detail.movie,
                                episode: episode,
                                progress: episodeProgressById[episode.id],
                                episodeIndex: index + 1,
                                totalEpisodes: detail.episodes.count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DetailSynopsisTab: View {
    let detail: PhucTvMovieDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(text: "Synopsis")
            Text(detail.description)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DetailInformationTab: View {
    let detail: PhucTvMovieDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(text: "Information")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(infoItems, id: \.label) { item in
                    DetailInfoCard(
                        label: item.label,
                        value: item.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "N/A" : item.value
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var infoItems: [DetailInfoItem] {
        [
            DetailInfoItem(label: "Director", value: detail.director),
            DetailInfoItem(label: "Cast", value: detail.castString),
            DetailInfoItem(label: "Show times", value: detail.showTimes),
            DetailInfoItem(label: "More info", value: detail.moreInfo),
            DetailInfoItem(label: "Trailer", value: detail.trailer),
            DetailInfoItem(label: "Status", value: [detail.statusTitle, detail.statusText, detail.statusRaw].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "))
        ]
    }
}

private struct DetailClassificationTab: View {
    let detail: PhucTvMovieDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(text: "Classification")

            if !detail.countries.isEmpty {
                DetailMiniLabel(text: "Countries")
                FlowWrapLayout(items: detail.countries.map(\.name)) { DetailLabelChip(text: $0) }
            }

            if !detail.categories.isEmpty {
                DetailMiniLabel(text: "Categories")
                FlowWrapLayout(items: detail.categories.map(\.name)) { DetailLabelChip(text: $0) }
            }
        }
    }
}

private struct DetailGalleryTab: View {
    let detail: PhucTvMovieDetail

    var body: some View {
        let images = Array(Set(detail.photoUrls + detail.previewPhotoUrls)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(text: "Gallery")

            if images.isEmpty {
                Text("No gallery images available.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(images, id: \.self) { url in
                            DetailGalleryImage(url: url)
                        }
                    }
                }
            }
        }
    }
}

private struct DetailRelatedTab: View {
    let detail: PhucTvMovieDetail
    let onOpenDetail: (PhucTvMovieCard) -> Void
    let onOpenSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DetailSectionTitle(text: "Related")
                Spacer(minLength: 12)
                Button(action: onOpenSearch) {
                    Text("VIEW MORE")
                        .font(AppTheme.captionFont.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }

            if detail.relatedMovies.isEmpty {
                Text("No related movies available.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(detail.relatedMovies, id: \.id) { movie in
                            MovieCardView(
                                movie: movie,
                                onTap: {
                                    onOpenDetail(movie)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct DetailEpisodeRow: View {
    let movie: PhucTvMovieCard
    let episode: PhucTvMovieEpisode
    let progress: PhucTvPlaybackProgressSnapshot?
    let episodeIndex: Int
    let totalEpisodes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.displayTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    FlowWrapLayout(items: rowPills) { text in
                        FeatureMetaPill(text: text)
                    }

                    Text(continueWatchingText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    Text("Tap để xem ngay")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                RemoteImageView(
                    url: detailEpisodePosterURL(from: detailEpisodeArtwork(for: movie)),
                    cornerRadius: 18
                )
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.red)
                        .shadow(color: Color.black.opacity(0.36), radius: 8, x: 0, y: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                ProgressView(value: progressValue)
                    .tint(.red)

                HStack {
                    Text(progressLeadingText)
                    Spacer()
                    Text(progressTrailingText)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(1),
                    Color.black.opacity(0.258),
                    Color.black.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var rowPills: [String] {
        [
            badgeText(movie.quantity),
            "Ep \(displayEpisodeIndex) / \(max(totalEpisodes, 1))",
        ]
        .compactMap { $0 }
    }

    private var displayEpisodeIndex: Int {
        let rawEpisodeNumber = episode.episodeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsedValue = Int(rawEpisodeNumber), parsedValue > 0 {
            return parsedValue
        }
        return episodeIndex
    }

    private var progressValue: Double {
        progress?.progressFraction ?? 0
    }

    private var progressLeadingText: String {
        "\(progressPercent)%"
    }

    private var progressTrailingText: String {
        "Ep \(displayEpisodeIndex) / \(max(totalEpisodes, 1))"
    }

    private var progressPercent: Int {
        Int((progressValue * 100).rounded())
    }

    private var continueWatchingText: String {
        "Tiếp tục: \(progressPercent)% - \(playbackProgressText)"
    }

    private var playbackProgressText: String {
        guard let progress, progress.durationMillis > 0 else {
            let fallbackDuration = movie.time.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fallbackDuration.isEmpty else { return "0/0 phút" }
            return "0/\(fallbackDuration)"
        }

        let duration = max(progress.durationMillis, 0)
        let position = min(max(progress.positionMillis, 0), duration)
        return "\(formatDetailEpisodeDuration(position))/\(formatDetailEpisodeDuration(duration))"
    }
}

private struct DetailBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.10, blue: 0.18).opacity(0.85),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )
        }
    }
}

private struct DetailHeroAction: View {
    let text: String
    let systemImage: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(AppTheme.captionFont.weight(.semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? AppTheme.accent : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(filled ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct DetailTabChip: View {
    let label: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? AppTheme.accent.opacity(0.20) : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(selected ? AppTheme.accent.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct DetailMetaRow: View {
    let pills: [String]

    var body: some View {
        FlowWrapLayout(items: pills) { text in
            DetailMetaPill(text: text)
        }
    }
}

private struct DetailMetaPill: View {
    let text: String

    var body: some View {
        FeatureMetaPill(text: text)
    }
}

private struct DetailLabelChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.captionFont.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct DetailMiniLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.captionFont.weight(.bold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }
}

private struct DetailSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.sectionTitleFont)
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private struct DetailSectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct DetailIconButton: View {
    let icon: String
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)
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

private struct DetailGalleryImage: View {
    let url: String

    var body: some View {
        RemoteImageView(url: detailURL(url))
            .frame(width: 180, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct DetailInfoItem: Hashable {
    let label: String
    let value: String
}

private struct DetailInfoCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func detailURL(_ value: String) -> URL? {
    URL(string: value)
}

private func detailEpisodePosterURL(from rawValue: String?) -> URL? {
    guard let rawValue else { return nil }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

    let scheme = url.scheme?.lowercased()
    guard scheme == "http" || scheme == "https" else { return nil }

    return url
}

private func detailEpisodeArtwork(for movie: PhucTvMovieCard) -> String {
    let banner = movie.displayBanner.trimmingCharacters(in: .whitespacesAndNewlines)
    if !banner.isEmpty {
        return banner
    }

    return movie.displayPoster
}

private func formatDetailEpisodeDuration(_ positionMs: Int64) -> String {
    let totalSeconds = max(positionMs, 0) / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private func badgeText(_ rawValue: String?) -> String? {
    guard let rawValue else { return nil }
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

#Preview("Detail") {
    DetailScreen(
        viewModel: DetailViewModel.previewLoaded(),
        router: AppRouter()
    )
}
