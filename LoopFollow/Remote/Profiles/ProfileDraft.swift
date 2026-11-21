// LoopFollow
// ProfileDraft.swift

import Foundation

enum ProfilePushSize {
    /// The largest measured size the review accepts. Trio's push is encrypted with a fresh nonce and timestamp at
    /// send time, which changes its size by a few bytes, so it keeps a margin; Loop's measured size is the size sent.
    static func reviewLimit(for remote: ProfileRemote) -> Int {
        APNSDelivery.maxPayloadBytes - (remote == .trio ? 64 : 0)
    }

    static func tooLargeMessage(_ size: Int) -> String {
        "This profile is too large to send remotely (\(size) of \(APNSDelivery.maxPayloadBytes) bytes). Use fewer time segments."
    }
}

enum ScheduledSwitchesPushSize {
    static func tooLargeMessage(_ size: Int) -> String {
        "The scheduled switches are too large to send remotely (\(size) of \(APNSDelivery.maxPayloadBytes) bytes). Use shorter profile names."
    }
}

/// One editable schedule entry. Single-value schedules use `value`; the correction range uses `value` as low and `high`.
struct EditableSegment: Identifiable, Equatable {
    let id: UUID
    var seconds: Int
    var value: Double
    var high: Double

    init(id: UUID = UUID(), seconds: Int, value: Double, high: Double? = nil) {
        self.id = id
        self.seconds = seconds
        self.value = value
        self.high = high ?? value
    }
}

/// The schedules of a profile while they are edited.
struct ProfileDraft: Equatable {
    let units: String
    var basal: [EditableSegment]
    var carbRatio: [EditableSegment]
    var sensitivity: [EditableSegment]
    var target: [EditableSegment]

    /// With `singleTarget`, each target's high value is its low value.
    init(_ values: TherapyProfileValues, singleTarget: Bool = false) {
        units = values.units
        basal = values.basal.map { EditableSegment(seconds: $0.seconds, value: $0.value) }
        carbRatio = values.carbRatio.map { EditableSegment(seconds: $0.seconds, value: $0.value) }
        sensitivity = values.sensitivity.map { EditableSegment(seconds: $0.seconds, value: $0.value) }
        target = values.target.map { EditableSegment(seconds: $0.seconds, value: $0.low, high: singleTarget ? $0.low : $0.high) }
    }

    var values: TherapyProfileValues {
        func items(_ segments: [EditableSegment]) -> [ProfileScheduleItem] {
            segments.map { ProfileScheduleItem(seconds: $0.seconds, value: $0.value) }
        }
        return TherapyProfileValues(
            units: units,
            basal: items(basal),
            carbRatio: items(carbRatio),
            sensitivity: items(sensitivity),
            target: target.map { ProfileRangeItem(seconds: $0.seconds, low: $0.value, high: $0.high) }
        )
    }

    subscript(kind: ProfileScheduleKind) -> [EditableSegment] {
        get {
            switch kind {
            case .basal: return basal
            case .carbRatio: return carbRatio
            case .sensitivity: return sensitivity
            case .correctionRange: return target
            }
        }
        set {
            switch kind {
            case .basal: basal = newValue
            case .carbRatio: carbRatio = newValue
            case .sensitivity: sensitivity = newValue
            case .correctionRange: target = newValue
            }
        }
    }
}

/// Segment operations on the time grid of the published limits.
enum ProfileSegmentGrid {
    /// The start time a new segment gets: one step after the last segment, or the first free slot when the
    /// last segment is at the end of the day. Nil when the schedule is full.
    static func newSegmentStart(_ segments: [EditableSegment], segmentSeconds: Int, maxSegments: Int) -> Int? {
        guard segments.count < maxSegments, segmentSeconds > 0 else { return nil }
        let starts = segments.map(\.seconds).sorted()
        if let last = starts.last, last + segmentSeconds < 86400 {
            return (last / segmentSeconds + 1) * segmentSeconds
        }
        var slot = 0
        while slot < 86400 {
            if !starts.contains(slot) { return slot }
            slot += segmentSeconds
        }
        return nil
    }

    /// Adds a segment that starts with the value in effect at its start time.
    static func addSegment(to segments: [EditableSegment], segmentSeconds: Int, maxSegments: Int) -> [EditableSegment] {
        guard let start = newSegmentStart(segments, segmentSeconds: segmentSeconds, maxSegments: maxSegments) else { return segments }
        let current = segments.last { $0.seconds <= start } ?? segments.first
        var result = segments
        result.append(EditableSegment(seconds: start, value: current?.value ?? 0, high: current?.high))
        return result.sorted { $0.seconds < $1.seconds }
    }

    /// Start times a segment can move to: between its neighbours on the grid. The first segment stays at midnight.
    static func allowedStarts(for index: Int, in segments: [EditableSegment], segmentSeconds: Int) -> [Int] {
        guard index > 0, index < segments.count, segmentSeconds > 0 else { return [0] }
        let lower = segments[index - 1].seconds + segmentSeconds
        let upper = index + 1 < segments.count ? segments[index + 1].seconds : 86400
        let first = (lower + segmentSeconds - 1) / segmentSeconds * segmentSeconds
        return Array(stride(from: first, to: upper, by: segmentSeconds))
    }
}
