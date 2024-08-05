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
        form.removeAll()  // Clear any existing form to ensure we start fresh
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

            // Iterate through the current infoSort array to set up UI elements
            for i in 0..<UserDefaultsRepository.infoSort.value.count {
                let sortedIndex = UserDefaultsRepository.infoSort.value[i]

                // Ensure sortedIndex is valid and maps to an InfoType
                if let infoType = InfoType(rawValue: sortedIndex) {
                    $0 <<< TextRow() { row in
                        if UserDefaultsRepository.infoVisible.value[sortedIndex] {
                            row.title = "\u{2713}\t\(infoType.name)"
                        } else {
                            row.title = "\u{2001}\t\(infoType.name)"
                        }
                    }.onCellSelection { [weak self] (cell, row) in
                        guard let self = self else { return }

                        let i = row.indexPath!.row
                        let sortedIndex = UserDefaultsRepository.infoSort.value[i]

                        // Toggle visibility directly
                        UserDefaultsRepository.infoVisible.value[sortedIndex] = !UserDefaultsRepository.infoVisible.value[sortedIndex]

                        // Reload the entire table to reflect changes
                        self.tableView.reloadData()
                    }.cellSetup { (cell, row) in
                        cell.textField.isUserInteractionEnabled = false
                    }.cellUpdate { [weak self] (cell, row) in
                        guard let self = self else { return }

                        let i = row.indexPath!.row
                        let sortedIndex = UserDefaultsRepository.infoSort.value[i]

                        if UserDefaultsRepository.infoVisible.value[sortedIndex] {
                            row.title = "\u{2713}\t\(infoType.name)"
                        } else {
                            row.title = "\u{2001}\t\(infoType.name)"
                        }

                        self.appStateController!.infoDataSettingsChanged = true
                    }
                } else {
                    print("Warning: sortedIndex \(sortedIndex) does not map to a valid InfoType!")
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

        // Update sort order if there's a move
        if destIndex != sourceIndex {
            self.appStateController!.infoDataSettingsChanged = true

            let tmpVal = UserDefaultsRepository.infoSort.value[sourceIndex]
            UserDefaultsRepository.infoSort.value.remove(at: sourceIndex)
            UserDefaultsRepository.infoSort.value.insert(tmpVal, at: destIndex)
        }
    }
}
