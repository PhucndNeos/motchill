//
//  HomeIpadComponents.swift
//  PhucTvSwiftUI
//
//  Created by Phucnd on 11/4/26.
//  Copyright © 2026 PhucTv. All rights reserved.
//
import ComposableArchitecture
import Kingfisher
import SwiftUI
import UIKit

/// The primary layout container for the iPad Home screen.
/// It observes the `HomeFeature` state to switch between loading, empty, error, and loaded UI views.
struct HomeIpadScreen: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HomeIpadBackground()
                    .ignoresSafeArea()

                switch store.status {
                case .loading:
                    FeatureStateOverlay(
                        descriptor: .loading(
                            title: "Đang tải nội dung",
                            message: "Chờ một lát để nạp hero feature cho iPad.",
                            errorCode: "HOME_LOADING"
                        ),
                        onRetry: { store.send(.retryTapped) }
                    )
                case .empty:
                    FeatureStateOverlay(
                        descriptor: .empty(
                            title: "Chưa có nội dung",
                            message: "Hero sẽ xuất hiện khi dữ liệu trang chủ sẵn sàng. Bạn có thể thử tìm kiếm nội dung khác trong lúc chờ.",
                            errorCode: "HOME_EMPTY",
                            secondaryTitle: "Tìm kiếm"
                        ),
                        onRetry: { store.send(.retryTapped) },
                        onSecondary: { store.send(.searchTapped) }
                    )
                case .error(let message):
                    FeatureStateOverlay(
                        descriptor: .failure(
                            title: "Không thể tải trang chủ",
                            message: message,
                            errorCode: "HOME_LOAD_FAIL",
                            icon: .server
                        ),
                        onRetry: { store.send(.retryTapped) }
                    )
                case .loaded(_):
                    if store.hasRenderableContent,
                       let section = store.selectedSection,
                           !section.products.isEmpty {
                        HomeIpadLoadedContent(
                            store: store,
                            heroMovies: section.products
                        )
                    } else {
                        FeatureStateOverlay(
                            descriptor: .empty(
                                title: "Chưa có nội dung",
                                message: "Trang chủ hiện chưa có section nào để hiển thị. Bạn có thể thử tìm kiếm nội dung khác trong lúc chờ.",
                                errorCode: "HOME_EMPTY",
                                secondaryTitle: "Tìm kiếm"
                            ),
                            onRetry: { store.send(.retryTapped) },
                            onSecondary: { store.send(.searchTapped) }
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()        
    }
}

@MainActor
private func openTrailer(_ trailer: String) {
    openExternalURL(trailer)
}

private struct HomeIpadLoadedContent: View {
    @Bindable var store: StoreOf<HomeFeature>
    let heroMovies: [PhucTvMovieCard]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FeaturePagingView(
                selectedItem: $store.selectedMovie,
                items: heroMovies,
                spacing: 0,
                horizontalPadding: 0,
                onSelectionChanged: nil
            ) { currentMovie in
                HomeIpadHeroCardView(
                    movie: currentMovie,
                    onWatchNow: {
                        store.send(.detailTapped(movie: currentMovie))
                    },
                    onTrailer: {
                        openTrailer(currentMovie.trailer)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .id(store.selectedSection?.id ?? "home-ipad-hero")
            .onAppear {
                syncSelectionIfNeeded()
            }
            .onChange(of: heroMovies.map(\.id)) { _, _ in
                syncSelectionIfNeeded()
            }
            
            HomeIpadIndicator(
                selectedMovie: $store.selectedMovie,
                items: heroMovies
            )
                .padding()
        }
    }

    private func syncSelectionIfNeeded() {
        guard !heroMovies.isEmpty else {
            store.selectedMovie = nil
            return
        }

        if let selectedID = store.selectedMovie?.id,
           let matched = heroMovies.first(where: { $0.id == selectedID }) {
            store.selectedMovie = matched
            return
        }

        store.selectedMovie = heroMovies.first
    }
}

private struct HomeIpadHeroCardView: View {
    let movie: PhucTvMovieCard
    let onWatchNow: () -> Void
    let onTrailer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = proxy.size.width

            ZStack {
                HomeIpadHeroBackdrop(movie: movie)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black,
                        .black.opacity(0.5),
                        .black.opacity(0.02)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                HStack(alignment: .center, spacing: 56) {
                    VStack(alignment: .leading, spacing: 24) {
                        HomeIpadMetadataRow(movie: movie)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text(movie.displayTitle.uppercased())
                                .font(.system(size: 66, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.98, green: 0.98, blue: 0.99),
                                            Color(red: 1.0, green: 0.78, blue: 0.74)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .tracking(-2.6)
                                .shadow(color: Color.black.opacity(0.40), radius: 24, x: 0, y: 10)
                            
                            if !movie.otherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(movie.otherName.uppercased())
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.84))
                                    .tracking(1.2)
                                    .lineLimit(2)
                            }
                        }
                        .frame(alignment: .center)
                        
                        HStack(spacing: 16) {
                            Button(action: onWatchNow) {
                                HomeIpadPrimaryAction(text: "Watch Now", systemImage: "play.fill")
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: onTrailer) {
                                FeatureSecondaryAction(text: "Trailer", systemImage: "film")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                        
                        Text(movieSummary(for: movie))
                            .lineLimit(5)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 560, alignment: .leading)
                        
                        HomeIpadCreditRow(movie: movie)
                                                
                    }
                    .frame(maxWidth: 660, alignment: .leading)
                    
                    Spacer(minLength: 0)
                    
                    HomeIpadPosterCard(movie: movie)
                }
                .padding(.horizontal, 20)
                .frame(width: contentWidth, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.08))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -120, y: -80)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.71, blue: 0.66).opacity(0.06))
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .offset(x: 120, y: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomeIpadBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.13),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.14),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 680
            )

            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.53, blue: 1.00).opacity(0.08),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 780
            )
        }
        .ignoresSafeArea()
    }
}

