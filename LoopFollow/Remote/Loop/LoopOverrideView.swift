//
//  LoopOverrideView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct LoopOverrideView: View {
    @Environment(\.presentationMode) private var presentationMode

    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var overrideNote = Observable.shared.override
    @ObservedObject var nsAdmin = ObservableUserDefaults.shared.nsWriteAuth

    @StateObject private var viewModel = LoopOverrideViewModel()

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    @State private var selectedOverride: ProfileManager.LoopOverride? = nil
    @State private var showConfirmation: Bool = false

    @FocusState private var noteFieldIsFocused: Bool

    private let pushNotificationManager = PushNotificationManager()
    private var profileManager = ProfileManager.shared

    enum AlertType {
        case confirmActivation
        case confirmCancellation
        case statusSuccess
        case statusFailure
        case validation
    }

    var body: some View {
        NavigationView {
            VStack {
                if device.value != "Loop" {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Loop."
                    )
                } else if !nsAdmin.value {
                    ErrorMessageView(
                        message: "Please update your token to include the 'admin' role in order to do remote commands."
                    )
                } else {

                    Form {
                        if let activeNote = overrideNote.value {
                            Section(header: Text("Active Override")) {
                                HStack {
                                    Text("Override")
                                    Spacer()
                                    Text(activeNote)
                                        .foregroundColor(.secondary)
                                }
                                Button {
                                    alertType = .confirmCancellation
                                    showAlert = true
                                } label: {
                                    HStack {
                                        Text("Cancel Override")
                                        Spacer()
                                        Image(systemName: "xmark.app")
                                            .font(.title)
                                    }
                                }
                                .tint(.red)
                            }
                        }

                        Section(header: Text("Available Overrides")) {
                            if profileManager.loopOverrides.isEmpty {
                                Text("No overrides available.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(profileManager.loopOverrides, id: \.name) { override in
                                    Button(action: {
                                        selectedOverride = override
                                        alertType = .confirmActivation
                                        showAlert = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("\(override.symbol) \(override.name)")
                                                    .font(.headline)
                                                Text("Duration: \(formattedDuration(from: override.duration))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text("Insulin Scale Factor: \(String(format: "%.2f", override.insulinNeedsScaleFactor))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                if !override.targetRange.isEmpty {
                                                    let range = override.targetRange.map { Localizer.formatQuantity($0) }.joined(separator: " - ")
                                                    Text("Target Range: \(range) \(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView("Please wait...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Loop Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmActivation:
                    return Alert(
                        title: Text("Activate Override"),
                        message: Text("Do you want to activate the override '\(selectedOverride?.name ?? "")'?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            if let override = selectedOverride {
                                activateOverride(override: override)
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Cancel Override"),
                        message: Text("Are you sure you want to cancel the active override?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            cancelOverride()
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Success"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Error"),
                        message: Text(statusMessage ?? "An error occurred."),
                        dismissButton: .default(Text("OK"))
                    )
                case .validation:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? "Invalid input."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    // MARK: - Functions
    private func formattedDuration(from duration: Int?) -> String {
        guard let duration = duration, duration != 0 else {
            return "Indefinitely"
        }

        let hours = duration / 3600
        let minutes = (duration % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hr, \(minutes) min"
        } else if hours > 0 {
            return "\(hours) hr"
        } else {
            return "\(minutes) min"
        }
    }

    private func activateOverride(override: ProfileManager.LoopOverride) {
        isLoading = true
        viewModel.sendActivateOverrideRequest(override: override) { success, message in
            self.isLoading = false
            if success {
                self.statusMessage = "Override command sent successfully."
                self.alertType = .statusSuccess
            } else {
                self.statusMessage = message ?? "Failed to send override command."
                self.alertType = .statusFailure
            }
            self.showAlert = true
        }
    }

    private func cancelOverride() {
        isLoading = true
        viewModel.sendCancelOverrideRequest { success, message in
            self.isLoading = false
            if success {
                self.statusMessage = "Cancellation request successfully sent to Nightscout."
                self.alertType = .statusSuccess
            } else {
                self.statusMessage = message ?? "Failed to cancel temp target."
                self.alertType = .statusFailure
            }
            self.showAlert = true
        }
    }
}
