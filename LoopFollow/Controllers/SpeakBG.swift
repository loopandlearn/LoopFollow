import AVFoundation
import CallKit
import Foundation

extension MainViewController {
    func evaluateSpeakConditions(currentValue: Int, previousValue: Int) {
        if !UserDefaultsRepository.speakBG.value {
            return
        }

        let always = UserDefaultsRepository.speakBGAlways.value
        let lowThreshold = UserDefaultsRepository.speakLowBGLimit.value
        let fastDropDelta = UserDefaultsRepository.speakFastDropDelta.value
        let highThreshold = UserDefaultsRepository.speakHighBGLimit.value
        let speakLowBG = UserDefaultsRepository.speakLowBG.value
        let speakProactiveLowBG = UserDefaultsRepository.speakProactiveLowBG.value
        let speakHighBG = UserDefaultsRepository.speakHighBG.value

        // Speak always
        if always {
            speakBG(currentValue: currentValue, previousValue: previousValue)
            LogManager.shared.log(category: .general, message: "Speaking because 'Always' is enabled.", isDebug: true)

            return
        }

        // Speak if low or last value was low
        if speakLowBG {
            if currentValue <= Int(lowThreshold) || previousValue <= Int(lowThreshold) {
                speakBG(currentValue: currentValue, previousValue: previousValue)
                LogManager.shared.log(category: .general, message: "Speaking because of 'Low' condition.", isDebug: true)
                return
            }
        }

        // Speak predictive low if...
        // * low or last value was low
        // * next predictive value is low
        // * fast drop occurs below high
        if speakProactiveLowBG {
            let predictiveTrigger = !predictionData.isEmpty && Float(predictionData.first!.sgv) <= lowThreshold

            if predictiveTrigger ||
                currentValue <= Int(lowThreshold) || previousValue <= Int(lowThreshold) ||
                (currentValue <= Int(highThreshold) && (previousValue - currentValue) >= Int(fastDropDelta))
            {
                speakBG(currentValue: currentValue, previousValue: previousValue)
                LogManager.shared.log(category: .general, message: "Speaking because of 'Proactive Low' condition. Predictive trigger: \(predictiveTrigger)", isDebug: true)
                return
            }
        }

        // Speak if high or if last value was high
        if speakHighBG {
            if currentValue >= Int(highThreshold) || previousValue >= Int(highThreshold) {
                speakBG(currentValue: currentValue, previousValue: previousValue)
                LogManager.shared.log(category: .general, message: "Speaking because of 'High' condition.", isDebug: true)
                return
            }
        }

        LogManager.shared.log(category: .general, message: "No condition met for speaking.", isDebug: true)
    }

    struct AnnouncementTexts {
        var stable: String
        var increase: String
        var decrease: String
        var currentBGIs: String

        static func forLanguage(_ language: String) -> AnnouncementTexts {
            switch language {
            case "it":
                return AnnouncementTexts(
                    stable: "ed è stabile",
                    increase: "ed è salita di",
                    decrease: "ed è scesa di",
                    currentBGIs: "Glicemia attuale è"
                )
            case "sk":
                return AnnouncementTexts(
                    stable: "a je stabilná",
                    increase: "a stúpla o",
                    decrease: "a klesla o",
                    currentBGIs: "Aktuálna glykémia je"
                )
            case "sv":
                return AnnouncementTexts(
                    stable: "och det är stabilt",
                    increase: "och det har ökat med",
                    decrease: "och det har minskat med",
                    currentBGIs: "Blodsockret är"
                )
            case "en": fallthrough
            default:
                return AnnouncementTexts(
                    stable: "and it is stable",
                    increase: "and it is up",
                    decrease: "and it is down",
                    currentBGIs: "Glucose is"
                )
            }
        }
    }

    enum LanguageVoiceMapping {
        static let voiceLanguageMap: [String: String] = [
            "en": "en-US",
            "it": "it-IT",
            "sk": "sk-SK",
            "sv": "sv-SE",
        ]

        static func voiceLanguageCode(forAppLanguage appLanguage: String) -> String {
            return voiceLanguageMap[appLanguage, default: "en-US"]
        }
    }

    // Speaks the current blood glucose value and the change from the previous value.
    // Repeated calls to the function within 30 seconds are prevented.
    func speakBG(currentValue: Int, previousValue: Int) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            LogManager.shared.log(category: .alarm, message: "speakBG, Failed to set up audio session: \(error)")
        }

        // Get the current time
        let currentTime = Date()

        // Check if speakBG was called less than 30 seconds ago. If so, prevent repeated announcements and return.
        // If `lastSpeechTime` is `nil` (i.e., this is the first time `speakBG` is being called), use `Date.distantPast` as the default
        // value to ensure that the `guard` statement passes and the announcement is made.
        guard currentTime.timeIntervalSince(lastSpeechTime ?? .distantPast) >= 30 else {
            LogManager.shared.log(category: .general, message: "Repeated calls to speakBG detected!", isDebug: true)
            return
        }

        // Update the last speech time
        lastSpeechTime = currentTime

        let bloodGlucoseDifference = currentValue - previousValue

        let preferredLanguage = UserDefaultsRepository.speakLanguage.value
        let voiceLanguageCode = LanguageVoiceMapping.voiceLanguageCode(forAppLanguage: preferredLanguage)

        let texts = AnnouncementTexts.forLanguage(preferredLanguage)

        let negligibleThreshold = 3
        let localizedCurrentValue = Localizer.toDisplayUnits(String(currentValue)).replacingOccurrences(of: ",", with: ".")
        let announcementText: String

        if abs(bloodGlucoseDifference) <= negligibleThreshold {
            announcementText = "\(texts.currentBGIs) \(localizedCurrentValue) \(texts.stable)"
        } else {
            let directionText = bloodGlucoseDifference < 0 ? texts.decrease : texts.increase
            let absoluteDifference = Localizer.toDisplayUnits(String(abs(bloodGlucoseDifference))).replacingOccurrences(of: ",", with: ".")
            announcementText = "\(texts.currentBGIs) \(localizedCurrentValue) \(directionText) \(absoluteDifference)"
        }

        let speechUtterance = AVSpeechUtterance(string: announcementText)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: voiceLanguageCode)

        speechSynthesizer.speak(speechUtterance)
    }
}
