// LoopFollow
// InfoManager.swift

import Combine
import Foundation
import HealthKit

class InfoManager: ObservableObject {
    @Published var tableData: [InfoData]

    init() {
        tableData = InfoType.allCases.map { InfoData(id: $0.rawValue, name: $0.name) }
    }

    func updateInfoData(type: InfoType, value: String, numericValue: Double? = nil) {
        tableData[type.rawValue].value = value
        tableData[type.rawValue].numericValue = numericValue
        objectWillChange.send()
    }

    func updateInfoData(type: InfoType, value: HKQuantity) {
        let formattedValue = Localizer.formatQuantity(value)
        let numericValue = value.doubleValue(for: Localizer.getPreferredUnit())
        updateInfoData(type: type, value: formattedValue, numericValue: numericValue)
    }

    func updateInfoData(type: InfoType, firstValue: HKQuantity, secondValue: HKQuantity, separator: InfoDataSeparator) {
        let formattedFirstValue = Localizer.formatQuantity(firstValue)
        let formattedSecondValue = Localizer.formatQuantity(secondValue)
        if formattedFirstValue != formattedSecondValue {
            let combinedValue = "\(formattedFirstValue) \(separator.rawValue) \(formattedSecondValue)"
            updateInfoData(type: type, value: combinedValue)
        } else {
            updateInfoData(type: type, value: formattedFirstValue)
        }
    }

    func updateInfoData(type: InfoType, value: Double, maxFractionDigits: Int = 1, minFractionDigits: Int = 0) {
        let formattedValue = Localizer.formatToLocalizedString(value, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
        updateInfoData(type: type, value: formattedValue, numericValue: value)
    }

    func updateInfoData(type: InfoType, value: Double, enactedValue: Double, separator: InfoDataSeparator, maxFractionDigits: Int = 1, minFractionDigits: Int = 0) {
        let formattedValue = Localizer.formatToLocalizedString(value, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
        let formattedEnactedValue = Localizer.formatToLocalizedString(enactedValue, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
        let separatorString = separator.rawValue
        let combinedValue = "\(formattedValue) \(separatorString) \(formattedEnactedValue)"
        updateInfoData(type: type, value: combinedValue)
    }

    func updateInfoData(type: InfoType, value: Metric) {
        let formattedValue = value.formattedValue()
        updateInfoData(type: type, value: formattedValue, numericValue: value.value)
    }

    /// Insulin activity in U/h.
    func updateInsulinActivity(_ value: Double) {
        updateInfoData(type: .insulinActivity, value: Self.insulinActivityText(value), numericValue: value)
    }

    static func insulinActivityText(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return Localizer.formatToLocalizedString(rounded == 0 ? 0 : rounded, maxFractionDigits: 1, minFractionDigits: 0) + "U/h"
    }

    func clearInfoData(type: InfoType) {
        tableData[type.rawValue].value = ""
        tableData[type.rawValue].numericValue = nil
        objectWillChange.send()
    }

    func clearInfoData(types: [InfoType]) {
        for type in types {
            tableData[type.rawValue].value = ""
            tableData[type.rawValue].numericValue = nil
        }
        objectWillChange.send()
    }

    var visibleRows: [InfoData] {
        Storage.shared.infoDisplayItems.value
            .filter { $0.isVisible }
            .compactMap { item in
                let index = item.type.rawValue
                guard index < tableData.count else { return nil }
                return tableData[index]
            }
    }
}
