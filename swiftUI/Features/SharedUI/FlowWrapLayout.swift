import Flow
import SwiftUI

struct FlowWrapLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    @ViewBuilder let content: (Data.Element) -> Content
    
    init(
        items: Data,
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.items = items
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }
    
    var body: some View {
        HFlow(itemSpacing: horizontalSpacing, rowSpacing: verticalSpacing) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}
