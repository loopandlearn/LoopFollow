//
//  RemoteViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class RemoteViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
            
            // Do any additional setup after loading the view.
        }
    }
    
    @IBAction func mealButtonPressed(_ sender: Any) {
        let mealViewController = storyboard!.instantiateViewController(withIdentifier: "remoteMeal") as! MealViewController
        self.present(mealViewController, animated: true, completion: nil)
    }
    
    @IBAction func bolusButtonPressed(_ sender: Any) {
        let bolusViewController = storyboard!.instantiateViewController(withIdentifier: "remoteBolus") as! BolusViewController
        self.present(bolusViewController, animated: true, completion: nil)
    }
    
    @IBAction func overrideButtonPressed(_ sender: Any) {
        let overrideViewController = storyboard!.instantiateViewController(withIdentifier: "remoteOverride") as! OverrideViewController
        self.present(overrideViewController, animated: true, completion: nil)
    }
    
    @IBAction func tempTargetButtonPressed(_ sender: Any) {
        let tempTargetViewController = storyboard!.instantiateViewController(withIdentifier: "remoteTempTarget") as! TempTargetViewController
        self.present(tempTargetViewController, animated: true, completion: nil)
    }
    
    @IBAction func remoteSettingsButtonTapped(_ sender: Any) {
        let remoteSettingsViewController = storyboard!.instantiateViewController(withIdentifier: "remoteSettings") as! RemoteSettingsViewController
        self.present(remoteSettingsViewController, animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
