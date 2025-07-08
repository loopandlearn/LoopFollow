// LoopFollow
// RemoteViewController.swift
// Created by Jonas Björkert.

import Combine
import SwiftUI
import UIKit

class RemoteViewController: UIViewController {
    private var cancellable: AnyCancellable?
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        cancellable = Storage.shared.device.$value
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateView()
                }
            }
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
            case "Loop":
                remoteView = AnyView(LoopNightscoutRemoteView())
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

    deinit {
        cancellable?.cancel()
    }
}
