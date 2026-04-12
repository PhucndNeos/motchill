//
//  DetailsIpadScreen.swift
//  MotchillSwiftUI
//
//  Created by Phucnd on 11/4/26.
//  Copyright © 2026 Motchill. All rights reserved.
//

import SwiftUI
import UIKit

struct DetailsIpadScreen: View {
    let viewModel: DetailViewModel
    let router: AppRouter
    let onToggleLike: () -> Void
    let onOpenTrailer: () -> Void
    let onOpenEpisode: (MotchillMovieEpisode) -> Void

    var body: some View {
        GeometryReader { proxy in
            let sidebarWidth = min(max(proxy.size.width * 0.40, 400), 560)

            HStack(spacing: 0) {
                IpadDetailSidebar(
                    viewModel: viewModel,
                    onToggleLike: onToggleLike,
                    onOpenTrailer: onOpenTrailer,
                    onOpenEpisode: {
                        guard let episode = viewModel.detail?.episodes.first else { return }
                        onOpenEpisode(episode)
                    }
                )
                .frame(width: sidebarWidth, height: proxy.size.height)
                .clipped()

                IpadDetailContent(
                    viewModel: viewModel,
                    router: router,
                    onOpenEpisode: onOpenEpisode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(IpadDetailBackground(viewModel: viewModel).ignoresSafeArea())
        }
    }
}

private struct IpadDetailSidebar: View {
    let viewModel: DetailViewModel
    let onToggleLike: () -> Void
    let onOpenTrailer: () -> Void
    let onOpenEpisode: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 14) {
                    Text(viewModel.title)
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 360, alignment: .leading)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)

                    if !viewModel.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(viewModel.subtitle)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 360, alignment: .leading)
                            .allowsTightening(true)
                    }
                    
                    HStack(spacing: 14) {
                        Button(action: onOpenEpisode) {
                            FeaturePrimaryAction(text: "Watch Now", systemImage: "play.fill")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onOpenTrailer) {
                            FeatureSecondaryAction(text: "Trailer", systemImage: "film")
                        }
                        .buttonStyle(.plain)
                    }

                    IpadMetaRow(pills: viewModel.metadataPills)

                    Text(viewModel.summary)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 360, alignment: .leading)
                        .lineLimit(8)
                }
                .frame(maxWidth: 360, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .padding(.top, 120)
        }
        .clipped()
    }
}

private struct IpadDetailContent: View {
    let viewModel: DetailViewModel
    let router: AppRouter
    let onOpenEpisode: (MotchillMovieEpisode) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 44) {
                if let detail = viewModel.detail {
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
                                        IpadEpisodeRow(
                                            episode: episode,
                                            progress: viewModel.episodeProgressById[episode.id],
                                            episodeIndex: index + 1
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    IpadSection(title: "Synopsis") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(viewModel.summary)
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(6)

                            if let trailer = viewModel.trailerURL(), !trailer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    openExternalURL(trailer)
                                }) {
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
                                value: [detail.statusTitle, detail.statusText, detail.statusRaw].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • ")
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
                        let images = Array(Set(detail.photoUrls + detail.previewPhotoUrls)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
                            .cornerRadius(20)
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
                                        MovieCardView(
                                            movie: movie,
                                            onTap: { router.push(.detail(movie)) }
                                        )
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
    }
}

private struct IpadDetailBackground: View {
    var viewModel: DetailViewModel
    var body: some View {
        ZStack {
            RemoteImageView(url: ipadDetailURL(bannerURL), cornerRadius: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.60),
                            Color.black.opacity(0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

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
    
    private var bannerURL: String {
        if let avatarThumb = viewModel.detail?.bannerThumb,
           !avatarThumb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return avatarThumb
        }
        return viewModel.movie.displayBanner
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

private struct IpadEpisodeRow: View {
    let episode: MotchillMovieEpisode
    let progress: MotchillPlaybackProgressSnapshot?
    let episodeIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", episodeIndex))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.26))
                    .frame(width: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.label)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    Text(episodeSecondaryText(episode: episode, progress: progress))
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress, shouldShowEpisodeProgressBar(progress) {
                ProgressView(value: progress.progressFraction)
                    .tint(.orange)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
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
    URL(string: value)
}
