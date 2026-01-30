// LoopFollow
// SimpleStatsViewModel.swift

import Combine
import Foundation

class SimpleStatsViewModel: ObservableObject {
    @Published var gmi: Double?
    @Published var avgGlucose: Double?
    @Published var stdDeviation: Double?
    @Published var coefficientOfVariation: Double?
    @Published var totalDailyDose: Double?
    @Published var programmedBasal: Double?
    @Published var actualBasal: Double?
    @Published var avgBolus: Double?
    @Published var avgCarbs: Double?

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
    }

    func calculateStats() {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else { return }

        let totalGlucose = bgData.reduce(0) { $0 + $1.sgv }
        let avgBGmgdL = Double(totalGlucose) / Double(bgData.count)
        avgGlucose = Storage.shared.units.value == "mg/dL" ? avgBGmgdL : avgBGmgdL * GlucoseConversion.mgDlToMmolL

        let variance = bgData.reduce(0.0) { sum, reading in
            let diff = Double(reading.sgv) - avgBGmgdL
            return sum + (diff * diff)
        }
        let stdDevMgdL = sqrt(variance / Double(bgData.count))
        stdDeviation = Storage.shared.units.value == "mg/dL" ? stdDevMgdL : stdDevMgdL * GlucoseConversion.mgDlToMmolL

        gmi = 3.31 + (0.02392 * avgBGmgdL)

        if avgBGmgdL > 0 {
            coefficientOfVariation = (stdDevMgdL / avgBGmgdL) * 100.0
        } else {
            coefficientOfVariation = nil
        }

        let bolusesInPeriod = dataService.getBolusData()
        let smbInPeriod = dataService.getSMBData()
        let bolusTotal = bolusesInPeriod.reduce(0.0) { $0 + $1.value }
        let smbTotal = smbInPeriod.reduce(0.0) { $0 + $1.value }
        let totalBolusInPeriod = bolusTotal + smbTotal

        let cutoffTime = Date().timeIntervalSince1970 - (Double(dataService.daysToAnalyze) * 24 * 60 * 60)
        let allBolusDates = (bolusesInPeriod + smbInPeriod).map { $0.date }.filter { $0 >= cutoffTime }
        let actualDays = calculateActualDaysCovered(dates: allBolusDates, requestedDays: dataService.daysToAnalyze)

        if actualDays > 0 {
            avgBolus = totalBolusInPeriod / Double(actualDays)
        } else {
            avgBolus = nil
        }

        let carbsInPeriod = dataService.getCarbData()

        let calendar = Calendar.current
        var dailyCarbs: [Date: Double] = [:]

        for carb in carbsInPeriod {
            let carbDate = Date(timeIntervalSince1970: carb.date)
            let dayStart = calendar.startOfDay(for: carbDate)

            if dailyCarbs[dayStart] == nil {
                dailyCarbs[dayStart] = 0.0
            }
            dailyCarbs[dayStart]? += carb.value
        }

        let totalCarbsInPeriod = dailyCarbs.values.reduce(0.0, +)

        let daysWithData = max(dailyCarbs.count, 1)

        if daysWithData > 0 {
            avgCarbs = totalCarbsInPeriod / Double(daysWithData)
        } else {
            avgCarbs = nil
        }

        let basalProfile = dataService.getBasalProfile()
        let dailyProgrammedBasal = calculateProgrammedBasalFromProfile(basalProfile: basalProfile)
        programmedBasal = dailyProgrammedBasal

        // Calculate actual basal using temp basal adjustments
        let tempBasalData = dataService.getTempBasalData()
        let (totalActualBasal, actualBasalDays) = calculateActualBasalFromTempBasals(
            tempBasals: tempBasalData,
            basalProfile: basalProfile,
            dailyProgrammedBasal: dailyProgrammedBasal
        )

        var avgDailyBolus = 0.0
        var avgDailyBasal = 0.0

        if actualDays > 0 {
            avgDailyBolus = totalBolusInPeriod / Double(actualDays)
        }

        if actualBasalDays > 0 {
            avgDailyBasal = totalActualBasal / Double(actualBasalDays)
            actualBasal = avgDailyBasal
        } else {
            actualBasal = nil
        }

        if actualDays > 0 || actualBasalDays > 0 {
            totalDailyDose = avgDailyBolus + avgDailyBasal
        } else {
            totalDailyDose = nil
        }
    }

    /// Calculates actual basal delivered using:
    /// Actual = Programmed Basal + Sum of all temp basal adjustments
    /// Where adjustment = (temp_rate - scheduled_rate) * duration
    private func calculateActualBasalFromTempBasals(
        tempBasals: [StatsDataService.TempBasalEntry],
        basalProfile: [MainViewController.basalProfileStruct],
        dailyProgrammedBasal: Double
    ) -> (totalBasal: Double, daysWithData: Int) {
        let cutoffTime = Date().timeIntervalSince1970 - (Double(dataService.daysToAnalyze) * 24 * 60 * 60)
        let now = Date().timeIntervalSince1970

        // Filter temp basals to the analysis period
        let relevantTempBasals = tempBasals.filter { tempBasal in
            let tempEnd = tempBasal.startTime + (tempBasal.durationMinutes * 60)
            return tempEnd > cutoffTime && tempBasal.startTime < now
        }

        guard !relevantTempBasals.isEmpty else {
            // No temp basals - return programmed basal for the period
            return (dailyProgrammedBasal, dataService.daysToAnalyze)
        }

        // Calculate total adjustment from all temp basals
        var totalAdjustment = 0.0

        for tempBasal in relevantTempBasals {
            // Clamp temp basal to analysis window
            let effectiveStart = max(tempBasal.startTime, cutoffTime)
            let effectiveEnd = min(tempBasal.startTime + (tempBasal.durationMinutes * 60), now)

            guard effectiveEnd > effectiveStart else { continue }

            // For each segment of this temp basal, calculate the adjustment
            // We need to handle cases where the temp basal spans multiple profile segments
            totalAdjustment += calculateAdjustmentForTempBasal(
                tempRate: tempBasal.rate,
                startTime: effectiveStart,
                endTime: effectiveEnd,
                profile: basalProfile
            )
        }

        // Calculate days with data
        let calendar = Calendar.current
        var uniqueDays = Set<Date>()
        for tempBasal in relevantTempBasals {
            let dateObj = Date(timeIntervalSince1970: tempBasal.startTime)
            let dayStart = calendar.startOfDay(for: dateObj)
            uniqueDays.insert(dayStart)
        }
        let daysWithData = min(uniqueDays.count, dataService.daysToAnalyze)

        // Actual = Programmed + Adjustments
        let totalActualBasal = (dailyProgrammedBasal * Double(daysWithData)) + totalAdjustment

        return (totalActualBasal, daysWithData)
    }

    /// Calculates the adjustment (positive or negative) for a single temp basal
    /// Adjustment = (temp_rate - scheduled_rate) * duration_hours
    private func calculateAdjustmentForTempBasal(
        tempRate: Double,
        startTime: TimeInterval,
        endTime: TimeInterval,
        profile: [MainViewController.basalProfileStruct]
    ) -> Double {
        guard !profile.isEmpty, endTime > startTime else { return 0.0 }

        var totalAdjustment = 0.0
        let sortedProfile = profile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }
        let calendar = Calendar.current

        var currentTime = startTime
        while currentTime < endTime {
            let currentDate = Date(timeIntervalSince1970: currentTime)
            let dayStart = calendar.startOfDay(for: currentDate).timeIntervalSince1970
            let nextDayStart = dayStart + 24 * 60 * 60

            // Process each profile segment for this day
            for i in 0 ..< sortedProfile.count {
                let scheduledRate = sortedProfile[i].value
                let segmentStartInDay = dayStart + sortedProfile[i].timeAsSeconds

                let segmentEndInDay: TimeInterval
                if i < sortedProfile.count - 1 {
                    segmentEndInDay = dayStart + sortedProfile[i + 1].timeAsSeconds
                } else {
                    segmentEndInDay = nextDayStart
                }

                // Calculate overlap between this profile segment and the temp basal
                let overlapStart = max(currentTime, segmentStartInDay)
                let overlapEnd = min(endTime, segmentEndInDay)

                if overlapEnd > overlapStart {
                    let durationHours = (overlapEnd - overlapStart) / 3600.0
                    // Adjustment = (temp_rate - scheduled_rate) * duration
                    let adjustment = (tempRate - scheduledRate) * durationHours
                    totalAdjustment += adjustment
                }
            }

            // Move to next day
            currentTime = nextDayStart
        }

        return totalAdjustment
    }

    private func getScheduledBasalRate(for time: TimeInterval, profile: [MainViewController.basalProfileStruct]) -> Double {
        guard !profile.isEmpty else { return 0.0 }

        let calendar = Calendar.current
        let date = Date(timeIntervalSince1970: time)
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)

        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        let secondsSinceMidnight = Double(hours * 3600 + minutes * 60 + seconds)

        let sortedProfile = profile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }

        for i in 0 ..< sortedProfile.count {
            let current = sortedProfile[i]
            let nextTime: Double
            if i < sortedProfile.count - 1 {
                nextTime = sortedProfile[i + 1].timeAsSeconds
            } else {
                nextTime = 24 * 60 * 60
            }

            if secondsSinceMidnight >= current.timeAsSeconds && secondsSinceMidnight < nextTime {
                return current.value
            }
        }

        return sortedProfile.first?.value ?? 0.0
    }

    private func calculateActualDaysCovered(dates: [TimeInterval], requestedDays: Int) -> Int {
        guard !dates.isEmpty else { return requestedDays }

        let calendar = Calendar.current
        let cutoffTime = Date().timeIntervalSince1970 - (Double(requestedDays) * 24 * 60 * 60)
        let filteredDates = dates.filter { $0 >= cutoffTime }

        var uniqueDays = Set<Date>()
        for date in filteredDates {
            let dateObj = Date(timeIntervalSince1970: date)
            let dayStart = calendar.startOfDay(for: dateObj)
            uniqueDays.insert(dayStart)
        }

        return min(uniqueDays.count, requestedDays)
    }

    private func calculateProgrammedBasalFromProfile(basalProfile: [MainViewController.basalProfileStruct]) -> Double {
        guard !basalProfile.isEmpty else { return 0.0 }

        let sortedProfile = basalProfile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }

        var totalBasal = 0.0
        let secondsInDay = 24 * 60 * 60

        for i in 0 ..< sortedProfile.count {
            let current = sortedProfile[i]
            let currentTime = Double(current.timeAsSeconds)

            let nextTime: Double
            if i < sortedProfile.count - 1 {
                nextTime = Double(sortedProfile[i + 1].timeAsSeconds)
            } else {
                nextTime = Double(secondsInDay)
            }

            let durationHours = (nextTime - currentTime) / 3600.0
            totalBasal += current.value * durationHours
        }

        return totalBasal
    }
}
