// LoopFollow
// AlarmViewController.swift

import Combine
import SwiftUI
import UIKit

class AlarmViewController: UIViewController {
    private var hostingController: UIHostingController<AlarmsContainerView>!
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        let alarmsView = AlarmsContainerView()
        hostingController = UIHostingController(rootView: alarmsView)

        // Apply initial appearance
        hostingController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle

        // Listen for appearance setting changes
        Storage.shared.appearanceMode.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.hostingController.overrideUserInterfaceStyle = mode.userInterfaceStyle
            }
            .store(in: &cancellables)

        // Listen for system appearance changes (when in System mode)
        NotificationCenter.default.publisher(for: .appearanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hostingController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
            }
            .store(in: &cancellables)

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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if Storage.shared.appearanceMode.value == .system,
           previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            hostingController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        }
    }
}
