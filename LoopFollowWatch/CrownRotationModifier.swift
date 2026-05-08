// LoopFollow
// CrownRotationModifier.swift

import SwiftUI

/// Conditionally applies `.focusable()` and `.digitalCrownRotation()` together,
/// avoiding the "Crown Sequencer was set up without a view property" warning
/// that occurs when `.digitalCrownRotation()` is attached to a non-focusable view.
/// Automatically requests focus on appear so the crown works immediately.
struct CrownRotationModifier: ViewModifier {
    let isActive: Bool
    @Binding var value: Double
    let from: Double
    let through: Double
    let by: Double
    let sensitivity: DigitalCrownRotationalSensitivity
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
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
        } else {
            content
        }
    }
}
