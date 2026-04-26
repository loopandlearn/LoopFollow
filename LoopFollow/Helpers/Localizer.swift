// LoopFollow
// Localizer.swift

import Foundation
import HealthKit

enum GlucoseDisplayUnit: String, Codable, CaseIterable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"

    var fractionDigits: Int {
        switch self {
        case .mgdL:
            return 0
        case .mmolL:
            return 1
        }
    }
}

enum TimeInRangeDisplayMode: String, Codable, CaseIterable {
    case tir = "TIR"
    case titr = "TITR"
    case custom = "Custom"
}

enum GlycemicMetricMode: String, Codable, CaseIterable {
    case ehba1c = "eHbA1c"
    case gmi = "GMI"
}

enum GlycemicOutputUnit: String, Codable, CaseIterable {
    case percent = "%"
    case mmolMol = "mmol/mol"
}

enum VariabilityMetricMode: String, Codable, CaseIterable {
    case stdDeviation = "Std Deviation"
    case cv = "CV"
}

final class UnitSettingsStore {
    static let shared = UnitSettingsStore()

    private init() {}

    var glucoseUnit: GlucoseDisplayUnit {
        get {
            GlucoseDisplayUnit(rawValue: Storage.shared.units.value) ?? .mgdL
        }
        set {
            Storage.shared.units.value = newValue.rawValue
        }
    }

    var timeInRangeMode: TimeInRangeDisplayMode {
        get {
            TimeInRangeDisplayMode(rawValue: Storage.shared.timeInRangeModeRaw.value) ?? .tir
        }
        set {
            Storage.shared.timeInRangeModeRaw.value = newValue.rawValue
        }
    }

    /// Returns the effective low/high thresholds (in mg/dL) for the current range mode.
    func effectiveThresholds() -> (low: Double, high: Double) {
        switch timeInRangeMode {
        case .tir:
            return (70.0, 180.0)
        case .titr:
            return (70.0, 140.0)
        case .custom:
            return (Storage.shared.lowLine.value, Storage.shared.highLine.value)
        }
    }

    var glycemicMetricMode: GlycemicMetricMode {
        get {
            Storage.shared.showGMI.value ? .gmi : .ehba1c
        }
        set {
            Storage.shared.showGMI.value = (newValue == .gmi)
        }
    }

    var glycemicOutputUnit: GlycemicOutputUnit {
        get {
            Storage.shared.useIFCC.value ? .mmolMol : .percent
        }
        set {
            Storage.shared.useIFCC.value = (newValue == .mmolMol)
        }
    }

    var variabilityMetricMode: VariabilityMetricMode {
        get {
            Storage.shared.showStdDev.value ? .stdDeviation : .cv
        }
        set {
            Storage.shared.showStdDev.value = (newValue == .stdDeviation)
        }
    }

    func convertMgdlToDisplay(_ mgdl: Double) -> Double {
        switch glucoseUnit {
        case .mgdL:
            return mgdl
        case .mmolL:
            return mgdl * GlucoseConversion.mgDlToMmolL
        }
    }

    func convertDisplayToMgdl(_ value: Double) -> Double {
        switch glucoseUnit {
        case .mgdL:
            return value
        case .mmolL:
            return value * GlucoseConversion.mmolToMgDl
        }
    }
}

enum GlycemicMetricCalculator {
    static func calculateEhba1c(avgGlucoseInDisplayUnits: Double?) -> Double? {
        guard let avgGlucoseInDisplayUnits else { return nil }

        switch UnitSettingsStore.shared.glycemicOutputUnit {
        case .mmolMol:
            let avgMmolL = UnitSettingsStore.shared.glucoseUnit == .mmolL
                ? avgGlucoseInDisplayUnits
                : avgGlucoseInDisplayUnits * GlucoseConversion.mgDlToMmolL
            return avgMmolL * 6.936514699616532 - 6.628248828291433
        case .percent:
            let avgMgdL = UnitSettingsStore.shared.convertDisplayToMgdl(avgGlucoseInDisplayUnits)
            return (avgMgdL + 46.7) / 28.7
        }
    }

