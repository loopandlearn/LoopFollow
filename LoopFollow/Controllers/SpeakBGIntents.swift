// LoopFollow
// SpeakBGIntents.swift

import AppIntents

struct EnableSpeakBGIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable BG Speech"
    static var description = IntentDescription("Turns on spoken glucose readings in LoopFollow.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        Storage.shared.speakBG.value = true
        return .result(dialog: "BG speech enabled.")
    }
}

struct DisableSpeakBGIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable BG Speech"
    static var description = IntentDescription("Turns off spoken glucose readings in LoopFollow.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        Storage.shared.speakBG.value = false
        return .result(dialog: "BG speech disabled.")
    }
}
