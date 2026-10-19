// LoopFollow
// WatchStateBuilder.swift

import Foundation
import HealthKit

/// Collects the phone's current data into the state the watch renders.
enum WatchStateBuilder {
    /// History sent to the watch; the watch chart scrolls back this far.
    static let historyWindow: TimeInterval = 24 * 3600

    static func build(now: Date = Date()) -> WatchState {
        let thresholds = UnitSettingsStore.shared.effectiveThresholds()
        let vc = MainViewController.shared
        let cutoff = now.timeIntervalSince1970 - historyWindow

        let readings = (vc?.bgData ?? [])
            .filter { $0.date >= cutoff && $0.sgv > 0 }
            .map { WatchReading(t: $0.date, v: Double($0.sgv)) }

        let boluses = ((vc?.bolusData ?? []) + (vc?.smbData ?? []))
            .filter { $0.date >= cutoff }
            .map { WatchReading(t: $0.date, v: $0.value) }
            .sorted { $0.t < $1.t }

        let carbs = (vc?.carbData ?? [])
            .filter { $0.date >= cutoff }
            .map { WatchReading(t: $0.date, v: $0.value) }

        var predictions: [WatchPredictionLine] = []
        if let vc {
            let lines: [(WatchPredictionLine.Kind, [ShareGlucoseData])] = [
                (.loop, vc.predictionData),
                (.zt, vc.ztPredictionData),
                (.iob, vc.iobPredictionData),
                (.cob, vc.cobPredictionData),
                (.uam, vc.uamPredictionData),
            ]
            for (kind, data) in lines where !data.isEmpty {
                predictions.append(WatchPredictionLine(kind: kind, points: data.map { WatchReading(t: $0.date, v: Double($0.sgv)) }))
            }
        }

        let cone = (vc?.chartModel.cone ?? []).map {
            WatchConePoint(t: $0.date.timeIntervalSince1970, low: $0.yMin, high: $0.yMax)
        }

        let lastLoop = Observable.shared.alertLastLoopTime.value.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }

        return WatchState(
            builtAt: now,
            snapshot: GlucoseSnapshotBuilder.build(from: StorageCurrentGlucoseStateProvider()),
            readings: readings,
            predictions: predictions,
            cone: cone,
            boluses: boluses,
            carbs: carbs,
            lowMgdl: thresholds.low,
            highMgdl: thresholds.high,
            colorBGText: Storage.shared.colorBGText.value,
            lastLoopAt: lastLoop,
            device: Storage.shared.device.value,
            alarm: currentAlarm(),
            remote: remoteConfig()
        )
    }

    private static func currentAlarm() -> WatchAlarm? {
        guard let id = Observable.shared.currentAlarm.value,
              let alarm = Storage.shared.alarms.value.first(where: { $0.id == id })
        else { return nil }
        return WatchAlarm(id: id, name: alarm.name)
    }

    // MARK: - Remote

    static func remoteKind() -> WatchRemoteConfig.Kind? {
        switch Storage.shared.remoteType.value {
        case .loopAPNS:
            return Storage.shared.device.value == "Loop" ? .loop : nil
        case .trc:
            return Storage.shared.device.value == "Trio" ? .trio : nil
        case .none:
            return nil
        }
    }

    private static func remoteConfig() -> WatchRemoteConfig? {
        guard Storage.shared.watchRemoteCommands.value, let kind = remoteKind() else { return nil }

        let maxBolus = Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit())
        let bolusIncrement = max(0.001, Storage.shared.bolusIncrement.value.doubleValue(for: .internationalUnit()))
        let maxCarbs = Storage.shared.maxCarbs.value.doubleValue(for: .gram())
        let mealWithFatProtein = kind == .trio && Storage.shared.mealWithFatProtein.value
        let now = Date()

        let recommendedAt: TimeInterval? = kind == .trio
            ? Observable.shared.enactedOrSuggested.value
            : Observable.shared.alertLastLoopTime.value

        return WatchRemoteConfig(
            kind: kind,
            maxBolus: maxBolus,
            bolusIncrement: bolusIncrement,
            maxCarbs: maxCarbs,
            maxFat: Storage.shared.maxFat.value.doubleValue(for: .gram()),
            maxProtein: Storage.shared.maxProtein.value.doubleValue(for: .gram()),
            mealWithBolus: kind == .trio && Storage.shared.mealWithBolus.value,
            mealWithFatProtein: mealWithFatProtein,
            recommendedBolus: Observable.shared.deviceRecBolus.value,
            recommendedBolusAt: recommendedAt.map { Date(timeIntervalSince1970: $0) },
            overridePresets: kind == .trio ? trioOverridePresets() : loopOverridePresets(),
            tempTargetPresets: kind == .trio ? tempTargetPresets() : [],
            quickPickBoluses: QuickPickBolusesManager.computeQuickPickBoluses(
                from: Storage.shared.remoteBolusHistory.value,
                now: now,
                stepIncrement: bolusIncrement,
                maxBolus: maxBolus
            ).map(\.units),
            quickPickMeals: QuickPickMealsManager.computeQuickPickMeals(
                from: Storage.shared.remoteMealHistory.value,
                now: now,
                carbStep: 1,
                maxCarbs: maxCarbs,
                includeFatProtein: mealWithFatProtein
            ).map { WatchMealPick(carbs: $0.carbs, fat: $0.fat, protein: $0.protein, bolus: $0.bolus) }
        )
    }

    private static func loopOverridePresets() -> [WatchPreset] {
        ProfileManager.shared.loopOverrides.map { override in
            var parts: [String] = []
            if override.insulinNeedsScaleFactor != 1 {
                parts.append("\(Int(round(override.insulinNeedsScaleFactor * 100))) %")
            }
            if override.targetRange.count >= 2 {
                let low = Localizer.formatQuantity(override.targetRange[0])
                let high = Localizer.formatQuantity(override.targetRange[1])
                parts.append(low == high ? low : "\(low)–\(high)")
            }
            parts.append(durationText(seconds: TimeInterval(override.duration ?? 0)))
            let symbol = override.symbol.isEmpty ? "" : "\(override.symbol) "
            return WatchPreset(id: override.name, name: symbol + override.name, detail: parts.joined(separator: ", "))
        }
    }

    private static func trioOverridePresets() -> [WatchPreset] {
        ProfileManager.shared.trioOverrides.map { override in
            var parts: [String] = []
            if let percentage = override.percentage {
                parts.append("\(Int(percentage)) %")
            }
            if let target = override.target {
                parts.append(Localizer.formatQuantity(target))
            }
            parts.append(durationText(seconds: (override.duration ?? 0) * 60))
            return WatchPreset(id: override.name, name: override.name, detail: parts.joined(separator: ", "))
        }
    }

    private static func tempTargetPresets() -> [WatchPreset] {
        TempTargetPresetManager.shared.presets.map { preset in
            let target = Localizer.formatQuantity(preset.target)
            let duration = durationText(seconds: preset.duration.doubleValue(for: .second()))
            return WatchPreset(id: preset.id.uuidString, name: preset.name, detail: "\(target), \(duration)")
        }
    }

    private static func durationText(seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "Indefinite" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0, minutes > 0 { return "\(hours) h \(minutes) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(minutes) min"
    }
}
