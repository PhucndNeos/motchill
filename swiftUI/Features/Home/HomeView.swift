import SwiftUI
import UIKit

struct HomeView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let initialViewModel: HomeViewModel?
    private let shouldLoadOnAppear: Bool

    init(
        repository: PhucTvRepository,
        router: AppRouter
    ) {
        self.router = router
        self.initialViewModel = HomeViewModel(repository: repository)
        self.shouldLoadOnAppear = true
    }

    init(
        viewModel: HomeViewModel,
        router: AppRouter
    ) {
        self.router = router
        self.initialViewModel = viewModel
        self.shouldLoadOnAppear = false
    }

    var body: some View {
        HomeRootView(
            viewModel: initialViewModel ?? HomeViewModel(repository: dependencies.repository),
            router: router,
            shouldLoadOnAppear: shouldLoadOnAppear
        )
    }
}

private struct HomeRootView: View {
    let router: AppRouter

    @State private var viewModel: HomeViewModel
    @State private var shouldLoadOnAppear: Bool

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init(
        viewModel: HomeViewModel,
        router: AppRouter,
        shouldLoadOnAppear: Bool
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        _shouldLoadOnAppear = State(initialValue: shouldLoadOnAppear)
    }

    var body: some View {
        content
        .toolbar {
            titleToolbar
            searchToolbar
        }
        .task {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if isPad {
                HomeIpadScreen(
                    viewModel: viewModel,
                    router: router
                )
                .ignoresSafeArea()
            } else {
                HomeScreen(
                    viewModel: viewModel,
                    router: router
                )
            }
        }
    }

    private var titleToolbar: ToolbarItem<(), some View> {
        ToolbarItem(placement: .title) {
            TabSegmentedView(
                selectedItem: $viewModel.selectedSection,
                items: viewModel.sections,
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
    }

    private var searchToolbar: ToolbarItem<(), some View> {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: openSearch) {
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

    private func openSearch() {
        router.push(.search())
    }

    private func loadIfNeeded() async {
        guard shouldLoadOnAppear else {
            return
        }

        await viewModel.load()
        shouldLoadOnAppear = false
    }
}
