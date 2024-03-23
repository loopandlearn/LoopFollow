//
//  OverrideViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class TempTargetViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var tempTargetsPicker: UIPickerView!
    
    // Property to store the selected override option
    var selectedTempTarget: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        // Set the delegate and data source for the UIPickerView
        tempTargetsPicker.delegate = self
        tempTargetsPicker.dataSource = self
        
        // Set the default selected item for the UIPickerView
        tempTargetsPicker.selectRow(0, inComponent: 0, animated: false)
        
        // Set the initial selected override
        selectedTempTarget = tempTargetsOptions[0]
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return tempTargetsOptions.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return tempTargetsOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Update the selectedTempTarget property when an option is selected
        selectedTempTarget = tempTargetsOptions[row]
        print("Override Picker selected: \(selectedTempTarget!)")
    }
    
    @IBAction func sendRemoteTempTargetPressed(_ sender: Any) {
        guard let selectedTempTarget = selectedTempTarget else {
            print("No temp target option selected")
            return
        }
        
        let combinedString = "temptargettoenact_\(selectedTempTarget)"
        
        print("Combined string:", combinedString)
 
        //Initial work/testing: Twilio API (This API is being discontinued. Please see https://support.twilio.com/hc/en-us/articles/223181028-Switching-from-SMS-Messages-resource-URI-to-Messages-resource-URI)
        let twilioSID = UserDefaultsRepository.twilioSIDString.value
        let twilioSecret = UserDefaultsRepository.twilioSecretString.value
        let fromNumber = UserDefaultsRepository.twilioFromNumberString.value
        let toNumber = UserDefaultsRepository.twilioToNumberString.value
        let message = combinedString

        // Build the request
        let urlString = "https://\(twilioSID):\(twilioSecret)@api.twilio.com/2010-04-01/Accounts/\(twilioSID)/SMS/Messages"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "From=\(fromNumber)&To=\(toNumber)&Body=\(message)".data(using: .utf8)

        // Build the completion block and send the request
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print("Finished")
            if let data = data, let responseDetails = String(data: data, encoding: .utf8) {
                // Success
                print("Response: \(responseDetails)")
            } else {
                // Failure
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }.resume()

        
        
        // Dismiss the current view controller
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // Data for the UIPickerView
    lazy var tempTargetsOptions: [String] = {
        let tempTargetsString = UserDefaultsRepository.tempTargetsString.value
        // Split the tempTargetsString by ", " to get individual options
        return tempTargetsString.components(separatedBy: ", ")
    }()
}

