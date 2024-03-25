//
//  BolusViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit
import LocalAuthentication

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
        
        // Confirmation alert before sending the request
        let confirmationAlert = UIAlertController(title: "Confirmation", message: "Do you want to give \(bolusValue) U bolus?", preferredStyle: .alert)
        
        confirmationAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
            // Authenticate with Face ID
            self.authenticateWithBiometrics {
                // Proceed with the request after successful authentication
                self.sendBolusRequest(bolusValue: bolusValue)
            }
        }))
        
        confirmationAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    func authenticateWithBiometrics(completion: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful
                        completion()
                    } else {
                        // Check for passcode authentication
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue || error.code == LAError.biometryNotEnrolled.rawValue {
                            // Biometry (Face ID or Touch ID) is not available or not enrolled, use passcode
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            // Authentication failed
                            if let error = authenticationError {
                                print("Authentication failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } else {
            // Biometry (Face ID or Touch ID) is not available, use passcode
            self.authenticateWithPasscode(completion: completion)
        }
    }
    
    func authenticateWithPasscode(completion: @escaping () -> Void) {
        let context = LAContext()
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate with passcode to proceed") { success, error in
            DispatchQueue.main.async {
                if success {
                    // Authentication successful
                    completion()
                } else {
                    // Authentication failed
                    if let error = error {
                        print("Authentication failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    
    func sendBolusRequest(bolusValue: Double) {
        
        // Convert bolusValue to string and trim any leading or trailing whitespace
        let trimmedBolusValue = "\(bolusValue)".trimmingCharacters(in: .whitespacesAndNewlines)
        
        let combinedString = "Bolus_\(trimmedBolusValue)"
        print("Combined string:", combinedString)
        
        // Retrieve the method value from UserDefaultsRepository
        let method = UserDefaultsRepository.method.value
        
        // Use combinedString as the text in the URL
        if method != "SMS API" {
            // URL encode combinedString
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("Failed to encode URL string")
                return
            }
            let urlString = "shortcuts://run-shortcut?name=Remote%20Bolus&input=text&text=\(encodedString)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            dismiss(animated: true, completion: nil)
        } else {
            // If method is "SMS API", proceed with sending the request
            let twilioSID = UserDefaultsRepository.twilioSIDString.value
            let twilioSecret = UserDefaultsRepository.twilioSecretString.value
            let fromNumber = UserDefaultsRepository.twilioFromNumberString.value
            let toNumber = UserDefaultsRepository.twilioToNumberString.value
            let message = combinedString
            
            // Build the request
            let urlString = "https://\(twilioSID):\(twilioSecret)@api.twilio.com/2010-04-01/Accounts/\(twilioSID)/Messages"
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "From=\(fromNumber)&To=\(toNumber)&Body=\(message)".data(using: .utf8)
            
            // Build the completion block and send the request
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        // Failure: Show error alert for network error
                        let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    } else if let httpResponse = response as? HTTPURLResponse {
                        if (200..<300).contains(httpResponse.statusCode) {
                            // Success: Show success alert for successful response
                            let alertController = UIAlertController(title: "Success", message: "Message sent successfully!", preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                                // Dismiss the current view controller
                                self.dismiss(animated: true, completion: nil)
                            }))
                            self.present(alertController, animated: true, completion: nil)
                        } else {
                            // Failure: Show error alert for non-successful HTTP status code
                            let message = "HTTP Status Code: \(httpResponse.statusCode)"
                            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alertController, animated: true, completion: nil)
                        }
                    } else {
                        // Failure: Show generic error alert for unexpected response
                        let alertController = UIAlertController(title: "Error", message: "Unexpected response", preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }.resume()
            
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

