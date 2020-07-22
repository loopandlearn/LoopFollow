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
        if UserDefaultsRepository.units.value == "mg/dL" {
            return removeDecimals(value)
        } else {
            // convert mg/dL to mmol/l
            let floatValue : Float = Float(value)! * 0.0555
            return String(floatValue.cleanValue)
        }
    }
    
    static func toFloat(_ value: Float) -> Float {
       if UserDefaultsRepository.units.value == "mg/dL" {
            return value
        } else {
            // convert mg/dL to mmol/l
            let mmolValue : Float = Float(value) * 0.0555
            return mmolValue
        }
    }
    
    static func toFloat(_ value: Int) -> Float {
       if UserDefaultsRepository.units.value == "mg/dL" {
            return Float(value)
        } else {
            // convert mg/dL to mmol/l
            let mmolValue : Float = Float(value) * 0.0555
            return mmolValue
        }
    }
    
    // if a "." is contained, simply takes the left part of the string only
    static func removeDecimals(_ value : String) -> String {
        if !value.contains(".") {
            return value
        }
        
        return String(value[..<value.firstIndex(of: ".")!])
    }
    
    static func removePeriodForBadge(_ value: String) -> String {
        return value.replacingOccurrences(of: ".", with: "")
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
