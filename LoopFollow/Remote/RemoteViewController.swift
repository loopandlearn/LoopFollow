//
//  RemoteViewController.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-19.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class RemoteViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let remoteView = RemoteView()
        let hostingController = UIHostingController(rootView: remoteView)

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}
