// LoopFollow
// InfoManager.swift
// Created by Jonas Björkert.

import Foundation
import HealthKit
import UIKit

class InfoManager {
    var tableData: [InfoData]
    weak var tableView: UITableView?

    init(tableView: UITableView) {
        tableData = InfoType.allCases.map { InfoData(name: $0.name) }
        self.tableView = tableView
    }

    func updateInfoData(type: InfoType, value: String) {
        tableData[type.rawValue].value = value
        tableView?.reloadData()
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
        tableView?.reloadData()
    }

    func clearInfoData(types: [InfoType]) {
        for type in types {
            tableData[type.rawValue].value = ""
        }
        tableView?.reloadData()
    }

    func numberOfRows() -> Int {
        return Storage.shared.infoSort.value.filter { Storage.shared.infoVisible.value[$0] }.count
    }

    func dataForIndexPath(_ indexPath: IndexPath) -> InfoData? {
        let sortedAndVisibleIndexes = Storage.shared.infoSort.value.filter { Storage.shared.infoVisible.value[$0] }

        guard indexPath.row < sortedAndVisibleIndexes.count else {
            return nil
        }

        let infoIndex = sortedAndVisibleIndexes[indexPath.row]

        guard infoIndex < tableData.count else {
            return nil
        }

        return tableData[infoIndex]
    }
}
