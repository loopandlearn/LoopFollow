// LoopFollow
// TabCustomizationModal.swift

import SwiftUI

// Represents either a TabItem or Settings in the drag-and-drop list
enum TabCustomizationItem: Identifiable, Equatable, Hashable {
    case tabItem(TabItem)
    case settings

    var id: String {
        switch self {
        case let .tabItem(item): return item.rawValue
        case .settings: return "settings"
        }
    }

    var displayName: String {
        switch self {
        case let .tabItem(item): return item.displayName
        case .settings: return "Menu"
        }
    }

    var icon: String {
        switch self {
        case let .tabItem(item): return item.icon
        case .settings: return "line.3.horizontal"
        }
    }
}

struct TabCustomizationModal: View {
    @Binding var isPresented: Bool
    let onApply: () -> Void

    // All items including Settings - top 4 go to tab bar, rest to menu
    @State private var allItems: [TabCustomizationItem]
    private let originalItems: [TabCustomizationItem]

    init(isPresented: Binding<Bool>, onApply: @escaping () -> Void) {
        _isPresented = isPresented
        self.onApply = onApply

        let sortedTabItems = TabItem.movableItems.sorted { item1, item2 in
            let pos1 = Storage.shared.position(for: item1).normalized
            let pos2 = Storage.shared.position(for: item2).normalized

            let isInTabBar1 = TabPosition.customizablePositions.contains(pos1)
            let isInTabBar2 = TabPosition.customizablePositions.contains(pos2)

            // Tab bar positions (1-4) come before menu
            if isInTabBar1, isInTabBar2 {
                return (pos1.tabIndex ?? 99) < (pos2.tabIndex ?? 99)
            } else if isInTabBar1 {
                return true // pos1 is in tab bar, pos2 is in menu
            } else if isInTabBar2 {
                return false // pos2 is in tab bar, pos1 is in menu
            } else {
                // Both in menu - maintain original order from movableItems
                let idx1 = TabItem.movableItems.firstIndex(of: item1) ?? 0
                let idx2 = TabItem.movableItems.firstIndex(of: item2) ?? 0
                return idx1 < idx2
            }
        }

        // Convert to TabCustomizationItem array and add Settings at the start of menu items
        var items: [TabCustomizationItem] = sortedTabItems.map { .tabItem($0) }

        // Find where menu items start (after position 4)
        let menuStartIndex = items.firstIndex { item in
            if case let .tabItem(tabItem) = item {
                let pos = Storage.shared.position(for: tabItem).normalized
                return !TabPosition.customizablePositions.contains(pos)
            }
            return false
        } ?? items.count

        // Insert Settings at the start of menu items
        items.insert(.settings, at: menuStartIndex)

        _allItems = State(initialValue: items)
        originalItems = items
    }

    var body: some View {
        NavigationStack {
            List {
                // Instructions
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drag to reorder")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("The top 4 items appear in the tab bar. Items 5+ appear in the Menu.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // All items - Settings appears at position 5 as a divider
                Section {
                    // Build display list: first 4 TabItems, then Settings, then remaining TabItems
                    let tabItems = allItems.compactMap { item -> TabItem? in
                        if case let .tabItem(tabItem) = item { return tabItem }
                        return nil
                    }

                    // Display items in order: tab bar items, Settings, menu items
                    ForEach(Array(allItems.enumerated()), id: \.element) { _, item in
                        switch item {
                        case let .tabItem(tabItem):
                            // Determine if this TabItem is in tab bar or menu
                            let tabItemIndex = tabItems.firstIndex(of: tabItem) ?? 0
                            let isInTabBar = tabItemIndex < 4

                            TabItemRow(
                                item : tabItem,
                                position: isInTabBar ? tabItemIndex + 1: nil,
                                isInMenu: !isInTabBar
                            )
                        case .settings:
                            SettingsRow()
                                .moveDisabled(true)
                        }
                    }
                    .onMove { source, destination in
                        // Check if Settings (at index 4) is being moved - prevent it
                        if source.contains(4) {
                            return
                        }

                        // Get all TabItems (excluding Settings)
                        var tabItemsOnly: [TabItem] = allItems.compactMap { item -> TabItem? in
                            if case let .tabItem(tabItem) = item { return tabItem }
                            return nil
                        }

                        // Adjust source indices: if any are after Settings (index 4), subtract 1
                        var adjustedSource = source
                        if source.contains(where: { $0 > 4 }) {
                            adjustedSource = IndexSet(source.map { $0 > 4 ? $0 - 1 : $0 })
                        }

                        // Adjust destination: if it's after Settings (position 5), subtract 1
                        let adjustedDestination = destination > 4 ? destination - 1 : destination

                        // Move TabItems
                        tabItemsOnly.move(fromOffsets: adjustedSource, toOffset: adjustedDestination)

                        // Rebuild allItems with Settings at position 5
                        var newItems: [TabCustomizationItem] = []
                        for (index, tabItem) in tabItemsOnly.enumerated() {
                            newItems.append(.tabItem(tabItem))
                            // Insert Settings after the 4th TabItem (at position 5)
                            if index == 3 {
                                newItems.append(.settings)
                            }
                        }

                        // If there are fewer than 4 TabItems, add Settings after the last one
                        if tabItemsOnly.count < 4 {
                            newItems.append(.settings)
                        }

                        allItems = newItems
                    }
                } header: {
                    Text("Tab Order")
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Tab Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .onDisappear {
                if allItems != originalItems {
                    applyChangesSilently()
                }
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }

    // MARK: - Actions

    private func applyChangesSilently() {
        // Count only TabItems (not Settings) to determine tab bar positions
        // First 4 TabItems go to tab bar, rest go to menu
        var tabItemCount = 0
        for item in allItems {
            switch item {
            case let .tabItem(tabItem):
                let position: TabPosition
                if tabItemCount < 4 {
                    switch tabItemCount {
                    case 0: position = .position1
                    case 1: position = .position2
                    case 2: position = .position3
                    case 3: position = .position4
                    default: position = .menu
                    }
                } else {
                    position = .menu
                }
                Storage.shared.setPosition(position, for: tabItem)
                tabItemCount += 1
            case .settings:
                break
            }
        }
        // Don't call onApply() - let the tab position observers handle the rebuild naturally
    }
}

// MARK: - Row Views

struct SettingsRow: View {
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .frame(width: 28)
                .foregroundColor(.secondary)
            Text("Menu")
                .foregroundColor(.secondary)
            Spacer()
            Text("Tab 5")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
    }
}

struct TabItemRow: View {
    let item: TabItem
    let position: Int?
    let isInMenu: Bool

    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .frame(width: 28)
                .foregroundColor(isInMenu ? .secondary : .accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .foregroundColor(isInMenu ? .secondary : .primary)
            }

            Spacer()

            if let pos = position {
                Text("Tab \(pos)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(4)
            } else {
                Text("In Menu")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
    }
}
