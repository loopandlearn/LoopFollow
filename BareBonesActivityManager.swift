// BareBonesActivityManager.swift
// Philippe Achkar
// 2026-03-06
//
// Main app target only.
// Manages a bare-bones Live Activity with a simple counter.
// No storage layer. No snapshot builder. No threshold logic.
// Pure ActivityKit smoke test.

import ActivityKit
import UIKit
import Foundation

@available(iOS 16.1, *)
final class BareBonesActivityManager {

static let shared = BareBonesActivityManager()
private init() {}

private(set) var current: Activity<BareBonesAttributes>?
private var counter: Int = 0

// MARK: - Start

func startIfNeeded() {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("[BB-LA] Activities not authorized")
        return
    }

    // Reuse existing if present
    if let existing = Activity<BareBonesAttributes>.activities.first {
        current = existing
        print("[BB-LA] Reused existing activity id=\(existing.id)")
        return
    }

    do {
        let attributes = BareBonesAttributes(name: "LoopFollow Test")
        let initialState = BareBonesAttributes.ContentState(
            counter: 0,
            label: "Started at \(formattedTime())"
        )
        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(15 * 60),
            relevanceScore: 100.0
        )
        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        current = activity
        print("[BB-LA] Started id=\(activity.id)")
    } catch {
        print("[BB-LA] Failed to start: \(error)")
    }
}

// MARK: - Update

/// Call this from wherever LoopFollow fires a refresh.
/// Each call increments the counter and updates the label.
func update() {
    if current == nil, let existing = Activity<BareBonesAttributes>.activities.first {
        current = existing
        print("[BB-LA] Rebound to existing id=\(existing.id)")
    }

    guard let activity = current else {
        print("[BB-LA] Update skipped — no activity")
        return
    }

    counter += 1
    let nextCounter = counter
    let label = "Updated at \(formattedTime())"

    Task {
        let state = BareBonesAttributes.ContentState(
            counter: nextCounter,
            label: label
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60),
            relevanceScore: 100.0
        )

        var bgTask = UIBackgroundTaskIdentifier.invalid
        bgTask = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "BB-LA-update-\(nextCounter)") {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }

        await activity.update(content)

        await MainActor.run {
            UIApplication.shared.endBackgroundTask(bgTask)
        }

        print("[BB-LA] Updated id=\(activity.id) counter=\(nextCounter) label=\(label)")
    }
}

// MARK: - End

func end() {
    guard let activity = current else { return }
    Task {
        await activity.end(dismissalPolicy: .default)
        print("[BB-LA] Ended id=\(activity.id)")
        current = nil
    }
}

// MARK: - Helpers

private func formattedTime() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
}


}