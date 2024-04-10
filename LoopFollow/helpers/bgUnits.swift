//
//  Units.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/22/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


class bgUnits {
    
    static func toDisplayUnits(_ value: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = UserDefaultsRepository.units.value == "mg/dL" ? 0 : 1
        numberFormatter.locale = Locale.current
        
        if UserDefaultsRepository.units.value == "mg/dL" {
            if let number = Float(value) {
                let numberValue = NSNumber(value: number)
                return numberFormatter.string(from: numberValue) ?? value
            }
        } else {
            if let number = Float(value) {
                let mmolValue = number / 18
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
