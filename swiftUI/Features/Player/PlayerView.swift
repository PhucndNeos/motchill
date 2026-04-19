import AVKit
import ComposableArchitecture
import SwiftUI

struct PlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>

    @State private var webDestination: PlayerWebDestination?

    var body: some View {
        PlayerPlaybackSurface(
            store: store,
            webDestination: $webDestination,
            onBack: { store.send(.backButtonTapped) }
        )
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $webDestination) { destination in
            NavigationStack {
                PlayerWebViewScreen(destination: destination)
            }
        }
        .task {
            await store.send(.onAppear).finish()
        }
    }
}

private struct PlayerPlaybackSurface: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onBack: () -> Void
    @Binding var webDestination: PlayerWebDestination?

    init(
        store: StoreOf<PlayerFeature>,
        webDestination: Binding<PlayerWebDestination?>,
        onBack: @escaping () -> Void
    ) {
        self._store = Bindable(store)
        self._webDestination = webDestination
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                playerContent
                playerStateOverlay
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        handleSeekGesture(at: value.location.x, width: proxy.size.width)
                    }
            )
            .onTapGesture {
                store.send(.overlayTapped)
            }
        }
    }

    @ViewBuilder
    private var playerContent: some View {
        if store.screenState == .loaded, store.selectedSource != nil {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: store.player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                PlayerSubtitleOverlay(text: store.currentSubtitleText)

                PlayerOverlay(
                    store: store,
                    onBack: onBack
                )
                .opacity(store.overlayVisible ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private var playerStateOverlay: some View {
        switch store.screenState {
        case .idle, .loading:
            FeatureStateOverlay(
                descriptor: .loading(
                    title: "Đang tải player",
                    message: "Chờ một lát để nạp nguồn phát cho tập này.",
                    errorCode: "PLAYER_LOADING"
                ),
                onRetry: retry
            )

        case .error(let message):
            FeatureStateOverlay(
                descriptor: .failure(
                    title: "Không thể mở player",
                    message: message,
                    errorCode: "PLAYER_LOAD_FAIL",
                    icon: .playback,
                    secondaryTitle: "Quay lại"
                ),
                actionButtons: iframeActionButtons,
                onRetry: retry,
                onSecondary: closePlayer
            )

        case .loaded:
            if store.selectedSource == nil {
                if store.hasIframeOnlySources {
                    FeatureStateOverlay(
                        descriptor: .failure(
                            title: "Không có nguồn phát trực tiếp",
                            message: "Nguồn này chỉ có iframe. Chọn một nguồn bên dưới để mở trong WebView.",
                            errorCode: "PLAYER_IFRAME_ONLY",
                            icon: .playback,
                            secondaryTitle: "Quay lại"
                        ),
                        actionButtons: iframeActionButtons,
                        onRetry: retry,
                        onSecondary: closePlayer
                    )
                } else {
                    FeatureStateOverlay(
                        descriptor: .empty(
                            title: "Chưa có nguồn phát",
                            message: "Không tìm thấy nguồn phát khả dụng cho tập này. Bạn có thể quay lại hoặc thử tải lại.",
                            errorCode: "PLAYER_NO_SOURCE",
                            icon: .playback,
                            secondaryTitle: "Quay lại"
                        ),
                        onRetry: retry,
                        onSecondary: closePlayer
                    )
                }
            }
        }
    }

    private var iframeActionButtons: [ErrorOverlay.ActionButton] {
        store.iframeSources.compactMap { source in
            guard let url = normalizedPlayerURL(from: source.link) else { return nil }

            return ErrorOverlay.ActionButton(title: source.actionButtonTitle) {
                webDestination = PlayerWebDestination(
                    title: source.actionButtonTitle,
                    url: url
                )
            }
        }
    }

    private func retry() {
        store.send(.retryTapped)
    }

    private func closePlayer() {
        store.send(.backButtonTapped)
    }

    private func handleSeekGesture(at positionX: CGFloat, width: CGFloat) {
        guard width > 0 else { return }

        if positionX < width / 3 {
            store.send(.seek(deltaMillis: -store.seekStepMillis))
        } else if positionX > width * 0.75 {
            store.send(.seek(deltaMillis: store.seekStepMillis))
        }
    }
}

private struct PlayerWebDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private func normalizedPlayerURL(from rawValue: String) -> URL? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let directURL = URL(string: trimmed), let scheme = directURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
        return directURL
    }

    if trimmed.hasPrefix("//"), let protocolRelativeURL = URL(string: "https:\(trimmed)") {
        return protocolRelativeURL
    }

    if let inferredURL = URL(string: "https://\(trimmed)") {
        return inferredURL
    }

    return nil
}

private struct PlayerWebViewScreen: View {
    let destination: PlayerWebDestination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlayerWebView(url: destination.url)
            .ignoresSafeArea()
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
    }
}

#Preview("Player") {
    NavigationStack {
        PlayerView(
            store: Store(initialState: PlayerFeature.State.previewLoaded()) {
                PlayerFeature()
            }
        )
    }
    .preferredColorScheme(.dark)
}
