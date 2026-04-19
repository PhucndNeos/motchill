import ComposableArchitecture
import SwiftUI

struct DetailView: View {
    @Bindable var store: StoreOf<DetailFeature>

    var body: some View {
        ZStack {
            if store.screenState == .loaded, store.hasRenderableContent {
                DetailsIpadScreen(store: store)
            } else {
                EmptyView()
            }

            stateOverlay
        }
        .background(
            DetailBackground(urlString: store.backDropURL)
                .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { store.send(.likeToggled) }) {
                    Image(systemName: store.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.isLiked ? Color.red.opacity(0.95) : AppTheme.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            (store.isLiked ? Color.red.opacity(0.18) : Color.white.opacity(0.06)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await store.send(.onAppear).finish()
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch store.screenState {
        case .idle, .loading:
            FeatureStateOverlay(
                descriptor: .loading(
                    title: "Đang tải nội dung",
                    message: "Chờ một lát để nạp thông tin chi tiết của phim.",
                    errorCode: "DETAIL_LOADING"
                ),
                onRetry: { store.send(.retryTapped) }
            )

        case .error(let message):
            FeatureStateOverlay(
                descriptor: .failure(
                    title: "Không thể tải chi tiết",
                    message: message,
                    errorCode: "DETAIL_LOAD_FAIL",
                    icon: .server,
                    secondaryTitle: "Quay lại"
                ),
                onRetry: { store.send(.retryTapped) },
                onSecondary: { store.send(.backButtonTapped) }
            )

        case .loaded:
            if !store.hasRenderableContent {
                FeatureStateOverlay(
                    descriptor: .empty(
                        title: "Chưa có nội dung",
                        message: "Trang chi tiết hiện chưa có section nào để hiển thị. Bạn có thể thử quay lại hoặc tìm kiếm nội dung khác.",
                        errorCode: "DETAIL_EMPTY",
                        secondaryTitle: "Tìm kiếm"
                    ),
                    onRetry: { store.send(.retryTapped) },
                    onSecondary: { store.send(.searchTapped) }
                )
            }
        }
    }
}

private struct DetailBackground: View {
    let urlString: String

    var body: some View {
        ZStack {
            RemoteImageView(url: backdropURL(urlString), cornerRadius: 0)
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
}

private func backdropURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
        return nil
    }

    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
        return nil
    }

    return url
}
