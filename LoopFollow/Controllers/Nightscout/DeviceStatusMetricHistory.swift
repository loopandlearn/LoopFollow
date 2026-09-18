// LoopFollow
// DeviceStatusMetricHistory.swift

import CoreFoundation
import Foundation

struct DeviceStatusMetricSample: Equatable {
    let date: Date
    let iob: Double?
    let cob: Double?
}

enum DeviceStatusMetricHistoryParser {
    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let timezoneLessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let cobReasonRegex = try? NSRegularExpression(
        pattern: #"\bCOB:\s*(-?\d+(?:\.\d+)?)"#
    )

    static func samples(
        from entries: [[String: AnyObject]],
        cutoff: Date = .distantPast,
        now: Date = Date()
    ) -> [DeviceStatusMetricSample] {
        var samplesByTimestamp: [TimeInterval: DeviceStatusMetricSample] = [:]
        let newestAllowedDate = now.addingTimeInterval(10 * 60)

        // Nightscout normally returns newest-first, but sorting by the upload
        // timestamp makes "keep first" deterministic for duplicate records.
        let orderedEntries = entries.enumerated()
            .map { offset, entry in
                (entry: entry, uploadDate: recordTimestamp(from: entry), offset: offset)
            }
            .sorted { lhs, rhs in
                if lhs.uploadDate == rhs.uploadDate {
                    return lhs.offset < rhs.offset
                }
                return (lhs.uploadDate ?? .distantPast) > (rhs.uploadDate ?? .distantPast)
            }
            .map { $0.entry }

        for entry in orderedEntries {
            for sample in samples(from: entry) where sample.date >= cutoff && sample.date <= newestAllowedDate {
                let timestamp = sample.date.timeIntervalSince1970

                if let existing = samplesByTimestamp[timestamp] {
                    samplesByTimestamp[timestamp] = DeviceStatusMetricSample(
                        date: existing.date,
                        iob: existing.iob ?? sample.iob,
                        cob: existing.cob ?? sample.cob
                    )
                } else {
                    samplesByTimestamp[timestamp] = sample
                }
            }
        }

        return samplesByTimestamp.values.sorted { $0.date < $1.date }
    }

    static func newestEntry(in entries: [[String: AnyObject]]) -> [String: AnyObject]? {
        entries.max { lhs, rhs in
            (recordTimestamp(from: lhs)?.timeIntervalSince1970 ?? -.greatestFiniteMagnitude)
                < (recordTimestamp(from: rhs)?.timeIntervalSince1970 ?? -.greatestFiniteMagnitude)
        } ?? entries.first
    }

