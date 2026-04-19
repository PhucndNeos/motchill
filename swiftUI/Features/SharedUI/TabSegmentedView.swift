//
//  TabSegmentedView.swift
//  PhucTvSwiftUI
//
//  Created by Phucnd on 11/4/26.
//  Copyright © 2026 PhucTv. All rights reserved.
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        let isSelected = selectedItem?.id == item.id
                        
                        Button {
                            selectedItem = item
                        } label: {
                            itemContent(item, isSelected)
                        }
                        .id(item.id) // 👈 QUAN TRỌNG
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .scrollTargetLayout() // 👈 enable target
            }
            .onChange(of: selectedItem?.id) {
                withAnimation(.easeInOut) {
                    proxy.scrollTo(selectedItem?.id, anchor: .center)
                }
            }
        }
    }
}

struct IndexedTabSegmentedView<Item, Content>: View where Item: Identifiable, Item.ID: Hashable, Content: View {
    @Binding var selectedIndex: Int
    let items: [Item]
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let itemContent: (Item, Bool) -> Content

    init(
        selectedIndex: Binding<Int>,
        items: [Item],
        spacing: CGFloat = 10,
        horizontalPadding: CGFloat = 16,
        @ViewBuilder itemContent: @escaping (Item, Bool) -> Content
    ) {
        self._selectedIndex = selectedIndex
        self.items = items
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.itemContent = itemContent
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let isSelected = selectedIndex == index

                        Button {
                            selectedIndex = index
                        } label: {
                            itemContent(item, isSelected)
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .scrollTargetLayout()
            }
            .onChange(of: selectedIndex) {
                guard items.indices.contains(selectedIndex) else { return }
                withAnimation(.easeInOut) {
                    proxy.scrollTo(items[selectedIndex].id, anchor: .center)
                }
            }
        }
    }
}


extension Color {
    
    /// Helper initializer to create a Color from a hex string.
    /// - Parameter hex: A hex string representing the color. It can be in the format #RGB, #RRGGBB, or #AARRGGBB.
    /// Examples:
    /// Color(hex: "#FF6B00")   // orange chính
    /// Color(hex: "FFFFFF")    // white
    /// Color(hex: "#1A1A1A")   // dark bg
    /// Color(hex: "#80FF0000") // có alpha
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
            case 3: // RGB (12-bit) -> #RGB
                (a, r, g, b) = (
                    255,
                    (int >> 8) * 17,
                    (int >> 4 & 0xF) * 17,
                    (int & 0xF) * 17
                )
            case 6: // RGB (24-bit) -> #RRGGBB
                (a, r, g, b) = (
                    255,
                    int >> 16,
                    int >> 8 & 0xFF,
                    int & 0xFF
                )
            case 8: // ARGB (32-bit) -> #AARRGGBB
                (a, r, g, b) = (
                    int >> 24,
                    int >> 16 & 0xFF,
                    int >> 8 & 0xFF,
                    int & 0xFF
                )
            default:
                (a, r, g, b) = (255, 0, 0, 0) // fallback black
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
