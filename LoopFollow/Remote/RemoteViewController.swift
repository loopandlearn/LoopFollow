//
//  RemoteViewController.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-19.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import HealthKit
import Combine

class RemoteViewController: UIViewController {

    private var cancellable: AnyCancellable?
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        cancellable = Storage.shared.remoteType.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateView()
                }
            }

        updateView()
    }

    private func updateView() {
        let remoteType = Storage.shared.remoteType.value

        if let existingHostingController = hostingController {
            existingHostingController.willMove(toParent: nil)
            existingHostingController.view.removeFromSuperview()
            existingHostingController.removeFromParent()
        }

        if remoteType == .nightscout {
            let remoteView = TrioNightscoutRemoteView()
            hostingController = UIHostingController(rootView: AnyView(remoteView))
        } else if remoteType == .trc {
            let trioRemoteControlViewModel = TrioRemoteControlViewModel()
            let trioRemoteControlView = TrioRemoteControlView(viewModel: trioRemoteControlViewModel)
            hostingController = UIHostingController(rootView: AnyView(trioRemoteControlView))
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
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            hostingController.didMove(toParent: self)
        }

        if remoteType == .nightscout, !ObservableUserDefaults.shared.nsWriteAuth.value {
            NightscoutUtils.verifyURLAndToken { error, jwtToken, nsWriteAuth in
                DispatchQueue.main.async {
                    ObservableUserDefaults.shared.nsWriteAuth.value = nsWriteAuth
                }
            }
        }
    }

    deinit {
        cancellable?.cancel()
    }
}
