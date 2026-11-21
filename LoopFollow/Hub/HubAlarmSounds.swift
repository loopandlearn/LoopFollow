// LoopFollow
// HubAlarmSounds.swift

import AVFoundation
import Foundation

/// Copies of the alarm sounds that a push notification can play. iOS plays a
/// notification sound only from Library/Sounds or the bundle, at most 30
/// seconds long, in Linear PCM, IMA4, µLaw or aLaw — the bundled alarm sounds
/// are AAC, so each sound an alarm uses is converted once. The copy goes to the
/// app's Library/Sounds and to the App Group's, where the notification service
/// extension's AlarmKit alarm finds it.
enum HubAlarmSounds {
    private static let maxSeconds: Double = 29.5

    /// File name the hub puts in the push's `sound` for this alarm sound.
    static func notificationName(for sound: SoundFile) -> String {
        switch sound {
        case let .builtin(name): return "lfhub-\(name).caf"
        case let .custom(uuid): return "lfhub-\(uuid.uuidString).caf"
        }
    }

    static func prepare(for alarms: [Alarm]) async {
        await Task.detached(priority: .utility) {
            let directories = soundsDirectories()
            guard let primary = directories.first else { return }
            for sound in Set(alarms.map(\.soundFile)) {
                let name = notificationName(for: sound)
                let converted = primary.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: converted.path), let source = sourceURL(for: sound) {
                    do {
                        try convert(source, to: converted)
                    } catch {
                        try? FileManager.default.removeItem(at: converted)
                        LogManager.shared.log(category: .hub, message: "Notification sound conversion failed for \(sound.displayName): \(error.localizedDescription)")
                        continue
                    }
                }
                for directory in directories.dropFirst() {
                    let copy = directory.appendingPathComponent(name)
                    if !FileManager.default.fileExists(atPath: copy.path) {
                        try? FileManager.default.copyItem(at: converted, to: copy)
                    }
                }
            }
        }.value
    }

    /// The app's Library/Sounds first, then the App Group's.
    private static func soundsDirectories() -> [URL] {
        let libraries = [
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupID.current())?
                .appendingPathComponent("Library", isDirectory: true),
        ].compactMap { $0 }
        return libraries.map { library in
            let directory = library.appendingPathComponent("Sounds", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
    }

    private static func sourceURL(for sound: SoundFile) -> URL? {
        switch sound {
        case let .builtin(name): return Bundle.main.url(forResource: name, withExtension: "caf")
        case let .custom(uuid): return CustomSoundStore.shared.url(for: uuid)
        }
    }

    /// Writes 16-bit Linear PCM, mono, truncated to `maxSeconds`.
    private static func convert(_ source: URL, to destination: URL) throws {
        let input = try AVAudioFile(forReading: source)
        let sampleRate = input.processingFormat.sampleRate
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let converter = AVAudioConverter(from: input.processingFormat, to: monoFormat)
        else { throw CocoaError(.fileReadCorruptFile) }

        let maxFrames = AVAudioFramePosition(maxSeconds * sampleRate)
        let chunk: AVAudioFrameCount = 8192
        while input.framePosition < min(input.length, maxFrames) {
            let frames = AVAudioFrameCount(min(AVAudioFramePosition(chunk), min(input.length, maxFrames) - input.framePosition))
            guard let inBuffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: frames),
                  let outBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: frames)
            else { break }
            try input.read(into: inBuffer, frameCount: frames)
            try converter.convert(to: outBuffer, from: inBuffer)
            try output.write(from: outBuffer)
        }
    }
}
