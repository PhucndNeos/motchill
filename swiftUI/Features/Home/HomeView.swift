import ComposableArchitecture
import SwiftUI

/// The main view for the Home feature, serving as the entry point for the Home tab.
/// It observes a `StoreOf<HomeFeature>` to render the UI state and dispatches user actions back to the store.
struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        HomeIpadScreen(store: store)
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .title) {
                    TabSegmentedView(
                        selectedItem: $store.selectedSection,
                        items: store.sections,
                        spacing: 4,
                        horizontalPadding: 8
                    ) { item, selected in
                        Text(item.title)
                            .font(AppTheme.sectionTitleFont.weight(.semibold))
                            .foregroundStyle(selected ? Color(hex: "FFB4AA") : AppTheme.textPrimary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.white.opacity(0.2) : Color.clear)
                            )
                    }
                    .frame(maxWidth: 500)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.searchTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Tìm kiếm")
                        }
                        .font(AppTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .task {
                await store.send(.onTask).finish()
            }
    }
}
