// LoopFollow
// TrioNightscoutRemoteView.swift
// Created by Jonas Björkert on 2024-07-19.

import HealthKit
import SwiftUI

struct TrioNightscoutRemoteView: View {
    private let remoteController = TrioNightscoutRemoteController()

    @ObservedObject var nightscoutURL = ObservableUserDefaults.shared.url
    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var nsWriteAuth = ObservableUserDefaults.shared.nsWriteAuth
    @ObservedObject var tempTarget = Observable.shared.tempTarget

    @State private var newHKTarget = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0.0)
    @State private var duration = HKQuantity(unit: .minute(), doubleValue: 0.0)
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    @State private var showPresetSheet: Bool = false
    @State private var presetName = ""
    @ObservedObject var presetManager = TempTargetPresetManager.shared

    @FocusState private var targetFieldIsFocused: Bool
    @FocusState private var durationFieldIsFocused: Bool

    enum AlertType {
        case confirmCommand
        case status
        case validation
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
                        message: "Please update your token to include the 'careportal' and 'readable' roles in order to do remote commands with Trio."
                    )
                } else {
                    Form {
                        if let tempTargetValue = tempTarget.value {
                            Section(header: Text("Existing Temp Target")) {
                                HStack {
                                    Text("Current Target")
                                    Spacer()
                                    Text(Localizer.formatQuantity(tempTargetValue))
                                    Text(Localizer.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
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
                                TextFieldWithToolBar(
                                    quantity: $newHKTarget,
                                    maxLength: 4,
                                    unit: Localizer.getPreferredUnit(),
                                    minValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80),
                                    maxValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200),
                                    onValidationError: { message in
                                        handleValidationError(message)
                                    }
                                )
                                .focused($targetFieldIsFocused)
                                Text(Localizer.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Duration")
                                Spacer()
                                TextFieldWithToolBar(
                                    quantity: $duration,
                                    maxLength: 4,
                                    unit: HKUnit.minute(),
                                    minValue: HKQuantity(unit: .minute(), doubleValue: 5),
                                    onValidationError: { message in
                                        handleValidationError(message)
                                    }
                                )
                                .focused($durationFieldIsFocused)
                                Text("minutes").foregroundColor(.secondary)
                            }
                            HStack {
                                Button {
                                    alertType = .confirmCommand
                                    showAlert = true
                                    targetFieldIsFocused = false
                                    durationFieldIsFocused = false
                                } label: {
                                    Text("Enact")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)

                                Spacer()

                                Button {
                                    showPresetSheet = true
                                    targetFieldIsFocused = false
                                    durationFieldIsFocused = false
                                } label: {
                                    Text("Save as Preset")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)
                            }
                        }

                        if !presetManager.presets.isEmpty {
                            Section(header: Text("Presets")) {
                                ForEach(presetManager.presets) { preset in
                                    HStack {
                                        Text(preset.name)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        alertType = .confirmCommand
                                        newHKTarget = preset.target
                                        duration = preset.duration
                                        showAlert = true
                                        targetFieldIsFocused = false
                                        durationFieldIsFocused = false
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            if let index = presetManager.presets.firstIndex(where: { $0.id == preset.id }) {
                                                presetManager.deletePreset(at: index)
                                            }
                                            targetFieldIsFocused = false
                                            durationFieldIsFocused = false
                                        } label: {
                                            Label("Delete", systemImage: "trash")
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
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmCommand:
                    return Alert(
                        title: Text("Confirm Command"),
                        message: Text("New Target: \(Localizer.formatQuantity(newHKTarget)) \(Localizer.getPreferredUnit().localizedShortUnitString)\nDuration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"),
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
            .sheet(isPresented: $showPresetSheet) {
                VStack {
                    Text("Save Preset")
                        .font(.headline)
                        .padding()
                    TextField("Preset Name", text: $presetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    HStack {
                        Button("Cancel") {
                            showPresetSheet = false
                        }
                        .padding()
                        Spacer()
                        Button("Save") {
                            presetManager.addPreset(name: presetName, target: newHKTarget, duration: duration)
                            presetName = ""
                            showPresetSheet = false
                        }
                        .disabled(presetName.isEmpty)
                        .padding()
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }

    private var isButtonDisabled: Bool {
        return newHKTarget.doubleValue(for: Localizer.getPreferredUnit()) == 0 ||
            duration.doubleValue(for: HKUnit.minute()) == 0 || isLoading
    }

    private func enactTempTarget() {
        isLoading = true
        remoteController.sendTempTarget(newTarget: newHKTarget, duration: duration) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Command successfully sent to Nightscout."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "sendTempTarget succeeded - New Target: \(Localizer.formatQuantity(newHKTarget)) \(Localizer.getPreferredUnit().localizedShortUnitString), Duration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"
                    )
                } else {
                    self.statusMessage = "Failed to enact target."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "sendTempTarget failed - New Target: \(Localizer.formatQuantity(newHKTarget)) \(Localizer.getPreferredUnit().localizedShortUnitString), Duration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"
                    )
                }
                self.alertType = .status
                self.showAlert = true
            }
        }
    }

    private func cancelTempTarget() {
        isLoading = true
        remoteController.cancelExistingTarget { success in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Cancellation request successfully sent to Nightscout."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "cancelExistingTarget succeeded"
                    )
                } else {
                    self.statusMessage = "Failed to cancel temp target."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "cancelExistingTarget failed"
                    )
                }
                self.alertType = .status
                self.showAlert = true
            }
        }
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }
}
