// LoopFollow
// OnboardingContainerView.swift

import SwiftUI

/// Root of the first-run onboarding wizard. Owns the shared chrome — progress
/// bar and Back/Next footer — and swaps in the view for the current step.
struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(onClose: onClose))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.step.showsProgressHeader {
                header
            }

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.step.usesSharedFooter {
                footer
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                OnboardingProgressBar(progress: viewModel.progress)
                Button("Skip") { viewModel.skip() }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !viewModel.progressLabel.isEmpty {
                Text(viewModel.progressLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var stepContent: some View {
        let content = Group {
            switch viewModel.step {
            case .welcome:
                WelcomeStepView(viewModel: viewModel)
            case .overview:
                OverviewStepView(onboarding: viewModel)
            case .dataSource:
                DataSourceChoiceStepView(viewModel: viewModel)
            case .connect:
                switch viewModel.dataSource {
                case .dexcom:
                    DexcomConnectStepView(viewModel: viewModel.dexcomViewModel, onboarding: viewModel)
                case .copyFromPhone:
                    ConnectImportStepView(viewModel: viewModel)
                default:
                    NightscoutConnectStepView(viewModel: viewModel.nightscoutViewModel, onboarding: viewModel)
                }
            case .units:
                UnitsStepView(onboarding: viewModel)
            case .generalAlarms:
                GeneralAlarmsStepView()
            case .alarms:
                AlarmsStepView(viewModel: viewModel)
            case .tabOrder:
                TabOrderStepView()
            case .notifications:
                NotificationsStepView(viewModel: viewModel)
            case .telemetry:
                TelemetryStepView(viewModel: viewModel)
            case .completion:
                CompletionStepView(viewModel: viewModel)
            }
        }

        if reduceMotion {
            content.id(viewModel.step)
        } else {
            content
                .id(viewModel.step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    private var footer: some View {
        OnboardingNavFooter(
            continueEnabled: viewModel.canProceed,
            showBack: viewModel.canGoBack,
            onBack: { withStepAnimation { viewModel.goBack() } },
            onContinue: { withStepAnimation { viewModel.advance() } }
        )
    }

    private func withStepAnimation(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { change() }
        }
    }
}

/// Thin segmented progress indicator shown at the top of each chrome'd step.
private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}
