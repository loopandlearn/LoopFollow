// LoopFollow
// NavigationRouter.swift

import SwiftUI

enum DeepLinkDestination: Hashable {
    case bolus, meal, override, tempTarget
}

class NavigationRouter: ObservableObject {
    /// 0 = ContentView (BG display), 1 = RemoteControlView, 2 = StatsView
    @Published var activeTab: Int = 0

    /// The currently presented (or about-to-be-presented) destination inside RemoteControlView's NavigationStack.
    /// Setting this to a non-nil value pushes the corresponding screen; setting it to nil pops back to the grid.
    @Published var activeDestination: DeepLinkDestination?

    /// Parse a deep link URL and navigate to the appropriate screen.
    /// URLs: loopfollow://open (main graph), loopfollow://bolus, loopfollow://meal, loopfollow://override, loopfollow://temptarget
    func handle(_ url: URL) {
        guard url.scheme == "loopfollow" else { return }

        // Clear any active navigation first
        activeDestination = nil

        switch url.host {
        case "bolus": navigateTo(.bolus)
        case "meal": navigateTo(.meal)
        case "override": navigateTo(.override)
        case "temptarget": navigateTo(.tempTarget)
        default:
            // "open" or unknown — stay on main graph (tab 0)
            activeTab = 0
        }
    }

    /// Switch to the Remote tab, then push the destination after a brief delay
    /// so the tab switch can settle before the NavigationStack push fires.
    private func navigateTo(_ dest: DeepLinkDestination) {
        activeTab = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.activeDestination = dest
        }
    }
}
