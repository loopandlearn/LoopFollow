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

        let basalDataInPeriod = dataService.getBasalData()
        let totalBasalOverPeriod = calculateTotalBasal(basalData: basalDataInPeriod)

        let basalDates = basalDataInPeriod.map { $0.date }.filter { $0 >= cutoffTime }
        let actualBasalDays = calculateActualDaysCovered(dates: basalDates, requestedDays: dataService.daysToAnalyze)

        var avgDailyBolus = 0.0
        var avgDailyBasal = 0.0

        if actualDays > 0 {
            avgDailyBolus = totalBolusInPeriod / Double(actualDays)
        }

        if actualBasalDays > 0 {
            avgDailyBasal = totalBasalOverPeriod / Double(actualBasalDays)
            actualBasal = avgDailyBasal
        } else {
            actualBasal = nil
        }

        if actualDays > 0 || actualBasalDays > 0 {
            totalDailyDose = avgDailyBolus + avgDailyBasal
        } else {
            totalDailyDose = nil
        }

        let basalProfile = dataService.getBasalProfile()
        programmedBasal = calculateProgrammedBasalFromProfile(basalProfile: basalProfile)
    }

    private func calculateTotalBasal(basalData: [MainViewController.basalGraphStruct]) -> Double {
        guard !basalData.isEmpty else { return 0.0 }

        var totalBasal = 0.0
        let cutoffTime = Date().timeIntervalSince1970 - (Double(dataService.daysToAnalyze) * 24 * 60 * 60)
        let now = Date().timeIntervalSince1970

        let basalProfile = dataService.getBasalProfile()

        let sortedBasal = basalData.sorted { $0.date < $1.date }

        for i in 0 ..< sortedBasal.count {
            let current = sortedBasal[i]
            let startTime = max(current.date, cutoffTime)

            let endTime: TimeInterval
            if i < sortedBasal.count - 1 {
                endTime = min(sortedBasal[i + 1].date, now)
            } else {
                endTime = now
            }

            if endTime > startTime {
                let durationHours = (endTime - startTime) / 3600.0

                let scheduledBasalRate = getScheduledBasalRate(for: startTime, profile: basalProfile)

                let adjustment = current.basalRate - scheduledBasalRate

                totalBasal += scheduledBasalRate * durationHours
                totalBasal += adjustment * durationHours
            }
        }

        return totalBasal
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
