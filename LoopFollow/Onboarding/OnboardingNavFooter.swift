// LoopFollow
// OnboardingNavFooter.swift

import SwiftUI

/// The shared Back / Continue footer used both by the container's chrome and by
/// phases that manage their own internal pages (connect, alarms), so the controls
/// look and behave identically everywhere.
struct OnboardingNavFooter: View {
    var continueTitle: String = "Continue"
    var continueEnabled: Bool = true
    var showBack: Bool = true
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        HStack {
            if showBack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button(action: onContinue) {
                Text(continueTitle)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!continueEnabled)
        }
        .padding()
        .background(.bar)
    }
}
