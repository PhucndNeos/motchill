import SwiftUI

struct FeaturePagingView<Item, Content>: View where Item: Identifiable, Item.ID: Hashable, Content: View {
    @Binding var selectedItem: Item?
    let items: [Item]
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let onSelectionChanged: ((Item.ID?) -> Void)?
    let content: (Item) -> Content

    init(
        selectedItem: Binding<Item?>,
        items: [Item],
        spacing: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        onSelectionChanged: ((Item.ID?) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._selectedItem = selectedItem
        self.items = items
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.onSelectionChanged = onSelectionChanged
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let pageWidth = max(proxy.size.width - (horizontalPadding * 2), 1)
            let selectedID = Binding<Item.ID?>(
                get: { selectedItem?.id },
                set: { newValue in
                    selectedItem = items.first(where: { $0.id == newValue })
                }
            )

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
            .scrollPosition(id: selectedID)
            .onAppear {
                guard selectedItem == nil else { return }
                selectedItem = items.first
            }
            .onChange(of: selectedItem?.id) { _, newValue in
                onSelectionChanged?(newValue)
            }
        }
    }
}
