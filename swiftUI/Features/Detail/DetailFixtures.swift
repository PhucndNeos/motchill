import Foundation

extension DetailFeature.State {
    static func previewLoaded() -> Self {
        var state = Self(movie: DetailMockData.movie)
        state.detail = DetailMockData.detail
        state.screenState = .loaded
        state.selectedTab = DetailMockData.detail.defaultTab
        state.isLiked = true
        state.episodeProgressById = [
            1: PhucTvPlaybackProgressSnapshot(positionMillis: 120_000, durationMillis: 600_000)
        ]
        return state
    }

    static func previewLoading() -> Self {
        var state = Self(movie: DetailMockData.movie)
        state.screenState = .loading
        return state
    }

    static func previewError() -> Self {
        var state = Self(movie: DetailMockData.movie)
        state.screenState = .error(message: "Không thể tải chi tiết ngay lúc này.")
        return state
    }
}
