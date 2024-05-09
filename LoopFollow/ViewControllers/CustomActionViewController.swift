//
//  CustomActionsViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit
import LocalAuthentication
import AudioToolbox

class CustomActionViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, TwilioRequestable  {
    var appStateController: AppStateController?
    
    @IBOutlet weak var sendCustomActionButton: UIButton!
    @IBOutlet weak var customActionsPicker: UIPickerView!
    @IBOutlet weak var minPredBGValue: UITextField!
    @IBOutlet weak var minPredBGView: UIView!
    
    var isAlertShowing = false // Property to track if alerts are currently showing
    var isButtonDisabled = false // Property to track if the button is currently disabled
    
    var minGuardBG: Decimal = 0.0
    var lowThreshold: Decimal = 0.0
    
    // Property to store the selected override option
    var selectedCustomAction: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
            
            // Do any additional setup after loading the view.
        }
        // Set the delegate and data source for the UIPickerView
        customActionsPicker.delegate = self
        customActionsPicker.dataSource = self
        
        // Set the default selected item for the UIPickerView
        customActionsPicker.selectRow(0, inComponent: 0, animated: false)
        
        // Set the initial selected override
        selectedCustomAction = customActionsOptions[0]
        
        // Create a NumberFormatter instance
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1
        
        //MinGuardBG & Low Threshold
        let minGuardBG = Decimal(sharedMinGuardBG)
        let lowThreshold = Decimal(Double(UserDefaultsRepository.lowLine.value) * 0.0555)
        
        // Format the MinGuardBG value & low threshold to have one decimal place
        let formattedMinGuardBG = numberFormatter.string(from: NSDecimalNumber(decimal: minGuardBG) as NSNumber) ?? ""
        let formattedLowThreshold = numberFormatter.string(from: NSDecimalNumber(decimal: lowThreshold) as NSNumber) ?? ""
         
        // Set the text field with the formatted value of minGuardBG or "N/A" if formattedMinGuardBG is "0.0"
        minPredBGValue.text = formattedMinGuardBG == "0" ? "N/A" : formattedMinGuardBG
        print("Predicted Min BG: \(formattedMinGuardBG) mmol/L")
        print("Low threshold: \(formattedLowThreshold) mmol/L")
        
        // Check if the value of minGuardBG is less than lowThreshold
        if minGuardBG < lowThreshold {
            // Show warning symbol
         minPredBGView.isHidden = false
        } else {
            // Hide warning symbol
         minPredBGView.isHidden = true
        }
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return customActionsOptions.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return customActionsOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Update the selectedOverride property when an option is selected
        selectedCustomAction = customActionsOptions[row]
        print("Custom Picker selected: \(selectedCustomAction!)")
    }
    
    @IBAction func sendRemoteCustomActionPressed(_ sender: Any) {
        // Disable the button to prevent multiple taps
                if !isButtonDisabled {
                    isButtonDisabled = true
                    sendCustomActionButton.isEnabled = false
                } else {
                    return // If button is already disabled, return to prevent double registration
                }
        guard let selectedCustomAction = selectedCustomAction else {
            print("No custom action option selected")
            return
        }

        //New formatting for testing (Use "Remote Custom Action" as trigger word on receiving phone after triggering automation)
        let name = UserDefaultsRepository.caregiverName.value
        let secret = UserDefaultsRepository.remoteSecretCode.value
        let combinedString = "Remote Custom Action\n\(selectedCustomAction)\nInlagt av: \(name)\nHemlig kod: \(secret)"
        print("Combined string:", combinedString)
        
        // Confirmation alert before sending the request
        let confirmationAlert = UIAlertController(title: "Bekräfta förval", message: "Observera att flera av förvalen både registrerar en måltid och ger en bolus!\n\nVill du registrera \(selectedCustomAction)?", preferredStyle: .alert)
        
        confirmationAlert.addAction(UIAlertAction(title: "Ja", style: .default, handler: { (action: UIAlertAction!) in
            // Authenticate with Face ID
            self.authenticateWithBiometrics {
                // Proceed with the request after successful authentication
                self.sendCustomActionRequest(combinedString: combinedString)
            }
        }))
        
        confirmationAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { (action: UIAlertAction!) in
                    // Handle dismissal when "Cancel" is selected
                    self.handleAlertDismissal()
                }))
        
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    // Function to handle alert dismissal
        func handleAlertDismissal() {
            // Enable the button when alerts are dismissed
            isAlertShowing = false
            sendCustomActionButton.isEnabled = true
            isButtonDisabled = false // Reset button disable status
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
                            // Handle dismissal when authentication fails
                            self.handleAlertDismissal()
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
                    // Handle dismissal when authentication fails
                    self.handleAlertDismissal()
                }
            }
        }
    }
    
    func sendCustomActionRequest(combinedString: String) {
        
        // Retrieve the method value from UserDefaultsRepository
        let method = UserDefaultsRepository.method.value
        
        // Use combinedString as the text in the URL
        if method != "SMS API" {
            // URL encode combinedString
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("Failed to encode URL string")
                return
            }
            let urlString = "shortcuts://run-shortcut?name=Remote%20Custom%20Action&input=text&text=\(encodedString)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            dismiss(animated: true, completion: nil)
            
        } else {
            // If method is "SMS API", proceed with sending the request
            twilioRequest(combinedString: combinedString) { result in
                switch result {
                case .success:
                    // Play success sound
                    AudioServicesPlaySystemSound(SystemSoundID(1322))
                    
                    // Show success alert
                    let alertController = UIAlertController(title: "Lyckades!", message: "Meddelandet levererades", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        // Dismiss the current view controller
                        self.dismiss(animated: true, completion: nil)
                    }))
                    self.present(alertController, animated: true, completion: nil)
                case .failure(let error):
                    // Play failure sound
                    AudioServicesPlaySystemSound(SystemSoundID(1053))
                    
                    // Show error alert
                    let alertController = UIAlertController(title: "Fel", message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // Data for the UIPickerView
    lazy var customActionsOptions: [String] = {
        let customActionsString = UserDefaultsRepository.customActionsString.value
        // Split the customActionsString by ", " to get individual options
        return customActionsString.components(separatedBy: ", ")
    }()
}
