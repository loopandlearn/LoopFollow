// LoopFollow
// LoopFollowAppShortcuts.swift

#if !targetEnvironment(macCatalyst)
    import AppIntents

    /// Siri phrases. Apple allows at most ten App Shortcuts per app; the intents
    /// without an entry here are still available in the Shortcuts app.
    struct LoopFollowAppShortcuts: AppShortcutsProvider {
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: GetStatusIntent(),
                phrases: [
                    "What's the status in \(.applicationName)",
                    "Check \(.applicationName)",
                    "\(.applicationName) status",
                    "How are they doing in \(.applicationName)",
                ],
                shortTitle: "Get Status",
                systemImageName: "waveform.path.ecg"
            )
            AppShortcut(
                intent: GetGlucoseIntent(),
                phrases: [
                    "What's the glucose in \(.applicationName)",
                    "What's the blood sugar in \(.applicationName)",
                    "What's the BG in \(.applicationName)",
                ],
                shortTitle: "Get Glucose",
                systemImageName: "drop"
            )
            AppShortcut(
                intent: GetStatusItemIntent(),
                phrases: [
                    "What's the \(\.$item) in \(.applicationName)",
                    "Check the \(\.$item) in \(.applicationName)",
                ],
                shortTitle: "Get Status Item",
                systemImageName: "list.bullet"
            )
            AppShortcut(
                intent: SnoozeAllAlarmsIntent(),
                phrases: [
                    "Snooze all alarms in \(.applicationName)",
                    "Snooze all alarms in \(.applicationName) for \(\.$duration)",
                ],
                shortTitle: "Snooze All Alarms",
                systemImageName: "bell.slash"
            )
            AppShortcut(
                intent: EndSnoozeIntent(),
                phrases: [
                    "End snooze in \(.applicationName)",
                    "Resume alarms in \(.applicationName)",
                ],
                shortTitle: "End Snooze",
                systemImageName: "bell"
            )
            AppShortcut(
                intent: SnoozeCurrentAlarmIntent(),
                phrases: ["Snooze the alarm in \(.applicationName)"],
                shortTitle: "Snooze Current Alarm",
                systemImageName: "bell.badge.slash"
            )
            AppShortcut(
                intent: RestartLiveActivityIntent(),
                phrases: ["Restart Live Activity in \(.applicationName)"],
                shortTitle: "Restart Live Activity",
                systemImageName: "dot.radiowaves.left.and.right"
            )
            AppShortcut(
                intent: EnableSpeakBGIntent(),
                phrases: ["Turn on Speak BG in \(.applicationName)"],
                shortTitle: "Turn On Speak BG",
                systemImageName: "speaker.wave.2"
            )
            AppShortcut(
                intent: DisableSpeakBGIntent(),
                phrases: ["Turn off Speak BG in \(.applicationName)"],
                shortTitle: "Turn Off Speak BG",
                systemImageName: "speaker.slash"
            )
        }
    }
#endif
