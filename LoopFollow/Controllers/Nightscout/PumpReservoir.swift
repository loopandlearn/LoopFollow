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
    /// Whether a volume in a record is this pump's own. Right after a pod change Loop
    /// still uploads the previous pod's final volume.
    var isSettled: Bool

    init(pumpID: String, pumpSince: Date, reading: Reading? = nil, isSettled: Bool = true) {
        self.pumpID = pumpID
        self.pumpSince = pumpSince
        self.reading = reading
        self.isSettled = isSettled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pumpID = try container.decode(String.self, forKey: .pumpID)
        pumpSince = try container.decode(Date.self, forKey: .pumpSince)
        reading = try container.decodeIfPresent(Reading.self, forKey: .reading)
        isSettled = try container.decodeIfPresent(Bool.self, forKey: .isSettled) ?? true
    }
}

/// What a device status record says about the reservoir.
enum PumpReservoirState: Equatable {
    /// An exact volume, from the record itself or from a recent reading for the same pump.
    case units(Double)
    /// A pump that reports a volume only once it drops below 50U, and is above it.
    case aboveReportingLimit
    /// The status the uploader shows in place of the volume, such as "No Pod".
    case status(String)
    /// No volume to show.
    case unknown
}

enum PumpReservoirResolver {
    /// Omnipod reports the reservoir in only some of the device status records it uploads
    /// while the pod is below 50U. A reading carries across those gaps for this long.
    static let maxReadingAge: TimeInterval = 30 * 60

    /// Loop uploads its last reservoir reading until it is 15 minutes old, whichever pod it
    /// came from, so the previous pod's final volume can appear for up to this long after a
    /// pod change. A new pod reports no volume of its own until it drops below 50U.
    static let pumpSettleTime: TimeInterval = 15 * 60

    struct Resolution: Equatable {
        let state: PumpReservoirState
        /// What to keep for the next record, `nil` to store nothing.
        let cache: PumpReservoirCache?
    }

    /// - Parameters:
    ///   - displayOverride: The status Loop shows in place of the reservoir, such as
    ///     "Finish Setup" or "No Pod", in the uploader's language.
    ///   - date: When the record was made, from the pump clock it carries.
    static func resolve(
        reservoir: Double?,
        pumpID: String?,
        manufacturer: String?,
        model: String?,
        displayOverride: String? = nil,
        cache storedCache: PumpReservoirCache?,
        date: Date
    ) -> Resolution {
        let resolution = resolveVolume(
            reservoir: reservoir,
            pumpID: pumpID,
            manufacturer: manufacturer,
            model: model,
            cache: storedCache,
            date: date
        )
        // The pump keeps being tracked while its status replaces the volume.
        if let status = displayOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return Resolution(state: .status(status), cache: resolution.cache)
        }
        return resolution
    }

    private static func resolveVolume(
        reservoir: Double?,
        pumpID: String?,
        manufacturer: String?,
        model: String?,
        cache storedCache: PumpReservoirCache?,
        date: Date
    ) -> Resolution {
        let onlyWhenLow = reportsVolumeOnlyWhenLow(manufacturer: manufacturer, model: model)
        let withoutReading: PumpReservoirState = onlyWhenLow ? .aboveReportingLimit : .unknown

        let pumpID = pumpID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Loop reports an Omnipod as "Unknown" while no pod is paired, so there is no volume
        // to show and one in the record is the previous pod's. Medtrum is always "Unknown"
        // on Loop.
        if pumpID == "Unknown", onlyWhenLow {
            return Resolution(state: .unknown, cache: storedCache)
        }

        // A reading is carried between records only when the uploader names the pump it
        // came from, so that a pod change discards it. The stored pump is kept across
        // records that name none, so the next one reads as a change.
        guard !pumpID.isEmpty, pumpID != "Unknown" else {
            guard let reservoir else { return Resolution(state: withoutReading, cache: storedCache) }
            return Resolution(state: .units(reservoir), cache: storedCache)
        }

        var cache: PumpReservoirCache
        if let storedCache, storedCache.pumpID == pumpID {
            cache = storedCache
        } else {
            // With no pump stored there is no change to have seen, so the pump is taken
            // as one already in use.
            cache = PumpReservoirCache(pumpID: pumpID, pumpSince: date, isSettled: storedCache == nil || !onlyWhenLow)
        }

        if !cache.isSettled, reservoir == nil || date.timeIntervalSince(cache.pumpSince) >= pumpSettleTime {
            cache.isSettled = true
        }

        if let reservoir {
            guard cache.isSettled else { return Resolution(state: withoutReading, cache: cache) }
            cache.reading = PumpReservoirCache.Reading(units: reservoir, date: date)
            return Resolution(state: .units(reservoir), cache: cache)
        }

        if let reading = cache.reading {
            let age = date.timeIntervalSince(reading.date)
            if age >= 0, age <= maxReadingAge {
                return Resolution(state: .units(reading.units), cache: cache)
            }
            // The pump has reported a volume of its own, so it is below its reporting limit
            // and the only thing missing is a fresh number.
            return Resolution(state: .unknown, cache: cache)
        }

        return Resolution(state: withoutReading, cache: cache)
    }

    private static func reportsVolumeOnlyWhenLow(manufacturer: String?, model: String?) -> Bool {
        let pump = [manufacturer, model].compactMap { $0 }.joined(separator: " ").lowercased()
        // An uploader that names no pump cannot be told apart from one that reports its
        // volume only when low, so it gets the same reading.
        guard !pump.isEmpty else { return true }
        return pump.contains("insulet") || pump.contains("omnipod") || pump.contains("dash")
    }
}