    private static func samples(from entry: [String: AnyObject]) -> [DeviceStatusMetricSample] {
        let recordDate = recordTimestamp(from: entry)
        var samples: [DeviceStatusMetricSample] = []

        if let loop = dictionary(entry["loop"]) {
            let loopDate = timestamp(in: loop, keys: ["timestamp", "time", "mills"]) ?? recordDate

            if let iobRecord = dictionary(loop["iob"]),
               let iob = firstNumber(in: iobRecord, keys: ["iob", "IOB"]),
               let date = timestamp(in: iobRecord, keys: ["timestamp", "time", "mills"]) ?? loopDate
            {
                samples.append(DeviceStatusMetricSample(date: date, iob: iob, cob: nil))
            }

            if let cobRecord = dictionary(loop["cob"]),
               let cob = firstNumber(in: cobRecord, keys: ["cob", "COB"]),
               let date = timestamp(in: cobRecord, keys: ["timestamp", "time", "mills"]) ?? loopDate
            {
                samples.append(DeviceStatusMetricSample(date: date, iob: nil, cob: cob))
            }
        }

        if let openAPS = dictionary(entry["openaps"]) {
            let determinations = ["suggested", "enacted"]
                .compactMap { dictionary(openAPS[$0]) }
                .enumerated()
                .map { offset, record in
                    (
                        record: record,
                        date: timestamp(
                            in: record,
                            keys: ["deliverAt", "timestamp", "time", "mills"]
                        ),
                        order: offset
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.date == rhs.date {
                        return lhs.order < rhs.order
                    }
                    return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
                }

            if let iobDetermination = determinations.first(where: {
                firstNumber(in: $0.record, keys: ["IOB", "iob"]) != nil && $0.date != nil
            }), let iob = firstNumber(in: iobDetermination.record, keys: ["IOB", "iob"]),
            let date = iobDetermination.date {
                samples.append(DeviceStatusMetricSample(date: date, iob: iob, cob: nil))
            } else if let iobRecord = firstMetricRecord(openAPS["iob"]),
                      let iob = firstNumber(in: iobRecord, keys: ["iob", "IOB"]),
                      let date = timestamp(
                          in: iobRecord,
                          keys: ["time", "timestamp", "date", "mills"]
                      ) ?? recordDate
            {
                samples.append(DeviceStatusMetricSample(date: date, iob: iob, cob: nil))
            }

            if let cobDetermination = determinations.first(where: {
                firstNumber(in: $0.record, keys: ["COB", "cob"]) != nil && $0.date != nil
            }), let cob = firstNumber(in: cobDetermination.record, keys: ["COB", "cob"]),
            let date = cobDetermination.date {
                samples.append(DeviceStatusMetricSample(date: date, iob: nil, cob: cob))
            } else if let reasonDetermination = determinations.first(where: {
                cobFromReason($0.record["reason"] as? String) != nil && $0.date != nil
            }), let cob = cobFromReason(reasonDetermination.record["reason"] as? String),
            let date = reasonDetermination.date {
                samples.append(DeviceStatusMetricSample(date: date, iob: nil, cob: cob))
            }
        }

        return samples
    }

    private static func recordTimestamp(from entry: [String: AnyObject]) -> Date? {
        for key in ["created_at", "dateString"] {
            if let date = date(entry[key]) {
                return date
            }
        }

        for key in ["date", "mills"] {
            if let date = date(entry[key]) {
                return date
            }
        }

        if let pump = dictionary(entry["pump"]),
           let date = timestamp(in: pump, keys: ["clock", "timestamp", "mills"])
        {
            return date
        }

        if let loop = dictionary(entry["loop"]),
           let date = timestamp(in: loop, keys: ["timestamp", "time", "mills"])
        {
            return date
        }

        if let openAPS = dictionary(entry["openaps"]) {
            for recordKey in ["suggested", "enacted"] {
                if let record = dictionary(openAPS[recordKey]),
                   let date = timestamp(
                       in: record,
                       keys: ["deliverAt", "timestamp", "time", "mills"]
                   )
                {
                    return date
                }
            }
        }

        return nil
    }

    private static func dictionary(_ value: AnyObject?) -> [String: AnyObject]? {
        value as? [String: AnyObject]
    }

    private static func firstMetricRecord(_ value: AnyObject?) -> [String: AnyObject]? {
        if let dictionary = dictionary(value) {
            return dictionary
        }
        let records: [[String: AnyObject]]
        if let dictionaries = value as? [[String: AnyObject]] {
            records = dictionaries
        } else if let objects = value as? [AnyObject] {
            records = objects.compactMap(dictionary)
        } else {
            return nil
        }

        return records.enumerated()
            .map { offset, record in
                (
                    record: record,
                    date: timestamp(in: record, keys: ["time", "timestamp", "date", "mills"]),
                    offset: offset
                )
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.offset < rhs.offset
                }
                return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
            }
            .first?.record
    }

    private static func firstNumber(in dictionary: [String: AnyObject]?, keys: [String]) -> Double? {
        guard let dictionary else { return nil }
        for key in keys {
            if let value = number(dictionary[key]) {
                return value
            }
        }
        return nil
    }

    private static func number(_ value: AnyObject?) -> Double? {
        let parsed: Double?
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            parsed = number.doubleValue
        } else if let string = value as? String {
            parsed = Double(string)
        } else {
            parsed = nil
        }

