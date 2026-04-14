import SwiftUI

struct MovieCardView: View {
    let movie: PhucTvMovieCard
    let onTap: () -> Void

    private let cardSize = CGSize(width: 150, height: 300)
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RemoteImageView(
                    url: movieCardRemoteURL(from: movie.displayPoster),
                    cornerRadius: 26
                )
                .frame(width: cardSize.width, height: cardSize.height)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.56),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        if let qualityText = badgeText(movie.quantity) {
                            FeatureMetaPill(text: qualityText)
                        }

                        Spacer(minLength: 12)

                        if let statusText = badgeText(movie.statusTitle) {
                            FeatureMetaPill(text: statusText)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    Spacer()

                    VStack(alignment: .leading, spacing: 7) {
                        Text(movie.displayTitle)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        if let releaseText = releaseText {
                            Text(releaseText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }

                        if let statsText = statsText {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.36))

                                Text(statsText)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary.opacity(0.96))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.34), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var releaseText: String? {
        let parts = [
            movie.year > 0 ? String(movie.year) : nil,
            badgeText(movie.time)
        ]
        .compactMap { $0 }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var statsText: String? {
        let ratingValue: String? = {
            guard movie.ratePoint > 0 else {
                return badgeText(movie.rating)
            }
            return String(format: "%.1f", movie.ratePoint)
        }()

        let episodeValue: String? = {
            guard movie.episodesTotal > 0 else { return nil }
            return "\(movie.episodesTotal) tập"
        }()

        let parts = [ratingValue, episodeValue].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }
}

private func badgeText(_ rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func movieCardRemoteURL(from rawValue: String?) -> URL? {
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

#Preview("Movie Card Poster") {
    ZStack {
        AppTheme.background
            .ignoresSafeArea()

        MovieCardView(movie: .previewMovieCard) { }
            .padding(24)
    }
}

private extension PhucTvMovieCard {
    static let previewMovieCard = PhucTvMovieCard(
        id: 1,
        name: "The Witcher",
        otherName: "Season 1",
        avatar: "https://image.tmdb.org/t/p/w500/8WUVHemHFH2ZIP6NWkwlHWsyrEL.jpg",
        bannerThumb: "",
        avatarThumb: "https://image.tmdb.org/t/p/w500/8WUVHemHFH2ZIP6NWkwlHWsyrEL.jpg",
        description: "Geralt of Rivia battles monsters and destiny across the Continent.",
        banner: "",
        imageIcon: "",
        link: "/the-witcher",
        quantity: "HD",
        rating: "8.7",
        year: 2019,
        statusTitle: "Tập 12",
        statusRaw: "ongoing",
        statusText: "Ongoing",
        director: "Alik Sakharov",
        time: "55m",
        trailer: "",
        showTimes: "",
        moreInfo: "",
        castString: "Henry Cavill",
        episodesTotal: 32,
        viewNumber: 0,
        ratePoint: 8.7,
        photoUrls: [],
        previewPhotoUrls: []
    )
}
