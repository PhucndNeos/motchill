import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    let router: AppRouter
    private let shouldLoadOnAppear: Bool

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
        HomeScreen(
            viewModel: viewModel,
            router: router
        )
        .task {
            guard shouldLoadOnAppear else {
                return
            }

            await viewModel.load()
        }
    }
}
