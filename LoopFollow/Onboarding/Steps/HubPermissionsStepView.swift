// LoopFollow
// HubPermissionsStepView.swift

import SwiftUI

/// After joining a family hub: the permissions LF Hub needs on this phone, in one place.
/// Continuing sets Background Refresh to LF Hub.
struct HubPermissionsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var laEnabled = Storage.shared.laEnabled
    @State private var notifications: HubChecklist.Permission?
    @State private var alarmKit = HubChecklist.alarmKitPermission

    private var items: [HubChecklist.Item] {
        var facts = HubChecklist.Facts()
        facts.notifications = notifications
        facts.alarmKit = alarmKit
        facts.liveActivityOn = laEnabled.value
        return HubChecklist.permissionItems(facts, liveActivity: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    EmptyView()
                } header: {
                    OnboardingStepHeader(
                        systemImage: "bell.badge.fill",
                        title: "Let LF Hub reach you",
                        subtitle: "LF Hub sends the alarms to this phone, rings them through silent mode, and keeps the Live Activity up to date."
                    )
                    .textCase(nil)
                    .padding(.bottom, 8)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    HubChecklistRows(items: items) { fix in
                        Task {
                            await HubChecklist.perform(fix)
                            await read()
                        }
                    }
                } footer: {
                    Text("Until LF Hub confirms it can send this phone's alarms, LoopFollow checks them itself. Settings → LF Hub shows what is still missing.")
                }
            }

            OnboardingNavFooter(
                showBack: viewModel.canGoBack,
                onBack: { viewModel.goBack() },
                onContinue: {
                    BackgroundRefreshSettingsViewModel.change(to: .hub)
                    viewModel.advance()
                }
            )
        }
        .task { await read() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await read() }
        }
    }

    private func read() async {
        notifications = await HubChecklist.notificationPermission()
        alarmKit = HubChecklist.alarmKitPermission
    }
}
