//
//  InfoManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-11.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

class InfoManager {
    var tableData: [InfoData]
    weak var tableView: UITableView?

    init(tableView: UITableView) {
        self.tableData = InfoType.allCases.map { InfoData(name: $0.name) }
        self.tableView = tableView
    }

    func updateInfoData(type: InfoType, value: String) {
        tableData[type.rawValue].value = value
        tableView?.reloadData()
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
        return UserDefaultsRepository.infoSort.value.filter { UserDefaultsRepository.infoVisible.value[$0] }.count
    }

    func dataForIndexPath(_ indexPath: IndexPath) -> InfoData {
        let sortedAndVisibleIndexes = UserDefaultsRepository.infoSort.value.filter { UserDefaultsRepository.infoVisible.value[$0] }
        let infoIndex = sortedAndVisibleIndexes[indexPath.row]
        return tableData[infoIndex]
    }
}
