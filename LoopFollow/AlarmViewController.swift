//
//  AlarmViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka

class AlarmViewController: FormViewController {


    
    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section(header: "High BG Alert", footer: "Alerts when blood glucose raises above this value")
            <<< SliderRow.glucoseLevelSlider(initialValue: 180, minimumValue: 100, maximumValue: 400)

        
    }


}

extension SliderRow {
    
    class func glucoseLevelSlider(initialValue: Float, minimumValue: Float, maximumValue: Float, snapIncrementForMgDl: Float = 1.0) -> SliderRow {
        
        return SliderRow() { row in
            row.value = 180
            }.cellSetup { cell, row in
                
                let minimumValue: Float = 40
                let maximumValue: Float  = 400
                
                cell.slider.minimumValue = minimumValue
                cell.slider.maximumValue = maximumValue
                row.displayValueFor = { value in
                    guard let value = value else { return "" }
                    let units = "mg/dl"
                    return units
                }
                
                // fixed width for value label
                let widthConstraint = NSLayoutConstraint(item: cell.valueLabel!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 96)
                cell.valueLabel.addConstraints([widthConstraint])
        }
    }
}
