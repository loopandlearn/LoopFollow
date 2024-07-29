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
    }

    private func cancelExistingTarget(completion: @escaping (Bool) -> Void) {
        let tempTargetBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Temporary Target",
            "reason": "Manual",
            "duration": 0,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        print("Executing cancelExistingTarget on thread: \(Thread.current), QoS: \(qos_class_self())")
        NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody) { (result: Result<[TreatmentCancelResponse], Error>) in
            print("Handling cancelExistingTarget result on thread: \(Thread.current), QoS: \(qos_class_self())")
            switch result {
            case .success(let response):
                print("Success: \(response)")
                completion(true)
            case .failure(let error):
                print("Error: \(error)")
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

        completion(true)

        print("Executing sendTempTarget on thread: \(Thread.current), QoS: \(qos_class_self())")
        NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody) { (result: Result<[TreatmentResponse], Error>) in
            print("Handling sendTempTarget result on thread: \(Thread.current), QoS: \(qos_class_self())")
            switch result {
            case .success(let response):
                print("Success: \(response)")
                completion(true)
            case .failure(let error):
                print("Error: \(error)")
                completion(false)
            }
        }
    }
}
