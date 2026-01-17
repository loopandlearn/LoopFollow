// LoopFollow
// SettingsViewController.swift

import Combine
import SwiftUI
import UIKit

final class SettingsViewController: UIViewController {
    // MARK: Stored properties

    private var host: UIHostingController<SettingsMenuView>!
    private var cancellables = Set<AnyCancellable>()

    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Build SwiftUI menu
        host = UIHostingController(rootView: SettingsMenuView())

        // Appearance mode override
        host.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle

        // Listen for appearance setting changes
        Storage.shared.appearanceMode.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateAppearance(mode)
            }
            .store(in: &cancellables)

        // Listen for system appearance changes (when in System mode)
        NotificationCenter.default.publisher(for: .appearanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAppearance(Storage.shared.appearanceMode.value)
            }
            .store(in: &cancellables)

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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if Storage.shared.appearanceMode.value == .system,
           previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            updateAppearance(.system)
        }
    }

    private func updateAppearance(_ mode: AppearanceMode) {
        host.overrideUserInterfaceStyle = mode.userInterfaceStyle
    }
}
