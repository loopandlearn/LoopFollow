// LoopFollow
// TelemetryStepView.swift

import SwiftUI

/// In-flow telemetry consent. Mirrors `TelemetryConsentView` but records the
/// decision and continues the wizard instead of dismissing a sheet.
struct TelemetryStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Help us help you")
                    .font(.title2.weight(.bold))

                Text("You can choose to share anonymous information with the developers to help improve LoopFollow — such as app and iOS version, device type, which app you're following, and a few settings. Your health data, credentials, time zone, and logs remain on your device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                Button { showPreview = true } label: {
                    Label("See exactly what's sent", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                }

                Text("You can change this any time in Settings → General → Diagnostics.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button { decide(true) } label: {
                    Text("Yes, send anonymous stats")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button { decide(false) } label: {
                    Text("No thanks")
                        .font(.body.weight(.medium))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                TelemetryPreviewView()
            }
        }
    }

    private func decide(_ enabled: Bool) {
        Storage.shared.telemetryEnabled.value = enabled
        Storage.shared.telemetryConsentDecisionMade.value = true
        if enabled {
            // Fire the inaugural ping immediately, then start the 24h cadence.
            Task.detached {
                await TelemetryClient.shared.maybeSend()
                TelemetryClient.shared.scheduleRecurring()
            }
        }
        viewModel.advance()
    }
}
