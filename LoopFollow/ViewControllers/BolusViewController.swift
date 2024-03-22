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

        // Do any additional setup after loading the view.
    }
    @IBAction func sendRemoteBolusPressed(_ sender: Any) {
        let bolusValue = bolusAmount.text ?? ""
        
        let combinedString = "bolustoenact_\(bolusValue)"
        
        print("Combined string:", combinedString)
        // Todo: Send combinedString via SMS through API
        
        // Dismiss the current view controller
            dismiss(animated: true, completion: nil)
    }
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
