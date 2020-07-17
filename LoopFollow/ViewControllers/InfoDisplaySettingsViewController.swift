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

    var infoNames:   [String] = []
    var infoSort:    [Int]    = []
    var infoVisible: [Bool]   = []
    
    override func viewDidLoad() {
        print("Display Load")
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
         
        // get the info table
        let userDefaults = UserDefaults.standard

        // names
        self.infoNames = userDefaults.stringArray(forKey:InfoNames) ?? [String]()
        if(self.infoNames.count == 0) {
            self.infoNames = DefaultInfoNames
            userDefaults.set(self.infoNames, forKey:InfoNames)
        }
        
        // sort
        self.infoSort = userDefaults.array(forKey:InfoSort) as? [Int] ?? [Int]()
        if(self.infoSort.count != self.infoNames.count) {
            self.infoSort = []
            for i in 0..<self.infoNames.count {
                self.infoSort.append(i)
            }
            userDefaults.set(self.infoSort, forKey:InfoSort)
        }
        // visible
        self.infoVisible = userDefaults.array(forKey:InfoVisible) as? [Bool] ?? [Bool]()
        if(self.infoVisible.count != self.infoNames.count) {
            self.infoVisible = []
            for _ in 0..<self.infoNames.count {
                self.infoVisible.append(true)
            }
            userDefaults.set(self.infoVisible, forKey:InfoVisible)
        }
        createForm()
    }
    
    private func createForm() {
        form
        +++ MultivaluedSection(multivaluedOptions: .Reorder, header: "Information Display Settings", footer: "Arrage/Enable Information Desired") {
        
           // TODO: add the other display values
           $0.tag = "InfoDisplay"
           
            for i in 0..<self.infoNames.count {
              $0 <<< TextRow() { row in
                if(self.infoVisible[self.infoSort[i]]) {
                    row.title = "\u{2713}\t\(self.infoNames[self.infoSort[i]])"
                 } else {
                    row.title = "\u{2001}\t\(self.infoNames[self.infoSort[i]])"
                 }
              }.onCellSelection{(cell, row) in
                let i = row.indexPath!.row
                self.infoVisible[self.infoSort[i]] = !self.infoVisible[self.infoSort[i]]
                
                // save info visible
                UserDefaults.standard.set(self.infoVisible, forKey:InfoVisible)
                
                self.tableView.reloadData()
                
                //print("\(row.title)")
                //print("\(row.indexPath?.row)")
              }.cellSetup { (cell, row) in
                 cell.textField.isUserInteractionEnabled = false
              }.cellUpdate{ (cell, row) in
                 if(self.infoVisible[self.infoSort[i]]) {
                    row.title = "\u{2713}\t\(self.infoNames[self.infoSort[i]])"
                 } else {
                    row.title = "\u{2001}\t\(self.infoNames[self.infoSort[i]])"
                 }
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
        let tmpVal = self.infoSort[sourceIndex]
        self.infoSort.remove(at:sourceIndex)
        self.infoSort.insert(tmpVal, at:destIndex)
       
        // save to defaults
        UserDefaults.standard.set(self.infoSort, forKey:InfoSort)
        
        print("Source Row: \(sourceIndexPath.row); Source Section: \(sourceIndexPath.section)")
        print("Destination Row: \(destinationIndexPath.row); Destination Section: \(destinationIndexPath.section)")
    }
 }
