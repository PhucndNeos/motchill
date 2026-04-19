import ComposableArchitecture
import SwiftUI
import UIKit

struct DetailsIpadScreen: View {
    @Bindable var store: StoreOf<DetailFeature>

    var body: some View {
        GeometryReader { proxy in
            let sidebarWidth = min(max(proxy.size.width * 0.40, 400), 560)

            HStack(spacing: 0) {
                IpadDetailSidebar(
                    title: store.title,
                    subtitle: store.subtitle,
                    summary: store.summary,
                    metadataPills: store.metadataPills,
                    primaryEpisode: store.primaryEpisode,
                    trailerURL: store.trailerURL,
                    onOpenEpisode: openPrimaryEpisode,
                    onOpenTrailer: openTrailer
                )
                .frame(width: sidebarWidth, height: proxy.size.height)

                IpadDetailContent(
                    store: store,
                    onOpenEpisode: { store.send(.playEpisodeTapped($0)) },
                    onOpenRelatedMovie: { store.send(.relatedMovieTapped($0)) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func openPrimaryEpisode() {
        guard let episode = store.primaryEpisode else { return }
        store.send(.playEpisodeTapped(episode))
    }

    private func openTrailer() {
        openExternalURL(store.trailerURL)
    }
}

private struct IpadDetailSidebar: View {
    let title: String
    let subtitle: String
    let summary: String
    let metadataPills: [String]
    let primaryEpisode: PhucTvMovieEpisode?
    let trailerURL: String?
    let onOpenEpisode: () -> Void
    let onOpenTrailer: () -> Void

    var body: some View {

            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)

                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsTightening(true)
                }

                HStack(spacing: 14) {
                    Button(action: onOpenEpisode) {
                        FeaturePrimaryAction(text: "Watch Now", systemImage: "play.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(primaryEpisode == nil)

                    Button(action: onOpenTrailer) {
                        FeatureSecondaryAction(text: "Trailer", systemImage: "film")
                    }
                    .buttonStyle(.plain)
                    .disabled((trailerURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                IpadMetaRow(pills: metadataPills)

                Text(summary)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(8)
            }
            .padding(32)
        }
}

private struct IpadDetailContent: View {
    let store: StoreOf<DetailFeature>
    let onOpenEpisode: (PhucTvMovieEpisode) -> Void
    let onOpenRelatedMovie: (PhucTvMovieCard) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if let detail = store.detail {
                        stackedContent(for: detail, proxy: proxy)
                    }
                }
                .padding(32)
            }
        }
    }

    @ViewBuilder
    private func stackedContent(
        for detail: PhucTvMovieDetail,
        proxy: ScrollViewProxy
    ) -> some View {
        VStack(alignment: .leading, spacing: 44) {
            IpadSection(
                title: "Episodes",
                subtitle: detail.episodes.isEmpty ? nil : "Season 01 • \(detail.episodes.count) Episodes"
            ) {
                if detail.episodes.isEmpty {
                    Text("No episodes available yet.")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(detail.episodes.enumerated()), id: \.element.id) { index, episode in
                            Button(action: { onOpenEpisode(episode) }) {
                                DetailEpisodeRow(
                                    movie: detail.movie,
                                    episode: episode,
                                    progress: store.episodeProgressById[episode.id],
                                    episodeIndex: index + 1,
                                    totalEpisodes: detail.episodes.count
                                )
                            }
                            .buttonStyle(.plain)
                            .id(episode.id)
                        }
                    }
                    .task(id: preferredEpisodeScrollTargetID(detail: detail, episodeProgressById: store.episodeProgressById)) {
                        guard let targetID = preferredEpisodeScrollTargetID(detail: detail, episodeProgressById: store.episodeProgressById) else { return }
                        await MainActor.run {
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                    }
                }
            }

            IpadSection(title: "Synopsis") {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.overviewText)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(6)

                    if let trailer = store.trailerURL,
                       !trailer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: { openExternalURL(trailer) }) {
                            Text("Open Trailer")
                                .font(AppTheme.captionFont.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
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
            }

            IpadSection(title: "Information") {
                VStack(alignment: .leading, spacing: 18) {
                    IpadInfoCard(label: "Director", value: detail.director)
                    IpadInfoCard(label: "Cast", value: detail.castString)
                    IpadInfoCard(label: "Show times", value: detail.showTimes)
                    IpadInfoCard(label: "More info", value: detail.moreInfo)
                    IpadInfoCard(label: "Trailer", value: detail.trailer)
                    IpadInfoCard(
                        label: "Status",
                        value: [detail.statusTitle, detail.statusText, detail.statusRaw]
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .joined(separator: " • ")
                    )
                }
            }

            IpadSection(title: "Classification") {
                VStack(alignment: .leading, spacing: 18) {
                    if !detail.countries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            IpadMiniLabel(text: "Countries")
                            FlowWrapLayout(items: detail.countries.map(\.name)) { IpadLabelChip(text: $0) }
                        }
                    }

                    if !detail.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            IpadMiniLabel(text: "Categories")
                            FlowWrapLayout(items: detail.categories.map(\.name)) { IpadLabelChip(text: $0) }
                        }
                    }
                }
            }

            IpadSection(title: "Gallery") {
                let images = Array(Set(detail.photoUrls + detail.previewPhotoUrls))
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                if images.isEmpty {
                    Text("No gallery images available.")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    TabView {
                        ForEach(images, id: \.self) { url in
                            IpadGalleryImage(url: url)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            IpadSection(title: "Related") {
                if detail.relatedMovies.isEmpty {
                    Text("No related movies available.")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(detail.relatedMovies, id: \.id) { movie in
                                MovieCardView(movie: movie, onTap: { onOpenRelatedMovie(movie) })
                                    .frame(width: 140, height: 210)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

private struct IpadSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.captionFont.weight(.medium))
                        .foregroundStyle(Color(red: 0.80, green: 0.62, blue: 0.55))
                }
            }

            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct IpadMetaRow: View {
    let pills: [String]

    var body: some View {
        if pills.isEmpty {
            EmptyView()
        } else {
            FlowWrapLayout(items: pills) { pill in
                IpadMetaPill(text: pill)
            }
        }
    }
}

private struct IpadMetaPill: View {
    let text: String

    var body: some View {
        FeatureMetaPill(text: text)
    }
}

private struct IpadLabelChip: View {
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

private struct IpadMiniLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.captionFont.weight(.bold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }
}

private struct IpadInfoCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "N/A" : value)
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

private struct IpadGalleryImage: View {
    let url: String

    var body: some View {
        RemoteImageView(url: ipadDetailURL(url))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private func ipadDetailURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
        return nil
    }

    return url
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
                    Text(episode.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    FlowWrapLayout(items: rowPills) { text in
                        FeatureMetaPill(text: text)
                    }

                    Text(continueWatchingText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)

                    Text("Tap để xem ngay")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                RemoteImageView(
                    url: detailEpisodePosterURL(from: detailEpisodeArtwork(for: movie)),
                    cornerRadius: 18,
                    width: 100,
                    height: 100
                )
                .overlay {
                    Image("Pause")
                        .resizable()
                        .scaledToFit()
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

#Preview("iPad Detail") {
    NavigationStack {
        DetailView(
            store: Store(initialState: DetailFeature.State.previewLoaded()) {
                DetailFeature()
            }
        )
    }
}
