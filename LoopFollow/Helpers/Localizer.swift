// LoopFollow
// Localizer.swift
// Created by Jon Fawcett.

import Foundation
import HealthKit

class Localizer {
    static func getPreferredUnit() -> HKUnit {
        let unitString = Storage.shared.units.value
        switch unitString {
        case "mmol/L":
            return .millimolesPerLiter
        default:
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

        let units = unit ?? Storage.shared.units.value

        if units == "mg/dL" {
            numberFormatter.maximumFractionDigits = 0 // No decimal places for mg/dL
        } else {
            numberFormatter.maximumFractionDigits = 1 // Always one decimal place for mmol/L
            numberFormatter.minimumFractionDigits = 1 // This ensures even .0 is displayed
        }

        numberFormatter.locale = Locale.current

        let numberValue = NSNumber(value: value)
        return numberFormatter.string(from: numberValue) ?? String(value)
    }

    static func toDisplayUnits(_ value: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        if Storage.shared.units.value == "mg/dL" {
            numberFormatter.maximumFractionDigits = 0 // No decimal places for mg/dL
        } else {
            numberFormatter.maximumFractionDigits = 1 // Always one decimal place for mmol/L
            numberFormatter.minimumFractionDigits = 1 // This ensures even .0 is displayed
        }

        numberFormatter.locale = Locale.current

        if let number = Float(value) {
            if Storage.shared.units.value == "mg/dL" {
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
