// LoopFollow
// RemoteViewController.swift

import Combine
import SwiftUI
import UIKit

class RemoteViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Apply initial appearance
        overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle

        Storage.shared.device.$value
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateView()
                }
            }
            .store(in: &cancellables)

        // Listen for appearance setting changes
        Storage.shared.appearanceMode.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.overrideUserInterfaceStyle = mode.userInterfaceStyle
                self?.hostingController?.overrideUserInterfaceStyle = mode.userInterfaceStyle
            }
            .store(in: &cancellables)

        // Listen for system appearance changes (when in System mode)
        NotificationCenter.default.publisher(for: .appearanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let style = Storage.shared.appearanceMode.value.userInterfaceStyle
                self?.overrideUserInterfaceStyle = style
                self?.hostingController?.overrideUserInterfaceStyle = style
            }
            .store(in: &cancellables)
    }

    private func updateView() {
        let remoteType = Storage.shared.remoteType.value

        if let existingHostingController = hostingController {
            existingHostingController.willMove(toParent: nil)
            existingHostingController.view.removeFromSuperview()
            existingHostingController.removeFromParent()
        }

        if remoteType == .nightscout {
            var remoteView: AnyView

            switch Storage.shared.device.value {
            case "Trio":
                remoteView = AnyView(TrioNightscoutRemoteView())
            default:
                remoteView = AnyView(NoRemoteView())
            }

            hostingController = UIHostingController(rootView: remoteView)
        } else if remoteType == .trc {
            if Storage.shared.device.value != "Trio" {
                hostingController = UIHostingController(
                    rootView: AnyView(
                        Text("Trio Remote Control is only supported for 'Trio'")
                    )
                )
            } else {
                let trioRemoteControlViewModel = TrioRemoteControlViewModel()
                let trioRemoteControlView = TrioRemoteControlView(viewModel: trioRemoteControlViewModel)
                hostingController = UIHostingController(rootView: AnyView(trioRemoteControlView))
            }
        } else if remoteType == .loopAPNS {
            hostingController = UIHostingController(rootView: AnyView(LoopAPNSRemoteView()))
        } else {
            hostingController = UIHostingController(rootView: AnyView(Text("Please select a Remote Type in Settings.")))
        }

        if let hostingController = hostingController {
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

        if remoteType == .nightscout, !Storage.shared.nsWriteAuth.value {
            NightscoutUtils.verifyURLAndToken { _, _, nsWriteAuth, nsAdminAuth in
                DispatchQueue.main.async {
                    Storage.shared.nsWriteAuth.value = nsWriteAuth
                    Storage.shared.nsAdminAuth.value = nsAdminAuth
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateView()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if Storage.shared.appearanceMode.value == .system,
           previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            let style = Storage.shared.appearanceMode.value.userInterfaceStyle
            overrideUserInterfaceStyle = style
            hostingController?.overrideUserInterfaceStyle = style
        }
    }
}
