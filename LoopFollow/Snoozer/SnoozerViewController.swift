// LoopFollow
// SnoozerViewController.swift

import Combine
import SwiftUI
import UIKit

class SnoozerViewController: UIViewController {
    private var hostingController: UIHostingController<SnoozerView>?

    @State private var snoozeMinutes = 15

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let snoozerView = SnoozerView()

        let hosting = UIHostingController(rootView: snoozerView)
        hostingController = hosting
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hosting.didMove(toParent: self)
    }
}
