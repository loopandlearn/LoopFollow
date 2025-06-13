// LoopFollow
// SettingsViewController.swift
// Created by Jon Fawcett on 2020-06-05.

import SwiftUI
import UIKit

final class SettingsViewController: UIViewController {
    // MARK: Stored properties

    private var host: UIHostingController<SettingsMenuView>!

    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build SwiftUI menu
        host = UIHostingController(
            rootView: SettingsMenuView { [weak self] nightscoutEnabled in
                self?.tabBarController?.tabBar.items?[3].isEnabled = nightscoutEnabled
            })

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
}
