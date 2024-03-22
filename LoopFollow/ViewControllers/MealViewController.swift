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
        
        let totalCarbs = carbs + fats + proteins
        if totalCarbs > maxCarbs {
            let alertController = UIAlertController(title: "Max setting exceeded", message: "The maximum allowed entry of \(maxCarbs)g is exceeded! Please try again with a smaller amount.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            return
        }
        
        let mealNotesValue = mealNotes.text ?? ""
        
        let combinedString = "mealtoenact_ carbs\(carbs)fat\(fats)protein\(proteins)note\(mealNotesValue)"
        
        print("Combined string:", combinedString)
        // Todo: Send combinedString via SMS through API
        
        // Dismiss the current view controller
        dismiss(animated: true, completion: nil)
    }





    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
