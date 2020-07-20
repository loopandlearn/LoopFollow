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
  
    var appStateController: AppStateController?
           
    var debugLogTextView = UITextView()
    var clearButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        let mainView = UIView()
        mainView.backgroundColor = .systemBackground
        mainView.frame.size.width = UIScreen.main.bounds.width
        mainView.frame.size.height = UIScreen.main.bounds.height
        
        // setup texview
        self.debugLogTextView.isEditable = false
        self.debugLogTextView.frame = CGRect(x:0, y:0, width: mainView.frame.size.width, height: mainView.frame.size.height - 200)
        self.debugLogTextView.addBorder(toSide: .Bottom, withColor: UIColor.darkGray.cgColor, andThickness: 2)
        self.debugLogTextView.text = "HELLO"
        
        // setup button
        self.clearButton.setTitle("Clear", for: .normal)
        self.clearButton.frame = CGRect(x:0, y:0, width:50, height:50)
        self.clearButton.center = CGPoint(x: mainView.frame.size.width/2, y: mainView.frame.size.height-150)
        // set the action
    
        // add up views
        mainView.addSubview(self.debugLogTextView)
        mainView.addSubview(self.clearButton)
        
        // set the controller
        self.view = mainView
        super.viewDidLoad()
        
    }
    @objc private func clearButton(_ sender: Any) {
        self.debugLogTextView.text = ""
    }
    
}
