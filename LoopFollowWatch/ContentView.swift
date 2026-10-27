// LoopFollow
// ContentView.swift

import SwiftUI

/// Screens pushed on the main navigation stack.
enum WatchRoute: Hashable {
    case chartScrub
    case treatments
    case meal
    case bolus
    case bolusAmount
    case overrides
    case tempTargets
    case confirm(CommandRequest)
}

/// What a confirmation screen sends, and how it describes it.
struct CommandRequest: Hashable {
    let title: String
    let lines: [String]
    let action: WatchCommand.Action
    let deliversInsulin: Bool
}

/// Owns the navigation path so a finished command can return to the glucose page.
final class WatchNavigator: ObservableObject {
    @Published var path: [WatchRoute] = []

    func push(_ route: WatchRoute) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }
}

struct ContentView: View {
    @EnvironmentObject private var session: WatchSession
    @StateObject private var navigator = WatchNavigator()

    var body: some View {
        NavigationStack(path: $navigator.path) {
            if let state = session.state {
                TabView {
                    GlucosePage(state: state)
                    ChartPage(state: state)
                    if let stats = state.stats {
                        StatsPage(state: state, stats: stats)
                    }
                    InfoPage(state: state)
                }
                .tabViewStyle(.verticalPage)
                .navigationDestination(for: WatchRoute.self) { route in
                    destination(route, state: state)
                }
            } else {
                WaitingForPhoneView()
            }
        }
        .environmentObject(navigator)
    }

    @ViewBuilder
    private func destination(_ route: WatchRoute, state: WatchState) -> some View {
        if route == .chartScrub {
            ChartScrubView(state: state)
        } else if let remote = state.remote {
            switch route {
            case .chartScrub:
                EmptyView()
            case .treatments:
                TreatmentMenuView()
            case .meal:
                MealEntryView(remote: remote)
            case .bolus:
                BolusPickerView(remote: remote)
            case .bolusAmount:
                BolusAmountView(remote: remote)
            case .overrides:
                PresetListView(kind: .override, state: state, presets: remote.overridePresets)
            case .tempTargets:
                PresetListView(kind: .tempTarget, state: state, presets: remote.tempTargetPresets)
            case let .confirm(request):
                CommandConfirmView(request: request)
            }
        } else {
            Text("Remote commands are turned off in LoopFollow on the iPhone.")
                .multilineTextAlignment(.center)
        }
    }
}

private struct WaitingForPhoneView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Waiting for LoopFollow on iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Open LoopFollow on the paired iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
