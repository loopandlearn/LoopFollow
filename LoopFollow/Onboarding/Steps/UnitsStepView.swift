// LoopFollow
// UnitsStepView.swift

import SwiftUI

/// The units phase, split into two lighter pages so it doesn't feel heavy:
/// 1. **Units** — the glucose display unit on its own.
/// 2. **Statistics** — range mode and the glycemic/variability metrics LoopFollow
///    shows.
///
/// Both pages reuse `UnitsConfigurationView`, each rendering only its subset of
/// sections. The phase reports its within-phase position through
/// `phaseProgress` so the progress bar fills smoothly across the two pages.
struct UnitsStepView: View {
    @ObservedObject var onboarding: OnboardingViewModel

    private enum Page: Int, CaseIterable { case units, statistics }
    @State private var page: Page = .units

    var body: some View {
        VStack(spacing: 0) {
            Form {
                switch page {
                case .units:
                    header(
                        systemImage: "ruler",
                        title: "Units",
                        subtitle: "Choose how glucose values are displayed. You can change this later in Settings."
                    )
                    UnitsConfigurationView(sections: .units)
                case .statistics:
                    header(
                        systemImage: "chart.bar.xaxis",
                        title: "Statistics",
                        subtitle: "Choose how LoopFollow's statistics are measured and displayed."
                    )
                    UnitsConfigurationView(sections: .statistics)
                }
            }

            footer
        }
        .onAppear { reportProgress() }
        .onChange(of: page) { _ in reportProgress() }
    }

    private func reportProgress() {
        onboarding.phaseProgress = .init(page: page.rawValue, count: Page.allCases.count)
    }

    private func header(systemImage: String, title: String, subtitle: String) -> some View {
        Section {
            EmptyView()
        } header: {
            OnboardingStepHeader(
                systemImage: systemImage,
                title: title,
                subtitle: subtitle
            )
            .textCase(nil)
            .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var footer: some View {
        switch page {
        case .units:
            OnboardingNavFooter(
                continueEnabled: true,
                showBack: onboarding.canGoBack,
                onBack: { onboarding.goBack() },
                onContinue: { withAnimation(.easeInOut(duration: 0.25)) { page = .statistics } }
            )
        case .statistics:
            OnboardingNavFooter(
                continueEnabled: true,
                showBack: true,
                onBack: { withAnimation(.easeInOut(duration: 0.25)) { page = .units } },
                onContinue: { onboarding.advance() }
            )
        }
    }
}
