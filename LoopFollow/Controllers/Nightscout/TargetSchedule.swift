// LoopFollow
// TargetSchedule.swift

import Foundation

extension MainViewController {
    /// Builds `targetScheduleData`, the routine (non-Override) target-of-the-day line shown on
    /// the graph -- mirrors `basalScheduleData` in Profile.swift exactly, substituting the
    /// profile's target-high schedule (via `profileManager.targetHighSchedule`, already
    /// unit-converted) for the basal schedule. Uses target-high specifically to match
    /// `currentTargetHigh()`, the same value already shown in the "Target" info row, so the line
    /// never disagrees with the number beside it.
    ///
    /// Like the basal line, this only ever reflects the day's *routine* schedule -- an active
    /// Override, Temp Target, or Weekend Profile is shown separately as a colored band
    /// (`overrides`/`tempTargets` in BGChartModel), the same relationship Trio's own target line
    /// has with its own Override bands.
    func updateTargetScheduleData() {
        let targetSchedule = profileManager.targetHighSchedule
        guard !targetSchedule.isEmpty else {
            targetScheduleData.removeAll()
            return
        }

        var targetSegments: [DataStructs.targetProfileSegment] = []

        let graphHours = 24 * Storage.shared.downloadDays.value
        // Build scheduled target segments from right to left by moving pointers to the current
        // midnight and current target -- same walk as the basal schedule builder.
        var midnight = dateTimeUtils.getTimeIntervalMidnightToday()
        var targetIndex = targetSchedule.count - 1
        var start = midnight + Double(targetSchedule[targetIndex].timeAsSeconds)
        var end = dateTimeUtils.getNowTimeIntervalUTC()
        while start > end {
            targetIndex -= 1
            start = midnight + Double(targetSchedule[targetIndex].timeAsSeconds)
        }
        let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
        while end >= graphStart {
            let entry = DataStructs.targetProfileSegment(
                targetHigh: targetSchedule[targetIndex].value.doubleValue(for: .milligramsPerDeciliter),
                startDate: start, endDate: end
            )
            targetSegments.append(entry)

            targetIndex -= 1
            if targetIndex < 0 {
                targetIndex = targetSchedule.count - 1
                midnight = midnight.advanced(by: -24 * 60 * 60)
            }
            end = start - 1
            start = midnight + Double(targetSchedule[targetIndex].timeAsSeconds)
        }
        targetSegments.reverse()

        var firstPass = true
        let predictionEndTime = dateTimeUtils.getNowTimeIntervalUTC() + (3600 * Storage.shared.predictionToLoad.value)
        targetScheduleData.removeAll()

        for i in 0 ..< targetSegments.count {
            let timeStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)

            if firstPass == false,
               targetSegments[i].startDate <= predictionEndTime
            {
                let startDot = targetGraphStruct(targetHigh: targetSegments[i].targetHigh, date: targetSegments[i].startDate)
                targetScheduleData.append(startDot)
                var endDate = targetSegments[i].endDate

                if endDate > predictionEndTime || i == targetSegments.count - 1 {
                    endDate = Double(predictionEndTime)
                }

                let endDot = targetGraphStruct(targetHigh: targetSegments[i].targetHigh, date: endDate)
                targetScheduleData.append(endDot)
            }

            if firstPass == true {
                if timeStart >= targetSegments[i].startDate, timeStart < targetSegments[i].endDate {
                    let startDot = targetGraphStruct(targetHigh: targetSegments[i].targetHigh, date: Double(timeStart + (60 * 5)))
                    targetScheduleData.append(startDot)

                    let endDate = targetSegments[i].endDate
                    let endDot = targetGraphStruct(targetHigh: targetSegments[i].targetHigh, date: endDate)
                    targetScheduleData.append(endDot)
                    firstPass = false
                }
            }
        }

        if Storage.shared.graphTargetLine.value {
            updateTargetScheduledGraph()
        }
    }
}
