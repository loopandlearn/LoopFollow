// LoopFollow
// CrownCaptureView.swift

import SwiftUI

/// An invisible view that captures Digital Crown input without interfering
/// with the parent ScrollView. When this view is present (via overlay),
/// it grabs focus and routes crown rotation to the provided binding.
/// When removed from the hierarchy, the ScrollView regains crown control.
struct CrownCaptureView: View {
    @Binding var value: Double
    let from: Double
    let through: Double
    let by: Double
    let sensitivity: DigitalCrownRotationalSensitivity
    @FocusState private var isFocused: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .focusable()
            .focused($isFocused)
            .digitalCrownRotation(
                $value,
                from: from,
                through: through,
                by: by,
                sensitivity: sensitivity,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onAppear { isFocused = true }
    }
}
