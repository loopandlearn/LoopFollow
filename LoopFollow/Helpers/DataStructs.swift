// LoopFollow
// DataStructs.swift

import Foundation

class DataStructs {
    // Pie Chart Data
    struct pieData: Codable {
        var name: String
        var value: Double
    }

    // NS Basal Profile  Struct
    struct basalProfileSegment: Codable {
        var basalRate: Double
        var startDate: TimeInterval
        var endDate: TimeInterval
    }

    // NS Timestamp Only Data  Struct
    struct timestampOnlyStruct: Codable {
        var date: TimeInterval
        var sgv: Int
    }

    // NS Note Data  Struct
    struct noteStruct: Codable {
        var date: TimeInterval
        var sgv: Int
        var note: String
    }

    // NS Battery Data  Struct
    struct batteryStruct: Codable {
        var batteryLevel: Double
        var timestamp: Date
    }

    // NS Override Data  Struct
    struct overrideStruct: Codable {
        var insulNeedsScaleFactor: Double
        var date: TimeInterval
        var endDate: TimeInterval
        var duration: Double
        var correctionRange: [Int]
        var enteredBy: String
        var reason: String
        var sgv: Float
        /// Scheduled end (start + duration); unlike `endDate` it is never
        /// clamped to the graph horizon. Nil when the override runs
        /// indefinitely, so the end is not known in advance.
        var scheduledEndDate: TimeInterval?
    }

    struct tempTargetStruct: Codable {
        var date: TimeInterval
        var endDate: TimeInterval
        var duration: Double
        var correctionRange: [Int]
        var enteredBy: String
        var reason: String
    }
}