        guard let parsed, parsed.isFinite else { return nil }
        return parsed
    }

    private static func timestamp(in dictionary: [String: AnyObject], keys: [String]) -> Date? {
        for key in keys {
            if let date = date(dictionary[key]) {
                return date
            }
        }
        return nil
    }

    private static func date(_ value: AnyObject?) -> Date? {
        if let number = number(value) {
            let seconds = number > 10_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        guard let string = value as? String else { return nil }
        if let numeric = Double(string) {
            let seconds = numeric > 10_000_000_000 ? numeric / 1000 : numeric
            return Date(timeIntervalSince1970: seconds)
        }

        if let date = fractionalDateFormatter.date(from: string) {
            return date
        }

        if let date = internetDateFormatter.date(from: string) {
            return date
        }

        return timezoneLessDateFormatter.date(from: string)
    }

    private static func cobFromReason(_ reason: String?) -> Double? {
        guard let reason,
              let regex = cobReasonRegex,
              let match = regex.firstMatch(
                  in: reason,
                  range: NSRange(reason.startIndex ..< reason.endIndex, in: reason)
              ),
              let valueRange = Range(match.range(at: 1), in: reason)
        else {
            return nil
        }

        return Double(reason[valueRange])
    }
}

extension MainViewController {
    func prepareDeviceStatusMetricHistorySource() {
        let source = Storage.shared.url.value + "\u{0}" + Storage.shared.token.value
        guard source != deviceStatusMetricHistorySource else { return }

        deviceStatusMetricHistoryGeneration += 1
        deviceStatusRequestGeneration += 1
        deviceStatusMetricHistorySource = source
        deviceStatusMetricHistoryDevice = ""
        deviceStatusMetricHistoryLoadedDays = 0
        isLoadingDeviceStatusMetricHistory = false
        deviceStatusMetricHistory = []
        chartModel.rebuild()
    }

    func prepareDeviceStatusMetricHistoryDevice(_ device: String?) {
        let device = device ?? ""
        guard device != deviceStatusMetricHistoryDevice else { return }

        deviceStatusMetricHistoryGeneration += 1
        deviceStatusMetricHistoryDevice = device
        deviceStatusMetricHistoryLoadedDays = 0
        isLoadingDeviceStatusMetricHistory = false
        deviceStatusMetricHistory = []
        chartModel.rebuild()
    }

    func mergeCurrentDeviceStatusMetricHistory(_ incoming: [DeviceStatusMetricSample]) {
        if let previousNewest = deviceStatusMetricHistory.last?.date,
           let incomingNewest = incoming.last?.date,
           incomingNewest.timeIntervalSince(previousNewest) > 15 * 60
        {
            // The app was suspended or offline long enough to miss samples.
            // Re-run the one-time backfill so the visible gap is recovered.
            deviceStatusMetricHistoryLoadedDays = 0
        }

        mergeDeviceStatusMetricHistory(incoming)
    }

    func mergeDeviceStatusMetricHistory(
        _ incoming: [DeviceStatusMetricSample],
        preferIncoming: Bool = true
    ) {
        guard !incoming.isEmpty else { return }

        // Retain the widest history already loaded. This avoids discarding
        // samples when Show Days Back is temporarily reduced and then restored.
        let retentionDays = max(
            max(Storage.shared.downloadDays.value, deviceStatusMetricHistoryLoadedDays),
            1
        )
        let cutoff = Date().addingTimeInterval(
            -TimeInterval(retentionDays * 24 * 3600)
        )
        var samplesByTimestamp = Dictionary(
            uniqueKeysWithValues: deviceStatusMetricHistory.map {
                ($0.date.timeIntervalSince1970, $0)
            }
        )

        for sample in incoming where sample.date >= cutoff {
            let timestamp = sample.date.timeIntervalSince1970
            if let existing = samplesByTimestamp[timestamp] {
                samplesByTimestamp[timestamp] = DeviceStatusMetricSample(
                    date: existing.date,
                    iob: preferIncoming ? (sample.iob ?? existing.iob) : (existing.iob ?? sample.iob),
                    cob: preferIncoming ? (sample.cob ?? existing.cob) : (existing.cob ?? sample.cob)
                )
            } else {
                samplesByTimestamp[timestamp] = sample
            }
        }

        deviceStatusMetricHistory = samplesByTimestamp.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        chartModel.rebuild()
    }

