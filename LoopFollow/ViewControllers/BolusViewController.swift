//
//  BolusViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class BolusViewController: UIViewController {

    @IBOutlet weak var bolusAmount: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    @IBAction func sendRemoteBolusPressed(_ sender: Any) {
        // Retrieve the maximum bolus value
        let maxBolus = UserDefaultsRepository.maxBolus.value 
        
        guard var bolusText = bolusAmount.text, !bolusText.isEmpty else {
            print("Error: Bolus amount not entered")
            return
        }
        
        // Replace all occurrences of ',' with '.'
        bolusText = bolusText.replacingOccurrences(of: ",", with: ".")
        
        guard let bolusValue = Double(bolusText) else {
            print("Error: Bolus amount conversion failed")
            return
        }
        
        if bolusValue > maxBolus {
            // Format maxBolus to display only one decimal place
            let formattedMaxBolus = String(format: "%.1f", maxBolus)
            
            let alertController = UIAlertController(title: "Max setting exceeded", message: "The maximum allowed bolus of \(formattedMaxBolus) U is exceeded! Please try again with a smaller amount.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            return
        }
        
        let combinedString = "bolustoenact_\(bolusValue)"
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
}

