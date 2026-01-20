// LoopFollow
// CalendarSettingsView.swift

import EventKit
import SwiftUI

struct CalendarSettingsView: View {
    // MARK: Storage bindings

    @ObservedObject private var writeCalendarEvent = Storage.shared.writeCalendarEvent
    @ObservedObject private var calendarIdentifier = Storage.shared.calendarIdentifier
    @ObservedObject private var watchLine1 = Storage.shared.watchLine1
    @ObservedObject private var watchLine2 = Storage.shared.watchLine2

    // MARK: Local state

    @State private var calendars: [EKCalendar] = []
    @State private var accessDenied = false

    // MARK: Body

    var body: some View {
        Form {
            // ------------- Calendar write -------------
            Section {
                Toggle("Save BG to Calendar",
                       isOn: $writeCalendarEvent.value)
                    .disabled(accessDenied) // prevent use when no access
            } footer: {
                Text("""
                Add the Apple-Calendar complication to your watch or CarPlay \
                to see BG readings. Create a separate calendar (e.g. “Follow”) \
                — this view will **delete** events on the same calendar each time \
                it writes new readings.
                """)
            }

            // ------------- Access / calendar picker -------------
            if accessDenied {
                Text("Calendar access denied")
                    .foregroundColor(.red)
            } else {
                if !calendars.isEmpty {
                    Picker("Calendar",
                           selection: $calendarIdentifier.value)
                    {
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            Text(cal.title).tag(cal.calendarIdentifier)
                        }
                    }
                }
            }

            // ------------- Template lines -------------
            Section("Calendar Text") {
                TextField("Line 1", text: $watchLine1.value)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                TextField("Line 2", text: $watchLine2.value)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            // ------------- Variable cheat-sheet -------------
            Section("Available Variables") {
                ForEach(variableDescriptions, id: \.self) { desc in
                    Text(desc)
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Calendar", displayMode: .inline)
        .task { // runs once on appear
            await requestCalendarAccessAndLoad()
        }
    }

    // MARK: - Helpers

    /// Returns array of “%TOKEN% : Explanation” strings used in the cheat-sheet.
    private var variableDescriptions: [String] {
        [
            "%BG% : Blood-glucose reading",
            "%DIRECTION% : Dexcom trend arrow",
            "%DELTA% : Difference from last reading",
            "%IOB% : Insulin-on-Board",
            "%COB% : Carbs-on-Board",
            "%BASAL% : Current basal U/h",
            "%LOOP% : Loop status symbol",
            "%OVERRIDE% : Active override %",
            "%MINAGO% : Minutes since last reading",
        ]
    }

    /// Ask for calendar permission, then pull the user’s calendars.
    private func requestCalendarAccessAndLoad() async {
        let store = EKEventStore()
        do {
            try await store.requestAccess(to: .event)
            accessDenied = false
            calendars = store.calendars(for: .event)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            accessDenied = true
        }

        // If the previously-saved calendar no longer exists, blank it out
        if !calendarIdentifier.value.isEmpty,
           !calendars.contains(where: { $0.calendarIdentifier == calendarIdentifier.value })
        {
            calendarIdentifier.value = ""
        }
    }
}
