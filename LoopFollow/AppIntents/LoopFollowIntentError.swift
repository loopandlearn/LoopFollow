// LoopFollow
// LoopFollowIntentError.swift

import AppIntents

enum LoopFollowIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storageUnavailable
    case noGlucoseData

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storageUnavailable:
            return "LoopFollow can't read its data until your iPhone has been unlocked once after restarting."
        case .noGlucoseData:
            return "LoopFollow has no glucose data yet. Open the app to check its setup."
        }
    }
}
