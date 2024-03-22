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

        // Do any additional setup after loading the view.
    }

    @IBAction func sendRemoteMealPressed(_ sender: Any) {
        let carbValue = carbGrams.text ?? ""
        let fatValue = fatGrams.text ?? ""
        let proteinValue = proteinGrams.text ?? ""
        let mealNotesValue = mealNotes.text ?? ""
        
        let combinedString = "mealtoenact_ carbs\(carbValue)fat\(fatValue)protein\(proteinValue)note\(mealNotesValue)"
        
        print("Combined string:", combinedString)
        // Todo: Send combinedString via SMS through API
        
        // Dismiss the current view controller
            dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
