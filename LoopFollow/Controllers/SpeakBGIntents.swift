// LoopFollow
// SpeakBGIntents.swift

import AppIntents

struct EnableSpeakBGIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn On Speak BG"
    static var description = IntentDescription("Turns on Speak BG so LoopFollow reads glucose values aloud.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try SpeakBGIntentSupport.set(true)
        return .result(dialog: "Speak BG is now on.")
    }
}

struct DisableSpeakBGIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Off Speak BG"
    static var description = IntentDescription("Turns off Speak BG so LoopFollow stops reading glucose values aloud.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try SpeakBGIntentSupport.set(false)
        return .result(dialog: "Speak BG is now off.")
    }
}

enum SpeakBGIntentSupport {
    /// Storage writes are memory-only during a suspected before-first-unlock
    /// launch, so the change would be lost on hydration.
    @MainActor
    static func set(_ enabled: Bool) throws {
        guard !StorageReadiness.isSuppressingWrites else {
            throw SpeakBGIntentError.storageUnavailable
        }
        Storage.shared.speakBG.value = enabled
    }
}

enum SpeakBGIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storageUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storageUnavailable:
            return "LoopFollow can't change Speak BG until your iPhone has been unlocked once after restarting."
        }
    }
}
