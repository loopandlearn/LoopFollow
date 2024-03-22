//
//  OverrideViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class OverrideViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var overridePicker: UIPickerView!
    
    // Data for the UIPickerView
    let overrideOptions = ["Select Override:", "👻 Resistance", "🤧 Sick day", "🏃‍♂️ Exercise", "😴 Nightmode"]
    
    // Property to store the selected override option
    var selectedOverride: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the delegate and data source for the UIPickerView
        overridePicker.delegate = self
        overridePicker.dataSource = self
        
        // Set the default selected item for the UIPickerView
        overridePicker.selectRow(0, inComponent: 0, animated: false)
        
        // Set the initial selected override
        selectedOverride = overrideOptions[0]
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return overrideOptions.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return overrideOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Update the selectedOverride property when an option is selected
        selectedOverride = overrideOptions[row]
        print("Override Picker selected: \(selectedOverride!)")
    }
    
    @IBAction func sendRemoteOverridePressed(_ sender: Any) {
        guard let selectedOverride = selectedOverride else {
            print("No override option selected")
            return
        }
        
        let combinedString = "overridetoenact_\(selectedOverride)"
        
        print("Combined string:", combinedString)
        // Todo: Send combinedString via SMS through API
        
        // Dismiss the current view controller
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}


