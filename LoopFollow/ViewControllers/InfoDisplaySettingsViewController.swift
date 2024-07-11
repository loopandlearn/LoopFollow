//
//  InfoDisplaySettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka
import EventKit
import EventKitUI

class InfoDisplaySettingsViewController: FormViewController {
    var appStateController: AppStateController?

    override func viewDidLoad() {
        print("Display Load")
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        createForm()
    }

    private func createForm() {
        form
        +++ Section("General")
        <<< SwitchRow("hideInfoTable"){ row in
            row.title = "Hide Information Table"
            row.tag = "hideInfoTable"
            row.value = UserDefaultsRepository.hideInfoTable.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.hideInfoTable.value = value
        }

        +++ MultivaluedSection(multivaluedOptions: .Reorder, header: "Information Display Settings", footer: "Arrange/Enable Information Desired") {

            $0.tag = "InfoDisplay"

            for i in 0..<UserDefaultsRepository.infoSort.value.count {
                let sortedIndex = UserDefaultsRepository.infoSort.value[i]
                let infoType = InfoType(rawValue: sortedIndex)!

                $0 <<< TextRow() { row in
                    if(UserDefaultsRepository.infoVisible.value[sortedIndex]) {
                        row.title = "\u{2713}\t\(infoType.name)"
                    } else {
                        row.title = "\u{2001}\t\(infoType.name)"
                    }
                }.onCellSelection { (cell, row) in
                    let i = row.indexPath!.row
                    let sortedIndex = UserDefaultsRepository.infoSort.value[i]
                    UserDefaultsRepository.infoVisible.value[sortedIndex] = !UserDefaultsRepository.infoVisible.value[sortedIndex]

                    self.tableView.reloadData()
                }.cellSetup { (cell, row) in
                    cell.textField.isUserInteractionEnabled = false
                }.cellUpdate { (cell, row) in
                    let sortedIndex = UserDefaultsRepository.infoSort.value[i]
                    if(UserDefaultsRepository.infoVisible.value[sortedIndex]) {
                        row.title = "\u{2713}\t\(infoType.name)"
                    } else {
                        row.title = "\u{2001}\t\(infoType.name)"
                    }
                    self.appStateController!.infoDataSettingsChanged = true
                }
            }
        }

        +++ ButtonRow() {
            $0.title = "DONE"
        }.onCellSelection { (row, arg)  in
            self.dismiss(animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let sourceIndex = sourceIndexPath.row
        let destIndex = destinationIndexPath.row

        // new sort
        if(destIndex != sourceIndex ) {
            self.appStateController!.infoDataSettingsChanged = true

            let tmpVal = UserDefaultsRepository.infoSort.value[sourceIndex]
            UserDefaultsRepository.infoSort.value.remove(at: sourceIndex)
            UserDefaultsRepository.infoSort.value.insert(tmpVal, at: destIndex)
        }
    }
}
