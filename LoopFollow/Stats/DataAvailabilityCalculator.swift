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
        case good // >= 70%
        case fair // >= 50%
        case poor // < 50%

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "green"
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
        let intervalMinutes = 5.0
        let totalMinutes = endDate.timeIntervalSince(startDate) / 60.0
        let expectedReadings = Int(totalMinutes / intervalMinutes)

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

        let quality: DataAvailabilityInfo.DataQuality
        if coveragePercentage >= 95.0 {
            quality = .excellent
        } else if coveragePercentage >= 70.0 {
            quality = .good
        } else if coveragePercentage >= 50.0 {
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
}
