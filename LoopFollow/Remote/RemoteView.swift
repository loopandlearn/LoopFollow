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
    @ObservedObject var statusMessage = Observable.shared.statusMessage

    @State private var newHKTarget = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0.0)
    @State private var duration = HKQuantity(unit: .minute(), doubleValue: 0.0)
    @State private var showConfirmation: Bool = false
    @State private var showCheckmark: Bool = false
    @State private var isLoading: Bool = false

    var onRefreshStatus: () -> Void
    var onCancelExistingTarget: () -> Void
    var sendTempTarget: (HKQuantity, HKQuantity, @escaping (Bool) -> Void) -> Void

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
                                    Text("Current Target: \(Localizer.formatQuantity(tempTargetValue)) mg/dL")
                                    Spacer()
                                    Button(action: onCancelExistingTarget) {
                                        Text("Cancel")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }

                        Section(header: Text("Temporary Target")) {
                            HStack {
                                Text("Target")
                                Spacer()
                                TextFieldWithToolBar(quantity: $newHKTarget, unit: UserDefaultsRepository.getPreferredUnit())
                                Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Duration")
                                Spacer()
                                TextFieldWithToolBar(quantity: $duration, unit: HKUnit.minute())
                                Text("minutes").foregroundColor(.secondary)
                            }
                            HStack {
                                Button {
                                    showConfirmation = true
                                } label: {
                                    Text("Enact")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)
                            }
                        }
                        .alert(isPresented: $showConfirmation) {
                            Alert(
                                title: Text("Confirm Command"),
                                message: Text("New Target: \(Localizer.formatQuantity(newHKTarget)) \(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)\nDuration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"),
                                primaryButton: .default(Text("Confirm"), action: {
                                    enactTempTarget()
                                }),
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    .navigationBarItems(trailing: Button(action: onRefreshStatus) {
                        Image(systemName: "arrow.clockwise")
                    })
                    .padding()
                    .disabled(isLoading) // Disable the form when loading

                    if isLoading {
                        ProgressView("Please wait...")
                            .padding()
                    }
                }
            }
            .padding()
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: .constant(!statusMessage.value.isEmpty)) {
                Alert(
                    title: Text("Status"),
                    message: Text(statusMessage.value),
                    dismissButton: .default(Text("OK"), action: {
                        statusMessage.value = ""
                    })
                )
            }
        }
    }

    private var isButtonDisabled: Bool {
        return newHKTarget.doubleValue(for: UserDefaultsRepository.getPreferredUnit()) == 0 ||
        duration.doubleValue(for: HKUnit.minute()) == 0
    }

    private func enactTempTarget() {
        isLoading = true
        sendTempTarget(newHKTarget, duration) { success in
            isLoading = false
            if success {
                statusMessage.value = "Target successfully enacted."
            } else {
                statusMessage.value = "Failed to enact target."
            }
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