    func loadDeviceStatusMetricHistoryIfNeeded() {
        let requestedDays = max(Storage.shared.downloadDays.value, 1)
        guard IsNightscoutEnabled(),
              Storage.shared.showIOBCOBHistory.value,
              deviceStatusMetricHistoryLoadedDays < requestedDays,
              !isLoadingDeviceStatusMetricHistory
        else {
            return
        }

        isLoadingDeviceStatusMetricHistory = true
        deviceStatusMetricHistoryGeneration += 1
        let requestGeneration = deviceStatusMetricHistoryGeneration
        let requestedSource = deviceStatusMetricHistorySource
        let now = Date()
        let cutoff = now.addingTimeInterval(-TimeInterval(requestedDays * 24 * 3600))
        let upperBound = now.addingTimeInterval(10 * 60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Filtering by the current uploader avoids mixing unrelated Loop,
        // Trio, and xDrip status streams and keeps this one-time request small.
        let uploaderHeadroom = deviceStatusMetricHistoryDevice.isEmpty ? 4 : 2
        let estimatedCount = requestedDays * 24 * 12 * uploaderHeadroom
        var parameters = [
            "find[created_at][$gte]": formatter.string(from: cutoff),
            "find[created_at][$lte]": formatter.string(from: upperBound),
            "count": "\(estimatedCount)",
        ]
        if !deviceStatusMetricHistoryDevice.isEmpty {
            parameters["find[device]"] = deviceStatusMetricHistoryDevice
        }

        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { result in
            DispatchQueue.main.async {
                guard requestedSource == self.deviceStatusMetricHistorySource,
                      requestGeneration == self.deviceStatusMetricHistoryGeneration
                else {
                    return
                }

                switch result {
                case let .success(json):
                    guard let entries = json as? [[String: AnyObject]] else {
                        self.isLoadingDeviceStatusMetricHistory = false
                        LogManager.shared.log(
                            category: .deviceStatus,
                            message: "Device status history returned an unexpected data structure"
                        )
                        return
                    }

                    DispatchQueue.global(qos: .utility).async {
                        let samples = DeviceStatusMetricHistoryParser.samples(
                            from: entries,
                            cutoff: cutoff,
                            now: now
                        )

                        DispatchQueue.main.async {
                            guard requestedSource == self.deviceStatusMetricHistorySource,
                                  requestGeneration == self.deviceStatusMetricHistoryGeneration
                            else {
                                return
                            }
                            self.isLoadingDeviceStatusMetricHistory = false
                            self.deviceStatusMetricHistoryLoadedDays = requestedDays
                            // A count=1 response may have arrived while the backfill
                            // was parsing. Preserve those fresher samples on collision.
                            self.mergeDeviceStatusMetricHistory(samples, preferIncoming: false)
                            self.loadDeviceStatusMetricHistoryIfNeeded()
                        }
                    }

                case let .failure(error):
                    self.isLoadingDeviceStatusMetricHistory = false
                    LogManager.shared.log(
                        category: .deviceStatus,
                        message: "Device status history fetch failed: \(error.localizedDescription)",
                        limitIdentifier: "Device status history fetch failed"
                    )
                }
            }
        }
    }

    func clearDeviceStatusMetricHistory() {
        guard !deviceStatusMetricHistory.isEmpty
            || deviceStatusMetricHistoryLoadedDays != 0
            || isLoadingDeviceStatusMetricHistory
            || !deviceStatusMetricHistorySource.isEmpty
        else {
            return
        }

        deviceStatusMetricHistoryGeneration += 1
        deviceStatusMetricHistory = []
        deviceStatusMetricHistoryLoadedDays = 0
        isLoadingDeviceStatusMetricHistory = false
        deviceStatusMetricHistorySource = ""
        deviceStatusMetricHistoryDevice = ""
        chartModel.rebuild()
    }
}
