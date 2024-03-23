//
//  MealViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class MealViewController: UIViewController {

    @IBOutlet weak var carbGrams: UITextField!
    @IBOutlet weak var fatGrams: UITextField!
    @IBOutlet weak var proteinGrams: UITextField!
    @IBOutlet weak var mealNotes: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
            
            // Do any additional setup after loading the view.
        }
    }
    @IBAction func sendRemoteMealPressed(_ sender: Any) {
        // Retrieve the maximum carbs value from UserDefaultsRepository
        let maxCarbs = UserDefaultsRepository.maxCarbs.value 
        
        // Convert carbGrams, fatGrams, and proteinGrams to integers or default to 0 if empty
        let carbs: Int
        let fats: Int
        let proteins: Int
        
        if let carbText = carbGrams.text, !carbText.isEmpty {
            guard let carbsValue = Int(carbText) else {
                print("Error: Carb input value conversion failed")
                return
            }
            carbs = carbsValue
        } else {
            carbs = 0
        }
        
        if let fatText = fatGrams.text, !fatText.isEmpty {
            guard let fatsValue = Int(fatText) else {
                print("Error: Fat input value conversion failed")
                return
            }
            fats = fatsValue
        } else {
            fats = 0
        }
        
        if let proteinText = proteinGrams.text, !proteinText.isEmpty {
            guard let proteinsValue = Int(proteinText) else {
                print("Error: Protein input value conversion failed")
                return
            }
            proteins = proteinsValue
        } else {
            proteins = 0
        }
        
        if carbs > maxCarbs || fats > maxCarbs || proteins > maxCarbs {
            let alertController = UIAlertController(title: "Max setting exceeded", message: "The maximum allowed amount of \(maxCarbs)g is exceeded for one or more of the entries! Please try again with a smaller amount.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            return
        }
        
        let mealNotesValue = mealNotes.text ?? ""
        
        let combinedString = "mealtoenact_carbs\(carbs)fat\(fats)protein\(proteins)note\(mealNotesValue)"
        
        print("Combined string:", combinedString)
        
        // Confirmation alert before sending the request
            let confirmationAlert = UIAlertController(title: "Confirmation", message: "Do you want to register this meal?", preferredStyle: .alert)
            
            confirmationAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
                // Proceed with sending the request
                self.sendMealRequest(combinedString: combinedString)
            }))
            
            confirmationAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            present(confirmationAlert, animated: true, completion: nil)
        }

        func sendMealRequest(combinedString: String) {
        
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

    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
