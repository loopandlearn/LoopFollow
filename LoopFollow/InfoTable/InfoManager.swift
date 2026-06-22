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

    func updateInfoData(type: InfoType, value: String) {
        tableData[type.rawValue].value = value
        objectWillChange.send()
    }

    func updateInfoData(type: InfoType, value: HKQuantity) {
        let formattedValue = Localizer.formatQuantity(value)
        updateInfoData(type: type, value: formattedValue)
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
        updateInfoData(type: type, value: formattedValue)
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
        updateInfoData(type: type, value: formattedValue)
    }

    func clearInfoData(type: InfoType) {
        tableData[type.rawValue].value = ""
        objectWillChange.send()
    }

    func clearInfoData(types: [InfoType]) {
        for type in types {
            tableData[type.rawValue].value = ""
        }
        objectWillChange.send()
    }

    var visibleRows: [InfoData] {
        Storage.shared.infoSort.value
            .filter { $0 < Storage.shared.infoVisible.value.count && Storage.shared.infoVisible.value[$0] }
            .compactMap { index in
                guard index < tableData.count else { return nil }
                return tableData[index]
            }
    }
}
