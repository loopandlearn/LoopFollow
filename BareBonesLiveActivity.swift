// BareBonesLiveActivity.swift
// Philippe Achkar
// 2026-03-06
//
// Extension target only.
// Replace the contents of your Widget Extension’s main file with this.

import ActivityKit
import SwiftUI
import WidgetKit

struct BareBonesLiveActivityWidget: Widget {
var body: some WidgetConfiguration {
ActivityConfiguration(for: BareBonesAttributes.self) { context in
// LOCK SCREEN
BareBonesLockScreenView(state: context.state)
} dynamicIsland: { context in
DynamicIsland {
DynamicIslandExpandedRegion(.center) {
Text(“Count: (context.state.counter)”)
.font(.headline)
.foregroundStyle(.white)
}
} compactLeading: {
Text(”(context.state.counter)”)
.font(.caption)
.foregroundStyle(.white)
} compactTrailing: {
Text(context.state.label)
.font(.caption)
.foregroundStyle(.white)
} minimal: {
Text(”(context.state.counter)”)
.font(.caption)
.foregroundStyle(.white)
}
}
}
}

// MARK: - Lock Screen View

private struct BareBonesLockScreenView: View {
let state: BareBonesAttributes.ContentState

```
var body: some View {
    VStack(spacing: 8) {
        Text("Counter: \(state.counter)")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)

        Text(state.label)
            .font(.system(size: 18, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
    }
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(Color.blue.opacity(0.8))
}


}