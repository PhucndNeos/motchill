import SwiftUI

struct HomeScreen: View {
    let viewModel: HomeViewModel
    let router: AppRouter

    var body: some View {
        let contentWidth = max(AppContainer.shared.configuration.screenSize.width - 48, 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HomeHeader(onTapSearch: openSearch)

                switch viewModel.state {
                case .loading:
                    HomeStatusCard(
                        title: "Đang tải nội dung",
                        subtitle: "Chờ một lát để nạp các section nổi bật.",
                        showsProgress: true,
                        actionTitle: nil,
                        onAction: nil
                    )
                case .empty:
                    HomeStatusCard(
                        title: "Chưa có nội dung",
                        subtitle: "Trang chủ sẽ hiển thị các section khi dữ liệu sẵn sàng.",
                        showsProgress: false,
                        actionTitle: "Tìm kiếm",
                        onAction: openSearch
                    )
                case .error(let message):
                    HomeStatusCard(
                        title: "Không thể tải trang chủ",
                        subtitle: message,
                        showsProgress: false,
                        actionTitle: "Thử lại",
                        onAction: retry
                    )
                case .loaded:
                    HomeLoadedContent(
                        viewModel: viewModel,
                        router: router
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(HomeBackground().ignoresSafeArea())
    }

    private func retry() {
        Task {
            await viewModel.retry()
        }
    }

    private func openSearch() {
        router.push(.search)
    }
}

private struct HomeLoadedContent: View {
    let viewModel: HomeViewModel
    let router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !viewModel.heroMovies.isEmpty {
                HomeHeroStage(
                    viewModel: viewModel,
                    router: router
                )
                .aspectRatio(4/3, contentMode: .fit)
            }

            HomeSectionList(
                sections: viewModel.contentSections,
                router: router
            )
        }
    }
}

private struct HomeHeader: View {
    let onTapSearch: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Motchill")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Khám phá nội dung nổi bật, chuyển nhanh sang tìm kiếm, và giữ nhịp điều hướng giống Android.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: onTapSearch) {
                Label("Tìm kiếm", systemImage: "magnifyingglass")
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
    }
}

private struct HomeHeroStage: View {
    let viewModel: HomeViewModel
    let router: AppRouter
    @State private var activeHeroID: Int?

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - 48, 1)
            let height = width * 0.75

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(viewModel.heroMovies, id: \.id) { movie in
                        HomeHeroSlideItem(
                            movie: movie,
                            onTap: {
                                router.push(.detail(movie))
                            }
                        )
                        .frame(width: width, height: height)
                        .id(movie.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeHeroID)
            .onAppear {
                if activeHeroID == nil {
                    activeHeroID = viewModel.heroMovies.first?.id
                }
            }
            .frame(height: height)
        }
    }
}

private struct HomeHeroSlideItem: View {
    let movie: MotchillMovieCard
    let onTap: () -> Void

    var body: some View {
        GeometryReader { p in
            Button(action: onTap) {
                ZStack(alignment: .bottomTrailing) {
                    HomeHeroBackdrop(movie: movie)
                        .frame(width: p.size.width, height: p.size.height)
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.78),
                            Color.black.opacity(0.38),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.90)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text(movie.displayTitle)
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)

                        Text(movieSummary(for: movie))
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(4)

                        HomeMetaRow(movie: movie)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(movie.rating.isEmpty ? "Slide" : movie.rating)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.72))
                            )
                    }
                    .padding(24)
                }
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
                    .opacity(phase.isIdentity ? 1.0 : 0.88)
            }
        }
    }
}

private struct HomeHeroBackdrop: View {
    let movie: MotchillMovieCard

    var body: some View {
        ZStack {
            RemoteImageView(url: remoteURL(from: movie.displayBanner))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.50),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.30, blue: 0.42).opacity(0.22),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
        }
        .clipped()
    }
}

private struct HomeMetaRow: View {
    let movie: MotchillMovieCard

    var body: some View {
        HStack(spacing: 8) {
            HomeMetaPill(text: movie.year > 0 ? String(movie.year) : nil)
            HomeMetaPill(text: movie.rating.isEmpty ? nil : movie.rating)
            HomeMetaPill(text: movie.statusTitle.isEmpty ? nil : movie.statusTitle)
            HomeMetaPill(text: movie.quantity.isEmpty ? nil : movie.quantity)
        }
    }
}

private struct HomeBackground: View {
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
                    Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.18),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 540
            )

            RadialGradient(
                colors: [
                    AppTheme.accent.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 560
            )
        }
    }
}

private struct HomeSectionList: View {
    let sections: [MotchillHomeSection]
    let router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(sections, id: \.self) { section in
                HomeSectionRail(
                    section: section,
                    router: router
                )
            }
        }
    }
}

private struct HomeSectionRail: View {
    let section: MotchillHomeSection
    let router: AppRouter

    var body: some View {
        let products = section.products

        if products.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.title.isEmpty ? section.key : section.title)
                        .font(AppTheme.sectionTitleFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button(action: {
                        router.push(.search)
                    }) {
                        Text("Xem thêm")
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

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(products, id: \.id) { movie in
                            MovieCardView(
                                movie: movie,
                                onTap: {
                                    router.push(.detail(movie))
                                }
                            )
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
    }
}

struct MovieCardView: View {
    let movie: MotchillMovieCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    RemoteImageView(url: remoteURL(from: movie.displayPoster))
                        .frame(width: 136, height: 220)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.45),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if !movie.rating.isEmpty {
                        HomeRatingBadge(
                            text: movie.rating
                        )
                        .padding(10)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                Text(movie.displayTitle)
                    .font(AppTheme.cardTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                Text(movie.displaySubtitle.isEmpty ? movie.statusTitle : movie.displaySubtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 136, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeMetaPill: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(AppTheme.captionFont.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.red.opacity(0.3))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct HomeRatingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
    }
}

private struct HomeStatusCard: View {
    let title: String
    let subtitle: String
    let showsProgress: Bool
    let actionTitle: String?
    let onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsProgress {
                ProgressView()
                    .tint(Color(red: 0.92, green: 0.22, blue: 0.26))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppTheme.sectionTitleFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                }
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
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }
}

private func movieSummary(for movie: MotchillMovieCard) -> String {
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

private func remoteURL(from rawValue: String?) -> URL? {
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
