import Foundation

extension PlayerFeature.State {
    static func previewLoaded() -> Self {
        var state = Self(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            summary: DetailMockData.detail.description
        )
        state.sources = PlayerMockData.sources
        state.selectedSourceIndex = 0
        state.selectedAudioTrack = PlayerMockData.sources.first?.defaultAudioTrack
        state.selectedSubtitleTrack = PlayerMockData.sources.first?.defaultSubtitleTrack
        state.currentPositionMillis = 120_000
        state.durationMillis = 600_000
        state.isPlaying = true
        state.overlayVisible = true
        state.currentSubtitleText = "Hello world"
        state.screenState = .loaded
        return state
    }

    static func previewError() -> Self {
        var state = Self(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            summary: DetailMockData.detail.description
        )
        state.screenState = .error(message: "Không thể nạp nguồn phát trong preview.")
        return state
    }

    static func previewIframeOnlyError() -> Self {
        var state = Self(
            movieID: DetailMockData.detail.id,
            episodeID: DetailMockData.detail.episodes.first?.id ?? 1,
            movieTitle: DetailMockData.detail.title,
            episodeLabel: DetailMockData.detail.episodes.first?.label ?? "Episode 1",
            summary: DetailMockData.detail.description
        )
        state.sources = PlayerMockData.iframeSources
        state.screenState = .error(message: "Không có nguồn phát trực tiếp. Chọn một iframe bên dưới để mở trong WebView.")
        return state
    }
}

private enum PlayerMockData {
    static let sources: [PhucTvPlaySource] = [
        PhucTvPlaySource(
            sourceId: 1,
            serverName: "Server 1",
            link: "https://example.com/stream-1080.m3u8",
            subtitle: "",
            type: 0,
            isFrame: false,
            quality: "1080p",
            tracks: [
                PhucTvPlayTrack(kind: "audio", file: "https://example.com/audio-en.m3u8", label: "English", isDefault: true),
                PhucTvPlayTrack(kind: "subtitle", file: "https://example.com/sub-en.vtt", label: "English", isDefault: true)
            ]
        ),
        PhucTvPlaySource(
            sourceId: 2,
            serverName: "Server 2",
            link: "https://example.com/stream-720.m3u8",
            subtitle: "https://example.com/sub-vi.vtt",
            type: 0,
            isFrame: false,
            quality: "720p",
            tracks: []
        )
    ]

    static let iframeSources: [PhucTvPlaySource] = [
        PhucTvPlaySource(
            sourceId: 11,
            serverName: "Iframe 1",
            link: "https://example.com/embed-1",
            subtitle: "",
            type: 0,
            isFrame: true,
            quality: "720p",
            tracks: []
        ),
        PhucTvPlaySource(
            sourceId: 12,
            serverName: "Iframe 2",
            link: "https://example.com/embed-2",
            subtitle: "",
            type: 0,
            isFrame: true,
            quality: "1080p",
            tracks: []
        )
    ]
}
