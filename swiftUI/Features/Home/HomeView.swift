import SwiftUI
import UIKit

struct HomeView: View {
    let router: AppRouter

    @Environment(\.appDependencies) private var dependencies

    private let initialViewModel: HomeViewModel?
    private let shouldLoadOnAppear: Bool
    @State private var viewModel: HomeViewModel?

    init(
        router: AppRouter
    ) {
        self.router = router
        self.initialViewModel = nil
        self.shouldLoadOnAppear = true
    }

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
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await bootstrapIfNeeded()
                    }
            }
        }
        .task {
            await bootstrapIfNeeded()
        }
    }

    @ViewBuilder
    private func content(viewModel: HomeViewModel) -> some View {
        HomeIpadScreen(
            viewModel: viewModel,
            router: router
        )
        .ignoresSafeArea()
        .toolbar {
            titleToolbar(viewModel: viewModel)
            searchToolbar
        }
        .task {
            guard shouldLoadOnAppear else {
                return
            }

            await viewModel.load()
        }
    }

    private func titleToolbar(viewModel: HomeViewModel) -> ToolbarItem<(), some View> {
        ToolbarItem(placement: .title) {
            TabSegmentedView(
                selectedItem: Binding(
                    get: { viewModel.selectedSection },
                    set: { viewModel.selectedSection = $0 }
                ),
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

    @MainActor
    private func bootstrapIfNeeded() async {
        guard viewModel == nil else {
            return
        }

        let resolvedViewModel = initialViewModel ?? HomeViewModel(repository: dependencies.repository)
        viewModel = resolvedViewModel
    }
}
