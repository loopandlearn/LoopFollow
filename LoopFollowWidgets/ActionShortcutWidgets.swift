// LoopFollow
// ActionShortcutWidgets.swift

import SwiftUI
import WidgetKit

// MARK: - Shared Timeline (static, never changes)

struct ActionEntry: TimelineEntry {
    let date: Date
}

struct ActionTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> ActionEntry {
        ActionEntry(date: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping (ActionEntry) -> Void) {
        completion(ActionEntry(date: .now))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ActionEntry>) -> Void) {
        completion(Timeline(entries: [ActionEntry(date: .now)], policy: .never))
    }
}

// MARK: - Shared View

struct ActionShortcutView: View {
    let systemImage: String
    var color: Color = .primary

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .widgetAccentable()
        }
    }
}

// MARK: - Bolus Shortcut

struct BolusShortcutWidget: Widget {
    let kind = "BolusShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActionTimelineProvider()) { _ in
            ActionShortcutView(systemImage: "drop.fill", color: .blue)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "loopfollow://bolus"))
        }
        .configurationDisplayName("Bolus")
        .description("Quick access to bolus entry.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Meal Shortcut

struct MealShortcutWidget: Widget {
    let kind = "MealShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActionTimelineProvider()) { _ in
            ActionShortcutView(systemImage: "fork.knife", color: .yellow)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "loopfollow://meal"))
        }
        .configurationDisplayName("Meal")
        .description("Quick access to meal entry.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Override Shortcut

struct OverrideShortcutWidget: Widget {
    let kind = "OverrideShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActionTimelineProvider()) { _ in
            ActionShortcutView(systemImage: "bolt.fill", color: .purple)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "loopfollow://override"))
        }
        .configurationDisplayName("Override")
        .description("Quick access to override selection.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Temp Target Shortcut

struct TempTargetShortcutWidget: Widget {
    let kind = "TempTargetShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActionTimelineProvider()) { _ in
            ActionShortcutView(systemImage: "target", color: Color(red: 0.2, green: 0.9, blue: 0.1))
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "loopfollow://temptarget"))
        }
        .configurationDisplayName("Temp Target")
        .description("Quick access to temp target selection.")
        .supportedFamilies([.accessoryCircular])
    }
}
