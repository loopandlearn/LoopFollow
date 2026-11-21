// LoopFollow
// HubModeLimits.swift

import Foundation

/// In LoopFollow Hub mode the app sleeps, so a calendar event or a contact image
/// written by the app would go on showing an old reading. Neither is written in
/// Hub mode; the settings are kept for when the app leaves it.
enum HubModeLimits {
    static let calendarNote = "Not available in LoopFollow Hub mode, where the app sleeps and would show old readings."
    static let contactNote = "Not available in LoopFollow Hub mode, where the app sleeps and would show old readings."

    /// Hub mode was entered and its limits have been applied.
    static let applied = StorageValue<Bool>(key: "hubModeLimitsApplied", defaultValue: false)
}

extension MainViewController {
    /// Once per stay in Hub mode: removes the calendar's events and sets the contact
    /// images to show no value.
    func applyHubModeLimits() {
        guard HubClient.shared.isHubMode else {
            HubModeLimits.applied.value = false
            return
        }
        guard !HubModeLimits.applied.value else { return }
        HubModeLimits.applied.value = true

        if Storage.shared.writeCalendarEvent.value, !Storage.shared.calendarIdentifier.value.isEmpty {
            store.requestCalendarAccess { granted, _ in
                guard granted else { return }
                self.removeCalendarEvents()
                LogManager.shared.log(category: .calendar, message: "Hub mode: calendar events removed")
            }
        }
        if Storage.shared.contactEnabled.value {
            contactImageUpdater.updateContactImage(bgValue: "--", trend: "--", delta: "--", iob: "--", stale: true)
            LogManager.shared.log(category: .contact, message: "Hub mode: contact images show no value")
        }
    }
}
