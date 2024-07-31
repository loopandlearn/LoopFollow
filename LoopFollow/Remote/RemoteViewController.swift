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

class RemoteViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let remoteView = RemoteView(
            onCancelExistingTarget: cancelExistingTarget,
            sendTempTarget: sendTempTarget
        )
        let hostingController = UIHostingController(rootView: remoteView)

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

        if(!ObservableUserDefaults.shared.nsWriteAuth.value) {
            NightscoutUtils.verifyURLAndToken { error, jwtToken, nsWriteAuth in
                DispatchQueue.main.async {
                    ObservableUserDefaults.shared.nsWriteAuth.value = nsWriteAuth
                }
            }
        }
    }

    private func cancelExistingTarget(completion: @escaping (Bool) -> Void) {
        Task {
            let tempTargetBody: [String: Any] = [
                "enteredBy": "LoopFollow",
                "eventType": "Temporary Target",
                "reason": "Manual",
                "duration": 0,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]

            do {
                let response: [TreatmentCancelResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody)
                Observable.shared.tempTarget.value = nil
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    private func sendTempTarget(newTarget: HKQuantity, duration: HKQuantity, completion: @escaping (Bool) -> Void) {
        let tempTargetBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Temporary Target",
            "reason": "Manual",
            "targetTop": newTarget.doubleValue(for: .milligramsPerDeciliter),
            "targetBottom": newTarget.doubleValue(for: .milligramsPerDeciliter),
            "duration": Int(duration.doubleValue(for: .minute())),
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        Task {
            do {
                let response: [TreatmentResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody)
                Observable.shared.tempTarget.value = newTarget
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
}
