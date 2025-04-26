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

    private var bgValue = ObservableValue<String>(default: "8,9")
    private var deltaValue = ObservableValue<String>(default: "-0,7")
    private var direction = ObservableValue<String>(default: "→")
    private var age = ObservableValue<String>(default: "4 min")
    private var time = ObservableValue<String>(default: "10:28")
    private var alarmText = ObservableValue<String?>(default: "High Alert")
    @State private var snoozeMinutes = 15

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let snoozerView = SnoozerView(
            bgValue: bgValue,
            deltaValue: deltaValue,
            direction: direction,
            age: age,
            time: time,
            alarmText: alarmText,
            snoozeMinutes: Binding(get: { self.snoozeMinutes }, set: { self.snoozeMinutes = $0 }),
            onSnooze: {
                // Trigger snooze logic here (e.g., update UserDefaultsRepository, stop alarm, etc.)
                print("Snoozed for \(self.snoozeMinutes) minutes")
            }
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

    // ✅ Only this screen supports landscape
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeLeft, .landscapeRight]
    }

    override var shouldAutorotate: Bool {
        return true
    }
}
