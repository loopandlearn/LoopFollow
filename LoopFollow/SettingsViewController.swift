//
//  SettingsViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka

class SettingsViewController: FormViewController {


    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        form +++ Section("Nightscout Settings")
            <<< TextRow(){ row in
                row.title = "URL"
                row.placeholder = "https://mycgm.herokuapp.com"
                row.value = UserDefaultsRepository.url.value
            }.onChange { row in
                guard let value = row.value else { return }
                UserDefaultsRepository.url.value = value.lowercased()
                }
        +++ Section("General Settings")
            
        +++ Section("Graph Settings")
            <<< SwitchRow("switchRowDots"){ row in
                row.title = "Display Dots"
                row.value = UserDefaultsRepository.showDots.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.showDots.value = value
                }
            <<< SwitchRow("switchRowLines"){ row in
                row.title = "Display Lines"
                row.value = UserDefaultsRepository.showLines.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.showLines.value = value
                        
                }
        
         }
        
        
        
 


}
