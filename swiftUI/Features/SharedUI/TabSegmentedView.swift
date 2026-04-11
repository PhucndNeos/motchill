//
//  TabSegmentedView.swift
//  MotchillSwiftUI
//
//  Created by Phucnd on 11/4/26.
//  Copyright © 2026 Motchill. All rights reserved.
//

import SwiftUI

struct TabSegmentedView<Item, Content>: View where Item: Identifiable, Item.ID: Hashable, Content: View {
    @Binding var selectedItem: Item?
    let items: [Item]
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let itemContent: (Item, Bool) -> Content

    init(
        selectedItem: Binding<Item?>,
        items: [Item],
        spacing: CGFloat = 10,
        horizontalPadding: CGFloat = 16,
        @ViewBuilder itemContent: @escaping (Item, Bool) -> Content
    ) {
        self._selectedItem = selectedItem
        self.items = items
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.itemContent = itemContent
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isSelected = selectedItem?.id == item.id

                    Button {
                        selectedItem = item
                    } label: {
                        itemContent(item, isSelected)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .zIndex(isSelected ? 1 : Double(index))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}
