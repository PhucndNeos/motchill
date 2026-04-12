import Foundation

func episodeSecondaryText(
    episode: MotchillMovieEpisode,
    progress: MotchillPlaybackProgressSnapshot?
) -> String {
    let metadata = [
        normalizedEpisodeTypeLabel(episode.type),
        normalizedEpisodeStatusLabel(episode.status),
    ]
    .compactMap { $0 }
    .filter { !$0.isEmpty }

    let playback = playbackStatusLabel(progress)

    if metadata.isEmpty {
        return playback
    }

    return metadata.joined(separator: " • ") + " • " + playback
}

func shouldShowEpisodeProgressBar(_ progress: MotchillPlaybackProgressSnapshot?) -> Bool {
    guard let progress else { return false }
    return progress.durationMillis > 0 && progress.positionMillis > 0
}

private func normalizedEpisodeTypeLabel(_ rawValue: String) -> String? {
    let normalized = rawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !normalized.isEmpty else { return nil }

    if normalized.contains("sub") {
        return "Vietsub"
    }
    if normalized.contains("dub") {
        return "Lồng tiếng"
    }
    if normalized.contains("raw") {
        return "Raw"
    }

    if normalized == "0" || normalized == "1" || normalized == "true" || normalized == "false" {
        return nil
    }

    return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func normalizedEpisodeStatusLabel(_ rawValue: String) -> String? {
    let normalized = rawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !normalized.isEmpty else { return nil }

    if normalized == "1" || normalized == "true" {
        return "Sẵn sàng"
    }

    if normalized == "0" || normalized == "false" {
        return "Chưa phát hành"
    }

    return nil
}

private func playbackStatusLabel(_ progress: MotchillPlaybackProgressSnapshot?) -> String {
    guard let progress, progress.durationMillis > 0 else {
        return "Chưa xem"
    }

    let duration = progress.durationMillis.clampedToNonNegative
    let position = min(progress.positionMillis.clampedToNonNegative, duration)

    guard position > 0 else {
        return "Chưa xem"
    }

    if position * 100 >= duration * 98 {
        return "Đã xem xong"
    }

    return "Đã xem \(formatPlaybackDuration(position))/\(formatPlaybackDuration(duration))"
}

private func formatPlaybackDuration(_ positionMs: Int64) -> String {
    let totalSeconds = positionMs.clampedToNonNegative / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

private extension Int64 {
    var clampedToNonNegative: Int64 {
        Swift.max(self, 0)
    }
}