private struct HomeIpadHeroBackdrop: View {
    let movie: PhucTvMovieCard

    var body: some View {
        ZStack {
            RemoteImageView(url: homeRemoteURL(from: movie.displayBanner), cornerRadius: 0)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.50),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            RadialGradient(
                colors: [
                    Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 700
            )
        }
        .clipped()
    }
}

private struct HomeIpadMetadataRow: View {
    let movie: PhucTvMovieCard

    var body: some View {
        HStack(spacing: 14) {
            HomeIpadMetaItem(
                icon: "calendar",
                text: movie.year > 0 ? String(movie.year) : nil
            )
            HomeIpadSeparatorDot()
            HomeIpadMetaItem(
                icon: "clock",
                text: movie.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : movie.time
            )
            HomeIpadSeparatorDot()
            HomeIpadBadge(text: movie.quantity.isEmpty ? "HD" : movie.quantity)
            HomeIpadMetaItem(
                icon: "star.fill",
                text: movie.rating.isEmpty ? nil : movie.rating,
                isAccent: true
            )
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
    }
}

private struct HomeIpadCreditRow: View {
    let movie: PhucTvMovieCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeIpadCreditLine(
                title: "Directed by",
                value: movie.director
            )
            HomeIpadCreditLine(
                title: "Starring",
                value: movie.castString
            )
        }
    }
}

private struct HomeIpadCreditLine: View {
    let title: String
    let value: String

    var body: some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
                    .tracking(2)
                    .frame(minWidth: 96, alignment: .leading)

                Text(value)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct HomeIpadPosterCard: View {
    let movie: PhucTvMovieCard

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImageView(url: homeRemoteURL(from: movie.displayPoster), cornerRadius: 18)
                .frame(width: 250, height: 510)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 18)
                .rotationEffect(.degrees(2))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: movie.id)

            HomeIpadBadge(text: movie.quantity.isEmpty ? "4K Ultra HD" : movie.quantity)
                .padding(16)
        }
        .overlay(alignment: .bottom) {
            Text(movie.displayTitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.75))
                .tracking(3)
                .offset(y: 26)
        }
    }
}

private struct HomeIpadPrimaryAction: View {
    let text: String
    let systemImage: String

    var body: some View {
        FeaturePrimaryAction(text: text, systemImage: systemImage)
    }
}

private struct HomeIpadIndicator: View {
    @Binding var selectedMovie: PhucTvMovieCard?
    let items: [PhucTvMovieCard]

    var body: some View {
        TabSegmentedView(
            selectedItem: $selectedMovie,
            items: items,
            spacing: 10,
            horizontalPadding: 16
        ) { item, isSelected in
            KFImage(homeRemoteURL(from: item.displayPoster))
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )
                .overlay {
                    if !isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .shadow(radius: 5)
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .center)
    }
}

private struct HomeIpadStateView: View {
    let title: String
    let subtitle: String
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560, alignment: .leading)

            if let retryTitle, let onRetry {
                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.02, blue: 0.03))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.76, blue: 0.73),
                                    Color(red: 0.95, green: 0.15, blue: 0.16)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomeIpadMetaItem: View {
    let icon: String
    let text: String?
    var isAccent: Bool = false

    var body: some View {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)

                Text(text)
            }
            .foregroundStyle(isAccent ? Color(red: 1.0, green: 0.79, blue: 0.77) : AppTheme.textSecondary)
        }
    }
}

private struct HomeIpadSeparatorDot: View {
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.26))
            .frame(width: 5, height: 5)
    }
}

private struct HomeIpadBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 1.0, green: 0.71, blue: 0.63))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private func movieSummary(for movie: PhucTvMovieCard) -> String {
    let candidates = [
        movie.description,
        movie.moreInfo,
        movie.displaySubtitle
    ]

    for candidate in candidates {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
    }

    return "Nội dung nổi bật đang được cập nhật."
}

private func homeRemoteURL(from rawValue: String?) -> URL? {
    guard let rawValue else {
        return nil
    }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return nil
    }

    guard let url = URL(string: trimmed) else {
        return nil
    }

    let scheme = url.scheme?.lowercased()
    guard scheme == "http" || scheme == "https" else {
        return nil
    }

    return url
}

#Preview("Home iPad Hero") {
    HomeIpadScreen(
        store: Store(initialState: HomeFeature.State.previewLoaded()) {
            HomeFeature()
        }
    )
    .preferredColorScheme(.dark)
}