    static func calculateGMI(avgGlucoseInDisplayUnits: Double?) -> Double? {
        guard let avgGlucoseInDisplayUnits else { return nil }

        switch UnitSettingsStore.shared.glycemicOutputUnit {
        case .percent:
            let avgMgdL = UnitSettingsStore.shared.convertDisplayToMgdl(avgGlucoseInDisplayUnits)
            return 3.31 + (0.02392 * avgMgdL)
        case .mmolMol:
            let avgMmolL = UnitSettingsStore.shared.glucoseUnit == .mmolL
                ? avgGlucoseInDisplayUnits
                : avgGlucoseInDisplayUnits * GlucoseConversion.mgDlToMmolL
            return 12.71 + (4.70587 * avgMmolL)
        }
    }
}

class Localizer {
    static func getPreferredUnit() -> HKUnit {
        switch UnitSettingsStore.shared.glucoseUnit {
        case .mmolL:
            return .millimolesPerLiter
        case .mgdL:
            return .milligramsPerDeciliter
        }
    }

    static func formatToLocalizedString(_ value: Double, maxFractionDigits: Int = 1, minFractionDigits: Int = 0) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = maxFractionDigits
        numberFormatter.minimumFractionDigits = minFractionDigits
        numberFormatter.locale = Locale.current

        let numberValue = NSNumber(value: value)
        return numberFormatter.string(from: numberValue) ?? String(value)
    }

    static func formatQuantity(_ quantity: HKQuantity) -> String {
        let unit: HKUnit = getPreferredUnit()
        let value = quantity.doubleValue(for: unit)

        return formatToLocalizedString(value, maxFractionDigits: unit.preferredFractionDigits, minFractionDigits: unit.preferredFractionDigits)
    }

    static func formatQuantity(_ value: Double) -> String {
        formatQuantity(HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value))
    }

    static func formatTimestampToLocalString(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("jms")
        dateFormatter.locale = Locale.current
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }

    static func formatLocalDouble(_ value: Double, unit: String? = nil) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        let units = GlucoseDisplayUnit(rawValue: unit ?? UnitSettingsStore.shared.glucoseUnit.rawValue) ?? .mgdL
        numberFormatter.maximumFractionDigits = units.fractionDigits
        numberFormatter.minimumFractionDigits = units.fractionDigits

        numberFormatter.locale = Locale.current

        let numberValue = NSNumber(value: value)
        return numberFormatter.string(from: numberValue) ?? String(value)
    }

    static func toDisplayUnits(_ value: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let units = UnitSettingsStore.shared.glucoseUnit
        numberFormatter.maximumFractionDigits = units.fractionDigits
        numberFormatter.minimumFractionDigits = units.fractionDigits

        numberFormatter.locale = Locale.current

        if let number = Float(value) {
            if units == .mgdL {
                let numberValue = NSNumber(value: number)
                return numberFormatter.string(from: numberValue) ?? value
            } else {
                let mmolValue = Double(number) * GlucoseConversion.mgDlToMmolL // Convert number to Double
                let numberValue = NSNumber(value: mmolValue)
                return numberFormatter.string(from: numberValue) ?? value
            }
        }

        return value
    }

    static func removePeriodAndCommaForBadge(_ value: String) -> String {
        var modifiedValue = value
        modifiedValue = modifiedValue.replacingOccurrences(of: ".", with: "")
        modifiedValue = modifiedValue.replacingOccurrences(of: ",", with: "")
        return modifiedValue
    }
}

extension Float {
    // remove the decimal part of the float if it is ".0" and trim whitespaces
    var cleanValue: String {
        return truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%5.0f", self).trimmingCharacters(in: CharacterSet.whitespaces)
            : String(format: "%5.1f", self).trimmingCharacters(in: CharacterSet.whitespaces)
    }

    var roundTo3f: Float {
        return round(to: 3)
    }

    func round(to places: Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (divisor * self).rounded() / divisor
    }
}
