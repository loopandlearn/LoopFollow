// LoopFollow
// SpeechOutput.swift

import AVFoundation
import Foundation

/// The speech synthesizer shared by spoken BG and the Speak BG quick action.
/// Speech ducks other audio, and the audio session is handed back through
/// AlarmSound.releaseAudioSession() when an utterance finishes.
final class SpeechOutput: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechOutput()

    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Activates the audio session with ducking of other audio.
    /// - Returns: False when the session could not be activated.
    func activateAudioSession() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(true)
            return true
        } catch {
            LogManager.shared.log(category: .general, message: "speakBG, Failed to set up audio session: \(error)")
            return false
        }
    }

    func speak(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        AlarmSound.releaseAudioSession()
    }
}
