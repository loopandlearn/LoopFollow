//
//  OverrideViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit

class OverrideViewController: UIViewController {

    @IBOutlet weak var overrideList: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // TOdo: Make the overrides user configurable. Below is just for UI visualization
        let item1 = UIAction(title: "👻 Resistance", handler: { _ in
            // Handle action for item 1
            print("Override Resistance selected")
        })
        
        let item2 = UIAction(title: "🤧 Sick day", handler: { _ in
            // Handle action for item 2
            print("Override Sick day selected")
        })
        
        let item3 = UIAction(title: "🏃‍♂️ Excercise", handler: { _ in
            // Handle action for item 3
            print("Override Exercise selected")
        })
        
        let item4 = UIAction(title: "😴 Nightmode", handler: { _ in
            // Handle action for item 4
            print("Override Nightmode selected")
        })
        
        // Create a menu with the actions
        let menu = UIMenu(title: "Override List", children: [item1, item2, item3, item4])
        
        // Set the menu to the overrideList
        if #available(iOS 14.0, *) {
            overrideList.menu = menu
        } else {
            print("iOS <14 do not support this function")
            //To do: Add varaible to block send button if not supported
        }
        
    }
    
    @IBAction func sendRemoteOverridePressed(_ sender: Any) {
        
        print("Send Override button pressed")
        // Todo: Send combinedString via SMS through API
        
        // Dismiss the current view controller
        dismiss(animated: true, completion: nil)
    }

}
