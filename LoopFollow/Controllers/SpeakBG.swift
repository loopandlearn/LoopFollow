// LoopFollow
// SpeakBG.swift

import AVFoundation
import CallKit
import Foundation

extension MainViewController {
    func evaluateSpeakConditions(currentValue: Int, previousValue: Int) {
        // In LoopFollow Hub mode the hub speaks each reading through a notification.
        guard Storage.shared.speakBG.value, !HubClient.shared.drivesSpeech else {
            return
        }

        let always = Storage.shared.speakBGAlways.value
        let lowThreshold = Storage.shared.speakLowBGLimit.value
        let fastDropDelta = Storage.shared.speakFastDropDelta.value
        let highThreshold = Storage.shared.speakHighBGLimit.value
        let speakLowBG = Storage.shared.speakLowBG.value
        let speakProactiveLowBG = Storage.shared.speakProactiveLowBG.value
        let speakHighBG = Storage.shared.speakHighBG.value

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
            let predictiveTrigger = !predictionData.isEmpty && Double(predictionData.first!.sgv) <= lowThreshold

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

    // Speaks the current blood glucose value and the change from the previous value.
    func speakBG(currentValue: Int, previousValue: Int) {
        // 1. Check if there's a new, unspoken BG value
        guard let lastBG = bgData.last else {
            // No data, so nothing to speak.
            return
        }

        // Compare the timestamp of the latest BG reading with the last one we spoke.
        guard lastBG.date > lastSpokenBGDate else {
            // The latest value has already been spoken, so we do nothing.
            return
        }

        // 2. Now that we know we need to speak, activate the audio session.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            LogManager.shared.log(category: .general, message: "speakBG, Failed to set up audio session: \(error)")
            return
        }

        // 3. Mark this BG value as spoken
        // This prevents race conditions where another call might try to speak the same value.
        lastSpokenBGDate = lastBG.date

        // 4. Generate announcement text.
        let preferredLanguage = Storage.shared.speakLanguage.value
        let voiceLanguageCode = BGAnnouncement.voiceLanguageCode(forAppLanguage: preferredLanguage)
        let announcementText = BGAnnouncement.text(current: currentValue, previous: previousValue,
                                                   language: preferredLanguage,
                                                   mmol: UnitSettingsStore.shared.glucoseUnit == .mmolL)

        // 5. Speak.
        let speechUtterance = AVSpeechUtterance(string: announcementText)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: voiceLanguageCode)
        speechSynthesizer.speak(speechUtterance)
    }
}
