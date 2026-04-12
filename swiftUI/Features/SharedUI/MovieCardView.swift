import SwiftUI

struct MovieCardView: View {
    let movie: MotchillMovieCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RemoteImageView(url: movieCardRemoteURL(from: movie.displayPoster))
                    .frame(width: 136, height: 220)
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(1),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                if !movie.rating.isEmpty {
                    MovieCardRatingBadge(text: movie.rating)
                        .padding(10)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MovieCardRatingBadge: View {
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
