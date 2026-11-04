// LoopFollow
// LoopInsulinActivity.swift

import Foundation

/// Insulin activity for Loop, which uploads IOB but not activity. Computed from
/// the boluses and temp basals in Nightscout with the selected insulin model,
/// the way Loop computes IOB: temp basals count net of the scheduled basal,
/// scaled by an active override's insulin needs, and are split into
/// five-minute doses.
enum LoopInsulinActivity {
    struct Dose: Equatable {
        let date: TimeInterval
        let units: Double
    }

    struct Override: Equatable {
        let start: TimeInterval
        let end: TimeInterval
        let insulinNeedsScaleFactor: Double
    }

    struct Point: Equatable {
        let date: TimeInterval
        /// U/h.
        let value: Double
    }

    static let step: TimeInterval = 5 * 60

    /// Net basal doses from the delivered rates (`basalData`) and the scheduled
    /// rates (`basalScheduleData`). Both are rate steps in chronological order:
    /// each dot's rate holds until the next dot.
    static func netBasalDoses(
        delivered: [MainViewController.basalGraphStruct],
        scheduled: [MainViewController.basalGraphStruct],
        overrides: [Override] = [],
        until end: TimeInterval
    ) -> [Dose] {
        guard !scheduled.isEmpty else { return [] }
        var doses: [Dose] = []
        var scheduleIndex = 0

        func scheduledRate(at time: TimeInterval) -> Double {
            while scheduleIndex + 1 < scheduled.count, scheduled[scheduleIndex + 1].date <= time {
                scheduleIndex += 1
            }
            let factor = overrides.last { $0.start <= time && time < $0.end }?.insulinNeedsScaleFactor ?? 1
            return scheduled[scheduleIndex].basalRate * factor
        }

        for i in delivered.indices {
            let start = delivered[i].date
            let stop = min(i + 1 < delivered.count ? delivered[i + 1].date : end, end)
            guard stop > start else { continue }
            var time = start
            while time < stop {
                let next = min(time + step, stop)
                let units = (delivered[i].basalRate - scheduledRate(at: time)) * (next - time) / 3600
                if units != 0 {
                    doses.append(Dose(date: time, units: units))
                }
                time = next
            }
        }
        return doses
    }

    /// IOB and activity at each of `times` (ascending), from `doses` (any order).
    static func evaluate(at times: [TimeInterval], doses: [Dose], model: LoopInsulinModel) -> [InsulinForecast.Point] {
        let sorted = doses.sorted { $0.date < $1.date }
        var first = 0
        return times.map { time in
            while first < sorted.count, sorted[first].date <= time - model.effectDuration {
                first += 1
            }
            var iob = 0.0
            var activity = 0.0
            var index = first
            while index < sorted.count, sorted[index].date <= time {
                let age = time - sorted[index].date
                iob += sorted[index].units * model.percentEffectRemaining(at: age)
                activity += sorted[index].units * model.activity(at: age)
                index += 1
            }
            return InsulinForecast.Point(date: time, iob: iob, activity: activity)
        }
    }

    /// Activity at each of `times` (ascending), from `doses` (any order).
    static func activity(at times: [TimeInterval], doses: [Dose], model: LoopInsulinModel) -> [Point] {
        evaluate(at: times, doses: doses, model: model).map { Point(date: $0.date, value: $0.activity) }
    }

    /// Five-minute steps from `start` to `end`, ending exactly at `end`.
    static func times(from start: TimeInterval, to end: TimeInterval) -> [TimeInterval] {
        guard end >= start else { return [] }
        var times = Array(stride(from: (start / step).rounded(.up) * step, to: end, by: step))
        times.append(end)
        return times
    }
}

extension MainViewController {
    /// Recomputes Loop's insulin activity and insulin forecast after the
    /// treatments, the basal schedule or the insulin model changed.
    func updateLoopInsulinActivity() {
        guard Storage.shared.device.value == "Loop" else {
            if !loopInsulinActivity.isEmpty {
                loopInsulinActivity = []
                insulinForecast = nil
                chartModel.rebuild()
            }
            return
        }

        let model = Storage.shared.loopInsulinModel.value
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        // Treatments are fetched from this time on; earlier doses are unknown,
        // so values start once those would have stopped acting.
        let fetchStart = now - TimeInterval(Storage.shared.downloadDays.value) * 24 * 3600
        let boluses = (bolusData + smbData).filter { $0.date <= now }.map { LoopInsulinActivity.Dose(date: $0.date, units: $0.value) }
        let overrides = overrideGraphData.map {
            LoopInsulinActivity.Override(start: $0.date, end: $0.endDate, insulinNeedsScaleFactor: $0.insulNeedsScaleFactor)
        }
        // The running temp basal counts until its set end.
        let basalEnd = max(now, basalData.last?.date ?? now)
        let basal = LoopInsulinActivity.netBasalDoses(delivered: basalData, scheduled: basalScheduleData, overrides: overrides, until: basalEnd)
        let doses = boluses + basal

        let times = LoopInsulinActivity.times(from: fetchStart + model.effectDuration, to: now)
        loopInsulinActivity = LoopInsulinActivity.activity(at: times, doses: doses, model: model)

        if loopInsulinActivity.isEmpty {
            insulinForecast = nil
        } else {
            let forecastTimes = Array(stride(from: now, through: now + model.effectDuration, by: InsulinForecast.step))
            insulinForecast = InsulinForecast(points: LoopInsulinActivity.evaluate(at: forecastTimes, doses: doses, model: model))
        }

        if let latest = loopInsulinActivity.last {
            infoManager.updateInsulinActivity(latest.value)
        } else {
            infoManager.clearInfoData(type: .insulinActivity)
        }
        chartModel.rebuild()
    }
}
