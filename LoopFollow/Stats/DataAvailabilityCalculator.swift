// LoopFollow
// DataAvailabilityCalculator.swift

import Foundation

struct DataAvailabilityInfo {
    let totalExpectedReadings: Int
    let actualReadings: Int
    let coveragePercentage: Double
    let missingIntervals: Int
    let dataQuality: DataQuality

    enum DataQuality {
        case excellent // >= 95%
        case good // >= 85%
        case fair // >= 70%
        case poor // < 70%

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }

        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }
    }

    var displayText: String {
        return String(format: "%.1f%% (%d/%d readings)",
                      coveragePercentage,
                      actualReadings,
                      totalExpectedReadings)
    }
}

class DataAvailabilityCalculator {
    /// Calculates data availability based on expected CGM readings every 5 minutes
    /// - Parameters:
    ///   - bgData: Array of glucose readings
    ///   - startDate: Start of the analysis period
    ///   - endDate: End of the analysis period
    /// - Returns: DataAvailabilityInfo with coverage statistics
    static func calculateAvailability(
        bgData: [ShareGlucoseData],
        startDate: Date,
        endDate: Date
    ) -> DataAvailabilityInfo {
        // Calculate time interval in minutes
        let intervalMinutes = 5.0
        let totalMinutes = endDate.timeIntervalSince(startDate) / 60.0
        let expectedReadings = Int(totalMinutes / intervalMinutes)

        // Filter data within the date range
        let startTimestamp = startDate.timeIntervalSince1970
        let endTimestamp = endDate.timeIntervalSince1970

        let relevantData = bgData.filter { reading in
            reading.date >= startTimestamp && reading.date <= endTimestamp
        }.sorted { $0.date < $1.date }

        guard !relevantData.isEmpty else {
            return DataAvailabilityInfo(
                totalExpectedReadings: max(expectedReadings, 0),
                actualReadings: 0,
                coveragePercentage: 0.0,
                missingIntervals: max(expectedReadings, 0),
                dataQuality: .poor
            )
        }

        // Count intervals with at least one reading
        var coveredIntervals = Set<Int>()

        for reading in relevantData {
            let readingTime = Date(timeIntervalSince1970: reading.date)
            let minutesSinceStart = readingTime.timeIntervalSince(startDate) / 60.0
            let intervalIndex = Int(minutesSinceStart / intervalMinutes)

            if intervalIndex >= 0 && intervalIndex < expectedReadings {
                coveredIntervals.insert(intervalIndex)
            }
        }

        let actualCoveredIntervals = coveredIntervals.count
        let coveragePercentage = expectedReadings > 0
            ? (Double(actualCoveredIntervals) / Double(expectedReadings)) * 100.0
            : 0.0

        let missingIntervals = expectedReadings - actualCoveredIntervals

        // Determine data quality
        let quality: DataAvailabilityInfo.DataQuality
        if coveragePercentage >= 95.0 {
            quality = .excellent
        } else if coveragePercentage >= 85.0 {
            quality = .good
        } else if coveragePercentage >= 70.0 {
            quality = .fair
        } else {
            quality = .poor
        }

        return DataAvailabilityInfo(
            totalExpectedReadings: expectedReadings,
            actualReadings: actualCoveredIntervals,
            coveragePercentage: coveragePercentage,
            missingIntervals: missingIntervals,
            dataQuality: quality
        )
    }

    /// Identifies gaps in CGM data longer than a specified threshold
    /// - Parameters:
    ///   - bgData: Array of glucose readings
    ///   - thresholdMinutes: Minimum gap duration to report (default: 60 minutes)
    /// - Returns: Array of gaps as date ranges
    static func findDataGaps(
        bgData: [ShareGlucoseData],
        thresholdMinutes: Double = 60.0
    ) -> [(start: Date, end: Date, durationMinutes: Double)] {
        guard bgData.count > 1 else { return [] }

        let sortedData = bgData.sorted { $0.date < $1.date }
        var gaps: [(start: Date, end: Date, durationMinutes: Double)] = []

        for i in 0 ..< (sortedData.count - 1) {
            let current = sortedData[i]
            let next = sortedData[i + 1]

            let gapMinutes = (next.date - current.date) / 60.0

            if gapMinutes >= thresholdMinutes {
                let gapStart = Date(timeIntervalSince1970: current.date)
                let gapEnd = Date(timeIntervalSince1970: next.date)
                gaps.append((start: gapStart, end: gapEnd, durationMinutes: gapMinutes))
            }
        }

        return gaps
    }
}
