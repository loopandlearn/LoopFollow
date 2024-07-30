//
//  RemoteView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-19.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct RemoteView: View {
    @ObservedObject var nightscoutURL = ObservableUserDefaults.shared.url
    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var nsWriteAuth = ObservableUserDefaults.shared.nsWriteAuth
    @ObservedObject var tempTarget = Observable.shared.tempTarget

    @State private var newHKTarget = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0.0)
    @State private var duration = HKQuantity(unit: .minute(), doubleValue: 0.0)
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    var onCancelExistingTarget: (@escaping (Bool) -> Void) -> Void
    var sendTempTarget: (HKQuantity, HKQuantity, @escaping (Bool) -> Void) -> Void

    enum AlertType {
        case confirmCommand
        case status
        case confirmCancellation
    }

    var body: some View {
        NavigationView {
            VStack {
                if nightscoutURL.value.isEmpty {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Trio. It requires you to enter your Nightscout address and a token with the careportal role in the settings."
                    )
                } else if device.value != "Trio" {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Trio."
                    )
                } else if !nsWriteAuth.value {
                    ErrorMessageView(
                        message: "Please enter a valid token with appropriate permissions."
                    )
                } else {
                    Form {
                        if let tempTargetValue = tempTarget.value {
                            Section(header: Text("Existing Temp Target")) {
                                HStack {
                                    Text("Current Target")
                                    Spacer()
                                    Text(Localizer.formatQuantity(tempTargetValue))
                                    Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                                }
                                Button {
                                    alertType = .confirmCancellation
                                    showAlert = true
                                } label: {
                                    HStack {
                                        Text("Cancel Temp Target")
                                        Spacer()
                                        Image(systemName: "xmark.app")
                                            .font(.title)
                                    }
                                }
                                .tint(.red)
                            }
                        }
                        Section(header: Text("Temporary Target")) {
                            HStack {
                                Text("Target")
                                Spacer()
                                TextFieldWithToolBar(quantity: $newHKTarget, maxLength: 4, unit: UserDefaultsRepository.getPreferredUnit())
                                Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Duration")
                                Spacer()
                                TextFieldWithToolBar(quantity: $duration, maxLength: 4, unit: HKUnit.minute())
                                Text("minutes").foregroundColor(.secondary)
                            }
                            HStack {
                                Button {
                                    alertType = .confirmCommand
                                    showAlert = true
                                } label: {
                                    Text("Enact")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)
                            }
                        }
                    }

                    if isLoading {
                        ProgressView("Please wait...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmCommand:
                    return Alert(
                        title: Text("Confirm Command"),
                        message: Text("New Target: \(Localizer.formatQuantity(newHKTarget)) \(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)\nDuration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"),
                        primaryButton: .default(Text("Confirm"), action: {
                            enactTempTarget()
                        }),
                        secondaryButton: .cancel()
                    )
                case .status:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            showAlert = false
                        })
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Confirm Cancellation"),
                        message: Text("Are you sure you want to cancel the existing temp target?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            cancelTempTarget()
                        }),
                        secondaryButton: .cancel()
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    private var isButtonDisabled: Bool {
        return newHKTarget.doubleValue(for: UserDefaultsRepository.getPreferredUnit()) == 0 ||
        duration.doubleValue(for: HKUnit.minute()) == 0 || isLoading
    }

    private func enactTempTarget() {
        isLoading = true
        sendTempTarget(newHKTarget, duration) { success in
            self.isLoading = false
            if success {
                self.statusMessage = "Target successfully enacted."
            } else {
                self.statusMessage = "Failed to enact target."
            }
            self.alertType = .status
            self.showAlert = true
        }
    }

    private func cancelTempTarget() {
        isLoading = true
        onCancelExistingTarget() { success in
            self.isLoading = false
            if success {
                self.statusMessage = "Temp target successfully cancelled."
            } else {
                self.statusMessage = "Failed to cancel temp target."
            }
            self.alertType = .status
            self.showAlert = true
        }
    }
}

struct ErrorMessageView: View {
    var message: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: .gray, radius: 5, x: 0, y: 2)
                )
                .padding()

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .gray, radius: 5, x: 0, y: 2)
        )
        .padding()
    }
}
