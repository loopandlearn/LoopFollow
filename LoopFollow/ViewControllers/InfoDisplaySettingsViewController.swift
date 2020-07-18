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
        +++ MultivaluedSection(multivaluedOptions: .Reorder, header: "Information Display Settings", footer: "Arrage/Enable Information Desired") {
        
           // TODO: add the other display values
           $0.tag = "InfoDisplay"
           
            for i in 0..<UserDefaultsRepository.infoNames.value.count {
              $0 <<< TextRow() { row in
                if(UserDefaultsRepository.infoVisible.value[UserDefaultsRepository.infoSort.value[i]]) {
                    row.title = "\u{2713}\t\(UserDefaultsRepository.infoNames.value[UserDefaultsRepository.infoSort.value[i]])"
                 } else {
                    row.title = "\u{2001}\t\(UserDefaultsRepository.infoNames.value[UserDefaultsRepository.infoSort.value[i]])"
                 }
              }.onCellSelection{(cell, row) in
                let i = row.indexPath!.row
                UserDefaultsRepository.infoVisible.value[UserDefaultsRepository.infoSort.value[i]] = !UserDefaultsRepository.infoVisible.value[UserDefaultsRepository.infoSort.value[i]]
                
                self.tableView.reloadData()
                
                //print("\(row.title)")
                //print("\(row.indexPath?.row)")
              }.cellSetup { (cell, row) in
                 cell.textField.isUserInteractionEnabled = false
              }.cellUpdate{ (cell, row) in
                if(UserDefaultsRepository.infoVisible.value[UserDefaultsRepository.infoSort.value[i]]) {
                    row.title = "\u{2713}\t\(UserDefaultsRepository.infoNames.value[UserDefaultsRepository.infoSort.value[i]])"
                 } else {
                    row.title = "\u{2001}\t\(UserDefaultsRepository.infoNames.value[UserDefaultsRepository.infoSort.value[i]])"
                 }
                 self.appStateController!.infoDataSettingsChanged = true
              }
           }
       }
    
       +++ ButtonRow() {
          $0.title = "DONE"
       }.onCellSelection { (row, arg)  in
          self.dismiss(animated:true, completion: nil)
       }
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        //let view = tableView
        let sourceIndex = sourceIndexPath.row
        let destIndex = destinationIndexPath.row
        
        // new sort
        if(destIndex != sourceIndex ) {
           self.appStateController!.infoDataSettingsChanged = true
           
            let tmpVal = UserDefaultsRepository.infoSort.value[sourceIndex]
            UserDefaultsRepository.infoSort.value.remove(at:sourceIndex)
            UserDefaultsRepository.infoSort.value.insert(tmpVal, at:destIndex)
       
        }
        
    }
 }
