import SwiftUI

struct FeaturePagingView<Item, Content>: View where Item: Identifiable, Item.ID: Hashable, Content: View {
    @Binding var selectedID: Item.ID?
    let items: [Item]
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let onSelectionChanged: ((Item.ID?) -> Void)?
    let content: (Item) -> Content

    init(
        selectedID: Binding<Item.ID?>,
        items: [Item],
        spacing: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        onSelectionChanged: ((Item.ID?) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._selectedID = selectedID
        self.items = items
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.onSelectionChanged = onSelectionChanged
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let pageWidth = max(proxy.size.width - (horizontalPadding * 2), 1)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: pageWidth, height: proxy.size.height)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .contentMargins(.horizontal, horizontalPadding, for: .scrollContent)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedID)
            .onAppear {
                guard selectedID == nil else { return }
                selectedID = items.first?.id
            }
            .onChange(of: selectedID) { _, newValue in
                onSelectionChanged?(newValue)
            }
        }
    }
}
