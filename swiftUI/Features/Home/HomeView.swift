import SwiftUI
import UIKit

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    let router: AppRouter
    private let shouldLoadOnAppear: Bool
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    init(
        repository: MotchillRepository,
        router: AppRouter
    ) {
        _viewModel = State(initialValue: HomeViewModel(repository: repository))
        self.router = router
        self.shouldLoadOnAppear = true
    }
    
    init(
        viewModel: HomeViewModel,
        router: AppRouter
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        self.shouldLoadOnAppear = false
    }
    
    var body: some View {
        Group {
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
        .toolbar {
            ToolbarItem(placement: .title) {
                TabSegmentedView(selectedItem: $viewModel.selectedSection,
                                 items: viewModel.sections,
                                 spacing: 4,
                                 horizontalPadding: 8) { item, selected in
                    Text(item.title)
                        .font(AppTheme.sectionTitleFont.weight(.semibold))
                        .foregroundStyle(selected ? Color.yellow : AppTheme.textPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(selected ? AppTheme.accent : Color.clear)
                        )
                }
                
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
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
            guard shouldLoadOnAppear else {
                return
            }
            
            await viewModel.load()
        }
    }
}
