// LoopFollow
// SettingsViewController.swift

import SwiftUI
import UIKit

final class SettingsViewController: UIViewController {
    // MARK: Stored properties

    private var host: UIHostingController<SettingsMenuView>!

    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build SwiftUI menu
        host = UIHostingController(rootView: SettingsMenuView())

        // Dark-mode override
        if Storage.shared.forceDarkMode.value {
            host.overrideUserInterfaceStyle = .dark
        }

        // Embed
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Observable.shared.settingsPath.set(NavigationPath())
    }
}
