// LoopFollow
// BGAnnouncement.swift

// Compiled into the app and into LoopFollowNotificationService: the app speaks it
// for Speak BG, the extension renders it for the hub's speech push.

import Foundation

/// The sentence Speak BG says for a new reading, in the chosen language.
enum BGAnnouncement {
    struct Texts {
        var stable: String
        var increase: String
        var decrease: String
        var currentBGIs: String

        static func forLanguage(_ language: String) -> Texts {
            switch language {
            case "fr":
                return Texts(
                    stable: "et c'est stable",
                    increase: "et c'est monté de",
                    decrease: "et c'est descendu de",
                    currentBGIs: "La glycémie est"
                )
            case "it":
                return Texts(
                    stable: "ed è stabile",
                    increase: "ed è salita di",
                    decrease: "ed è scesa di",
                    currentBGIs: "Glicemia attuale è"
                )
            case "sk":
                return Texts(
                    stable: "a je stabilná",
                    increase: "a stúpla o",
                    decrease: "a klesla o",
                    currentBGIs: "Aktuálna glykémia je"
                )
            case "sv":
                return Texts(
                    stable: "och det är stabilt",
                    increase: "och det har ökat med",
                    decrease: "och det har minskat med",
                    currentBGIs: "Blodsockret är"
                )
            case "en": fallthrough
            default:
                return Texts(
                    stable: "and it is stable",
                    increase: "and it is up",
                    decrease: "and it is down",
                    currentBGIs: "Glucose is"
                )
            }
        }
    }

    static let voiceLanguageMap: [String: String] = [
        "en": "en-US",
        "fr": "fr-FR",
        "it": "it-IT",
        "sk": "sk-SK",
        "sv": "sv-SE",
    ]

    static func voiceLanguageCode(forAppLanguage appLanguage: String) -> String {
        voiceLanguageMap[appLanguage, default: "en-US"]
    }

    /// A change of this many mg/dL or less is spoken as stable.
    static let negligibleChange = 3

    /// The announcement for `current` after `previous` (mg/dL), with values in the
    /// display unit and a period as the decimal mark, which every voice reads as one.
    static func text(current: Int, previous: Int, language: String, mmol: Bool,
                     locale: Locale = .current) -> String
    {
        let texts = Texts.forLanguage(language)
        let difference = current - previous
        let currentText = format(current, mmol: mmol, locale: locale)
        if abs(difference) <= negligibleChange {
            return "\(texts.currentBGIs) \(currentText) \(texts.stable)"
        }
        let direction = difference < 0 ? texts.decrease : texts.increase
        return "\(texts.currentBGIs) \(currentText) \(direction) \(format(abs(difference), mmol: mmol, locale: locale))"
    }

    static func format(_ mgdl: Int, mmol: Bool, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = mmol ? 1 : 0
        formatter.maximumFractionDigits = mmol ? 1 : 0
        let value = mmol ? Double(mgdl) * GlucoseConversion.mgDlToMmolL : Double(mgdl)
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)).replacingOccurrences(of: ",", with: ".")
    }
}
