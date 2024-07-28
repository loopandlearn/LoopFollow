//
//  HKQuantity+AnyConvertible.swift
//  nightguard
//
//  Created by Jonas Björkert on 2024-07-24.
//

import HealthKit

class HKQuantityWrapper: AnyConvertible {
    let quantity: HKQuantity

    init(quantity: HKQuantity) {
        self.quantity = quantity
    }

    func toAny() -> Any {
        return ["unit": UserDefaultsRepository.getPreferredUnit().unitString,
                "value": quantity.doubleValue(for: UserDefaultsRepository.getPreferredUnit())]
    }

    static func fromAny(_ anyValue: Any) -> HKQuantityWrapper? {
        // Convert dictionary back to HKQuantity
        guard let dict = anyValue as? [String: Any],
              let unitString = dict["unit"] as? String,
              let value = dict["value"] as? Double else {
            return nil
        }

        let unit = HKUnit(from: unitString)
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        return HKQuantityWrapper(quantity: quantity)
    }
}
