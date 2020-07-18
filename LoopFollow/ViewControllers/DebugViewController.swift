//
//  DebugViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/29/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

class debugViewController: UIViewController {
    
    @IBOutlet weak var debugLogTextView: UITextView!
    @IBOutlet weak var clearButton: UIButton!
    
    var appStateController: AppStateController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        debugLogTextView.isEditable = false

    }
    
    @IBAction func clearButton(_ sender: Any) {
        
        self.debugLogTextView.text = ""
    }
    
    
}
