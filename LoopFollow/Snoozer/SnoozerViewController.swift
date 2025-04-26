//
//  SnoozerViewController.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import UIKit
import SwiftUI
import Combine

class SnoozerViewController: UIViewController {
    private var hostingController: UIHostingController<SnoozerView>?

    @State private var snoozeMinutes = 15

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let snoozerView = SnoozerView(snoozeMinutes: $snoozeMinutes,
            onSnooze: {
                // Trigger snooze logic here (e.g., update UserDefaultsRepository, stop alarm, etc.)
                print("Snoozed for \(self.snoozeMinutes) minutes")
            },
        )

        let hosting = UIHostingController(rootView: snoozerView)
        self.hostingController = hosting
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hosting.didMove(toParent: self)
    }
}
