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
    private var statusMessage: ObservableValue<String> {
        return Observable.shared.statusMessage
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let remoteView = RemoteView(
            onRefreshStatus: refreshStatus,
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

        initialSetup()
    }

    private func initialSetup() {
        // Perform initial setup checks here
        // For example, load the Nightscout URL and token from user defaults or another source
    }

    private func refreshStatus() {
        // Refresh the status to check current temp targets and other relevant info
    }

    private func cancelExistingTarget(completion: @escaping (Bool) -> Void) {
        let tempTargetBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Temporary Target",
            "reason": "Manual",
            "duration": 0,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody) { (result: Result<[TreatmentCancelResponse], Error>) in
            switch result {
            case .success(let response):
                print("Success: \(response)")
                DispatchQueue.main.async {
                    self.statusMessage.set("Temp target successfully cancelled.")
                    completion(true)
                }
            case .failure(let error):
                print("Error: \(error)")
                DispatchQueue.main.async {
                    self.statusMessage.set("Failed to cancel temp target: \(error.localizedDescription)")
                    completion(false)
                }
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

        NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody) { (result: Result<[TreatmentResponse], Error>) in
            switch result {
            case .success(let response):
                print("Success: \(response)")
                DispatchQueue.main.async {
                    self.statusMessage.set("Temp target sent successfully.")
                    completion(true)
                }
            case .failure(let error):
                print("Error: \(error)")
                DispatchQueue.main.async {
                    self.statusMessage.set("Failed to send temp target: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
}
