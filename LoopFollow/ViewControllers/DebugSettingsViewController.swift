//
//  DebugSettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Eureka
import EventKit
import EventKitUI

class DebugSettingsViewController: FormViewController {
    
    var appStateController: AppStateController?
    
    override func viewDidLoad()  {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        buildDebugSettings()
    }
    private func buildDebugSettings() {
        form
            +++ Section("Debug Settings")
            
            <<< SwitchRow("downloadTreatments"){ row in
                row.title = "Download Treatments"
                row.value = UserDefaultsRepository.downloadTreatments.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.downloadTreatments.value = value
            }
            <<< SwitchRow("downloadPrediction"){ row in
                row.title = "Download Prediction"
                row.value = UserDefaultsRepository.downloadPrediction.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.downloadPrediction.value = value
            }
            <<< SwitchRow("graphBasal"){ row in
                row.title = "Graph Basal"
                row.value = UserDefaultsRepository.graphBasal.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.graphBasal.value = value
            }
            <<< SwitchRow("graphBolus"){ row in
                row.title = "Graph Bolus"
                row.value = UserDefaultsRepository.graphBolus.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.graphBolus.value = value
            }
            <<< SwitchRow("graphCarbs"){ row in
                row.title = "Graph Carbs"
                row.value = UserDefaultsRepository.graphCarbs.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.graphCarbs.value = value
            }
            <<< SwitchRow("graphOtherTreatments"){ row in
                row.title = "Graph Other Treatments"
                row.value = UserDefaultsRepository.graphOtherTreatments.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.graphOtherTreatments.value = value
            }
            
            
            
            <<< SwitchRow("debugLog"){ row in
                row.title = "Show Debug Log"
                row.value = UserDefaultsRepository.debugLog.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.debugLog.value = value
            }
            
            +++ ButtonRow() {
                $0.title = "DONE"
            }.onCellSelection { (row, arg)  in
                self.dismiss(animated:true, completion: nil)
            }
    }
}
