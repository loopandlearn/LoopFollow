// LoopFollow
// AlarmViewController.swift
// Created by Jonas Björkert.

import SwiftUI
import UIKit

class AlarmViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let alarmsView = AlarmsContainerView()

        let hostingController = UIHostingController(rootView: alarmsView)

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController.didMove(toParent: self)
    }
}
