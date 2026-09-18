// LoopFollow
// PumpReservoir.swift

import Foundation

/// What is known about one pump's reservoir, carried between device status records.
struct PumpReservoirCache: Codable, Equatable {
    struct Reading: Codable, Equatable {
        let units: Double
        let date: Date
    }

    let pumpID: String
    /// When this pump first appeared in a device status record LoopFollow fetched.
    let pumpSince: Date
    var reading: Reading?
}

/// What a device status record says about the reservoir.
enum PumpReservoirState: Equatable {
    /// An exact volume, from the record itself or from a recent reading for the same pump.
    case units(Double)
    /// A pump that reports a volume only once it drops below 50U, and is above it.
    case aboveReportingLimit
    /// No volume to show.
    case unknown
}

enum PumpReservoirResolver {
    /// Omnipod reports the reservoir in only some of the device status records it uploads
    /// while the pod is below 50U. A reading carries across those gaps for this long.
    static let maxReadingAge: TimeInterval = 30 * 60

    /// A volume reported within this long of a pump first appearing can still be the
    /// previous pod's final reading, so it says nothing about the pump now on.
    static let pumpSettleTime: TimeInterval = 15 * 60

    struct Resolution: Equatable {
        let state: PumpReservoirState
        /// What to keep for the next record, `nil` to store nothing.
        let cache: PumpReservoirCache?
    }

    static func resolve(
        reservoir: Double?,
        pumpID: String?,
        manufacturer: String?,
        model: String?,
        cache storedCache: PumpReservoirCache?,
        now: Date
    ) -> Resolution {
        let withoutReading: PumpReservoirState = reportsVolumeOnlyWhenLow(manufacturer: manufacturer, model: model)
            ? .aboveReportingLimit
            : .unknown

        // A reading is carried between records only when the uploader names the pump it
        // came from, so that a pod change discards it.
        guard let pumpID = identifiedPump(pumpID) else {
            guard let reservoir else { return Resolution(state: withoutReading, cache: nil) }
            return Resolution(state: .units(reservoir), cache: nil)
        }

        var cache = storedCache?.pumpID == pumpID
            ? storedCache!
            : PumpReservoirCache(pumpID: pumpID, pumpSince: now, reading: nil)

        if let reservoir {
            cache.reading = PumpReservoirCache.Reading(units: reservoir, date: now)
            return Resolution(state: .units(reservoir), cache: cache)
        }

        if let reading = cache.reading {
            let age = now.timeIntervalSince(reading.date)
            if age >= 0, age <= maxReadingAge {
                return Resolution(state: .units(reading.units), cache: cache)
            }
            if reading.date.timeIntervalSince(cache.pumpSince) >= pumpSettleTime {
                // The pump has reported a volume long enough after coming online for that
                // to be its own, so it is below its reporting limit and the only thing
                // missing is a fresh number. A pump first seen mid-pod has no such gap,
                // so its first reading is treated as a pod change's and dropped below.
                return Resolution(state: .unknown, cache: cache)
            }
            cache.reading = nil
        }

        return Resolution(state: withoutReading, cache: cache)
    }

    private static func identifiedPump(_ pumpID: String?) -> String? {
        let trimmed = pumpID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Loop reports "Unknown" while no pod is paired.
        guard !trimmed.isEmpty, trimmed != "Unknown" else { return nil }
        return trimmed
    }

    private static func reportsVolumeOnlyWhenLow(manufacturer: String?, model: String?) -> Bool {
        let pump = [manufacturer, model].compactMap { $0 }.joined(separator: " ").lowercased()
        // An uploader that names no pump cannot be told apart from one that reports its
        // volume only when low, so it gets the same reading.
        guard !pump.isEmpty else { return true }
        return pump.contains("insulet") || pump.contains("omnipod") || pump.contains("dash")
    }
}
