// LoopFollow
// BasalVariabilityCalculator.swift

import Foundation

class BasalVariabilityCalculator {
    static func calculate(
        basalData: [MainViewController.basalGraphStruct],
        basalProfile: [MainViewController.basalProfileStruct],
        startTime: TimeInterval,
        endTime: TimeInterval
    ) -> [BasalVariabilityDataPoint] {
        guard !basalData.isEmpty, !basalProfile.isEmpty else { return [] }

        let sortedProfile = basalProfile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }
        let calendar = dateTimeUtils.displayCalendar()
        let sampleInterval: TimeInterval = 5 * 60

        var periodSamples: [TIRPeriod: [Double]] = [:]

        // Advance step-function pointer to the entry covering startTime
        var basalIndex = 0
        while basalIndex < basalData.count - 1, basalData[basalIndex + 1].date <= startTime {
            basalIndex += 1
        }

        var t = startTime
        while t < endTime {
            while basalIndex < basalData.count - 1, basalData[basalIndex + 1].date <= t {
                basalIndex += 1
            }

            let actualRate = basalData[basalIndex].basalRate

            let date = Date(timeIntervalSince1970: t)
            let dayStart = calendar.startOfDay(for: date).timeIntervalSince1970
            let secondsInDay = t - dayStart

            var scheduledRate = sortedProfile[0].value
            for entry in sortedProfile {
                if entry.timeAsSeconds <= secondsInDay {
                    scheduledRate = entry.value
                } else {
                    break
                }
            }

            if scheduledRate > 0 {
                let ratio = actualRate / scheduledRate
                let hour = calendar.component(.hour, from: date)

                var period: TIRPeriod?
                for p in [TIRPeriod.night, .morning, .day, .evening] {
                    if let range = p.hourRange, hour >= range.start, hour < range.end {
                        period = p
                        break
                    }
                }

                if let period = period {
                    if periodSamples[period] == nil { periodSamples[period] = [] }
                    periodSamples[period]!.append(ratio)
                }
            }

            t += sampleInterval
        }

        var result: [BasalVariabilityDataPoint] = []
        var allRatios: [Double] = []

        for period in [TIRPeriod.night, .morning, .day, .evening] {
            let ratios = periodSamples[period] ?? []
            allRatios.append(contentsOf: ratios)
            result.append(dataPoint(period: period, ratios: ratios))
        }
        result.append(dataPoint(period: .average, ratios: allRatios))

        return result
    }

    private static func dataPoint(period: TIRPeriod, ratios: [Double]) -> BasalVariabilityDataPoint {
        let (vb, b, ap, a, va) = percentages(from: ratios)
        return BasalVariabilityDataPoint(period: period, veryBelow: vb, below: b, atPlanned: ap, above: a, veryAbove: va)
    }

    private static func percentages(from ratios: [Double]) -> (Double, Double, Double, Double, Double) {
        guard !ratios.isEmpty else { return (0, 0, 0, 0, 0) }
        let total = Double(ratios.count)
        var vb = 0, b = 0, ap = 0, a = 0, va = 0
        for r in ratios {
            if r < 0.5 { vb += 1 }
            else if r < 0.75 { b += 1 }
            else if r <= 1.25 { ap += 1 }
            else if r <= 1.5 { a += 1 }
            else { va += 1 }
        }
        return (
            Double(vb) / total * 100,
            Double(b) / total * 100,
            Double(ap) / total * 100,
            Double(a) / total * 100,
            Double(va) / total * 100
        )
    }
}
