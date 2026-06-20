// LoopFollow
// TabOrderStepView.swift

import SwiftUI

/// Lets the user arrange which features live in the tab bar versus the Menu,
/// during onboarding. Reuses the same drag-to-reorder list as the Settings
/// "Tabs" screen so behavior stays identical.
struct TabOrderStepView: View {
    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                systemImage: "square.grid.2x2",
                title: "Arrange your tabs",
                subtitle: "Pick which features sit in the tab bar. You can always reach everything through the Menu."
            )
            .padding(.horizontal)
            .padding(.top, 8)

            TabCustomizationModal()
        }
    }
}
