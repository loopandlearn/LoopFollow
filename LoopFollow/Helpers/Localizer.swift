//
//  Units.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/22/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit

class Localizer {
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
        let unitPreference = UserDefaultsRepository.units.value

        if unitPreference == "mg/dL" {
            let valueInMgdL = quantity.doubleValue(for: .milligramsPerDeciliter)
            return formatToLocalizedString(valueInMgdL, maxFractionDigits: 0, minFractionDigits: 0)
        } else {
            let valueInMmolL = quantity.doubleValue(for: .millimolesPerLiter)
            return formatToLocalizedString(valueInMmolL, maxFractionDigits: 1, minFractionDigits: 1)
        }
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

        let units = unit ?? UserDefaultsRepository.units.value

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
        
        if UserDefaultsRepository.units.value == "mg/dL" {
            numberFormatter.maximumFractionDigits = 0 // No decimal places for mg/dL
        } else {
            numberFormatter.maximumFractionDigits = 1 // Always one decimal place for mmol/L
            numberFormatter.minimumFractionDigits = 1 // This ensures even .0 is displayed
        }
        
        numberFormatter.locale = Locale.current
        
        if let number = Float(value) {
            if UserDefaultsRepository.units.value == "mg/dL" {
                let numberValue = NSNumber(value: number)
                return numberFormatter.string(from: numberValue) ?? value
            } else {
                let mmolValue = Double(number) * GlucoseConversion.mgDlToMmolL  // Convert number to Double
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
        return self.truncatingRemainder(dividingBy: 1) == 0
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
