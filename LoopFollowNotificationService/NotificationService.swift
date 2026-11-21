// LoopFollow
// NotificationService.swift

import AVFAudio
import UserNotifications

/// Runs for every push that carries `mutable-content`. For an LF Hub alarm it
/// rings an AlarmKit alarm (iOS 26+, when allowed) and confirms the delivery to the
/// hub, then delivers the notification, without its own sound when the system alarm
/// rings. A hub alarm or Speak BG push reaching a phone that left the hub is delivered
/// quietly. Other notifications are left as they are.
final class NotificationService: UNNotificationServiceExtension {
    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var speech: SpeechFile?

    /// Hands the notification to the system once; whichever of the work and the
    /// expiry comes second does nothing.
    private func deliver(_ content: UNNotificationContent) {
        let handler = lock.withLock {
            defer { contentHandler = nil }
            return contentHandler
        }
        handler?(content)
    }

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)
    {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        lock.withLock {
            self.contentHandler = contentHandler
            self.content = content
        }

        let userInfo = request.content.userInfo
        Self.log("received keys=\(userInfo.keys.compactMap { $0 as? String }.sorted())")

        // The hub stops a system alarm whose condition cleared or that Snooze All silenced.
        if let stop = userInfo["lfhubStopAlarmId"] as? String, let stopID = UUID(uuidString: stop) {
            #if canImport(AlarmKit)
                if #available(iOS 26, *) { HubAlarmKit.stop(alarmID: stopID) }
            #endif
            Self.log("alarm \(stopID.uuidString.prefix(8)) stopped by the hub")
            deliver(content)
            return
        }
        let isAlarm = userInfo["lfhubAlarmId"] != nil
        let delivery = HubAppGroup.delivery(hubURL: Self.hubURL, systemAlarm: (userInfo["lfhubAlarmKit"] as? Int) == 1)
        if delivery == .quiet, isAlarm || userInfo["lfhubSpeak"] != nil {
            content.sound = nil
            content.interruptionLevel = .passive
            Self.log("\(isAlarm ? "alarm" : "speak") delivered quietly: not connected to a hub")
            deliver(content)
            return
        }
        if let speak = userInfo["lfhubSpeak"] as? [String: Any], let library = Self.groupLibrary {
            self.speak(speak, content: content, sounds: library.appendingPathComponent("Sounds", isDirectory: true))
            return
        }
        guard let alarm = userInfo["lfhubAlarmId"] as? String, let alarmID = UUID(uuidString: alarm) else {
            deliver(content)
            return
        }

        let receipt = userInfo["lfhubReceipt"] as? String
        let ringsSystemAlarm = delivery == .systemAlarm
        let named = userInfo["lfhubSound"] as? String
        // A sound the app has not put in the App Group rings as the default sound.
        let sound = named.flatMap { Self.soundExists($0) ? $0 : nil }
        if let named, sound == nil {
            Self.log("alarm \(alarmID.uuidString.prefix(8)) sound \(named) missing, ringing the default sound")
        }
        let acknowledge = request.content.categoryIdentifier == HubAppGroup.acknowledgeCategory
        let symbol = userInfo["lfhubIcon"] as? String ?? "moon.zzz"
        let ringOnce = (userInfo["lfhubRingOnce"] as? Int) == 1
        let started = Date()
        Task {
            async let receiptSent: Void = Self.sendReceipt(receipt, alarmID: alarmID)
            if ringsSystemAlarm {
                let (ringing, firesAt) = await Self.ring(alarmID: alarmID, title: content.title, sound: sound,
                                                         symbol: symbol, acknowledge: acknowledge)
                if ringing {
                    // The system alarm is the alert; the notification goes quietly to the list.
                    content.sound = nil
                    content.interruptionLevel = .passive
                }
                if ringOnce, let firesAt {
                    await Self.stopAfterOnePlay(alarmID: alarmID, firesAt: firesAt, sound: sound, started: started)
                }
            }
            await receiptSent
            self.deliver(content)
        }
    }

    /// Rings the hub alarm as an AlarmKit alarm: whether it rings, and when it starts if
    /// this push scheduled it.
    private static func ring(alarmID: UUID, title: String, sound: String?, symbol: String,
                             acknowledge: Bool) async -> (Bool, Date?)
    {
        #if canImport(AlarmKit)
            if #available(iOS 26, *) {
                let result = await HubAlarmKit.ring(alarmID: alarmID, title: title, soundName: sound, symbol: symbol,
                                                    acknowledge: acknowledge)
                log("alarm \(alarmID.uuidString.prefix(8)) sound=\(sound ?? "default") button=\(HubAlarmKit.buttonTitle(acknowledge: acknowledge)) -> \(result.detail)")
                return (result.ringing, result.firesAt)
            }
        #endif
        log("alarm \(alarmID.uuidString.prefix(8)): AlarmKit unavailable")
        return (false, nil)
    }

    /// The system alarm loops its sound until stopped; an alarm whose sound does not repeat
    /// is stopped once it has sounded for its sound's length plus `ringMargin`, within the
    /// time the extension is given. An alarm that has not begun to sound by then
    /// is left ringing; the hub stops it later.
    private static func stopAfterOnePlay(alarmID: UUID, firesAt: Date, sound: String?, started: Date) async {
        #if canImport(AlarmKit)
            if #available(iOS 26, *) {
                let deadline = started.addingTimeInterval(ringOnceDeadline)
                while !HubAlarmKit.isAlerting(alarmID: alarmID) {
                    guard Date() < deadline else {
                        log("alarm \(alarmID.uuidString.prefix(8)) not sounding yet, left for the hub to stop")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                let alerting = Date()
                let ring = (soundDuration(sound) ?? defaultSoundDuration) + ringMargin
                let wait = min(alerting.addingTimeInterval(ring), deadline).timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
                HubAlarmKit.stop(alarmID: alarmID)
                log("alarm \(alarmID.uuidString.prefix(8)) sounded \(Int(alerting.timeIntervalSince(firesAt) * 1000)) ms after its fire time, stopped after \(Int(Date().timeIntervalSince(alerting))) s")
            }
        #endif
    }

    /// How long a sound in the App Group's Library/Sounds plays; nil when it cannot be read.
    private static func soundDuration(_ name: String?) -> TimeInterval? {
        guard let name, let library = groupLibrary,
              let player = try? AVAudioPlayer(contentsOf: library.appendingPathComponent("Sounds/\(name)"))
        else { return nil }
        return player.duration
    }

    /// The play time assumed for the system's default alarm sound.
    private static let defaultSoundDuration: TimeInterval = 8

    /// The time from the alarm's alerting state to its sound being heard, allowed on top of the sound.
    private static let ringMargin: TimeInterval = 0.75

    /// The extension gets about 30 seconds per push; the stop and the delivery fit within this.
    private static let ringOnceDeadline: TimeInterval = 25

    /// Tells the hub this alarm push reached the phone. The receipt token is the
    /// credential; the request carries no key and no body.
    private static func sendReceipt(_ token: String?, alarmID: UUID) async {
        guard let token, token.count == 32, token.allSatisfy(\.isHexDigit) else { return }
        guard let base = hubURL, let url = URL(string: "\(base)/v1/receipt/\(token)")
        else {
            log("alarm \(alarmID.uuidString.prefix(8)) receipt not sent: no hub URL")
            return
        }
        var request = URLRequest(url: url, timeoutInterval: receiptTimeout)
        request.httpMethod = "POST"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            log("alarm \(alarmID.uuidString.prefix(8)) receipt -> \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        } catch {
            log("alarm \(alarmID.uuidString.prefix(8)) receipt failed: \(error.localizedDescription)")
        }
    }

    private static let receiptTimeout: TimeInterval = 10

    /// Speak BG from the hub: the announcement for the reading becomes the
    /// notification's sound. Without a rendered file the push's own sound plays.
    private func speak(_ speak: [String: Any], content: UNMutableNotificationContent, sounds: URL) {
        guard let current = (speak["current"] as? NSNumber)?.intValue,
              let previous = (speak["previous"] as? NSNumber)?.intValue
        else {
            deliver(content)
            return
        }
        let language = speak["language"] as? String ?? "en"
        let text = BGAnnouncement.text(current: current, previous: previous, language: language,
                                       mmol: speak["mmol"] as? Bool ?? false)
        let started = Date()
        let speech = SpeechFile(directory: sounds)
        lock.withLock { self.speech = speech }
        speech.render(text, language: BGAnnouncement.voiceLanguageCode(forAppLanguage: language)) { name in
            Self.log("speak \(language) -> \(name ?? "failed") in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
            if let name { content.sound = UNNotificationSound(named: UNNotificationSoundName(name)) }
            self.deliver(content)
        }
    }

    /// The hub's address while the app is connected to one.
    private static var hubURL: String? {
        groupID.flatMap { UserDefaults(suiteName: $0) }?.string(forKey: HubAppGroup.hubURLKey)
    }

    private static var groupID: String? {
        (Bundle.main.object(forInfoDictionaryKey: "LFAppGroupBaseBundleID") as? String).map { "group.\($0)" }
    }

    private static var groupLibrary: URL? {
        guard let groupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("Library", isDirectory: true)
    }

    private static func soundExists(_ name: String?) -> Bool {
        guard let name, let library = groupLibrary else { return false }
        return FileManager.default.fileExists(atPath: library.appendingPathComponent("Sounds/\(name)").path)
    }

    /// The log keeps its newest lines within this size.
    private static let logLimit = 256 * 1024

    /// Appends to Library/Logs/lfhub-nse.log in the App Group, newest last. Past
    /// `logLimit` the oldest half is dropped.
    private static func log(_ message: String) {
        guard let library = groupLibrary else { return }
        let directory = library.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("lfhub-nse.log")
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int, size > logLimit,
           let data = try? Data(contentsOf: url)
        {
            var kept = data.suffix(logLimit / 2)
            if let newline = kept.firstIndex(of: UInt8(ascii: "\n")) { kept = kept[kept.index(after: newline)...] }
            try? Data(kept).write(to: url, options: .atomic)
        }
        let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let content = lock.withLock({ content }) { deliver(content) }
    }
}

/// Renders text to speech into a sound file the notification can play. Only
/// the latest rendering is kept.
final class SpeechFile: NSObject {
    private let directory: URL
    private let synthesizer = AVSpeechSynthesizer()
    private var file: AVAudioFile?

    init(directory: URL) {
        self.directory = directory
    }

    func render(_ text: String, language: String, completion: @escaping (String?) -> Void) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let old = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in old where name.hasPrefix("lfhub-speak-") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        let name = "lfhub-speak-\(Int(Date().timeIntervalSince1970)).caf"
        let url = directory.appendingPathComponent(name)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        var finished = false
        synthesizer.write(utterance) { [weak self] buffer in
            guard let self, !finished else { return }
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                finished = true
                let ok = file != nil
                file = nil
                completion(ok ? name : nil)
                return
            }
            do {
                if file == nil {
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: pcm.format.sampleRate,
                        AVNumberOfChannelsKey: pcm.format.channelCount,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                    ]
                    file = try AVAudioFile(forWriting: url, settings: settings,
                                           commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                }
                try file?.write(from: pcm)
            } catch {
                finished = true
                file = nil
                completion(nil)
            }
        }
    }
}
