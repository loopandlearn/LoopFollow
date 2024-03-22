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
    
    // Property to store the selected override option
    var selectedOverride: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
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
 
        //Initial work/testing: Twilo API (This API is being discontinued. Please see https://support.twilio.com/hc/en-us/articles/223181028-Switching-from-SMS-Messages-resource-URI-to-Messages-resource-URI)
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
    lazy var overrideOptions: [String] = {
        let overrideString = UserDefaultsRepository.overrideString.value
        // Split the overrideString by ", " to get individual options
        return overrideString.components(separatedBy: ", ")
    }()
}

