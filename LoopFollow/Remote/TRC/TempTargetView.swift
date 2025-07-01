// LoopFollow
// TempTargetView.swift
// Created by Jonas Björkert.

import HealthKit
import SwiftUI

struct TempTargetView: View {
    @Environment(\.presentationMode) private var presentationMode
    private let pushNotificationManager = PushNotificationManager()

    @ObservedObject var device = Storage.shared.device
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
        case statusSuccess
        case statusFailure
        case validation
        case confirmCancellation
    }

    var body: some View {
        NavigationView {
            VStack {
                if device.value != "Trio" {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Trio."
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
                case .statusSuccess:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"))
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

        pushNotificationManager.sendTempTargetPushNotification(target: newHKTarget, duration: duration) { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Temp target command successfully sent."
                    self.alertType = .statusSuccess
                    LogManager.shared.log(category: .apns, message: "sendTempTargetPushNotification succeeded with target: \(newHKTarget), duration: \(duration)")
                } else {
                    self.statusMessage = errorMessage ?? "Failed to send temp target command."
                    self.alertType = .statusFailure
                    LogManager.shared.log(category: .apns, message: "sendTempTargetPushNotification failed with target: \(newHKTarget), duration: \(duration), error: \(errorMessage ?? "unknown error")")
                }
                self.showAlert = true
            }
        }
    }

    private func cancelTempTarget() {
        isLoading = true

        pushNotificationManager.sendCancelTempTargetPushNotification { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Cancel temp target command successfully sent."
                    self.alertType = .statusSuccess
                    LogManager.shared.log(category: .apns, message: "sendCancelTempTargetPushNotification succeeded")
                } else {
                    self.statusMessage = errorMessage ?? "Failed to send cancel temp target command."
                    self.alertType = .statusFailure
                    LogManager.shared.log(category: .apns, message: "sendCancelTempTargetPushNotification failed with error: \(errorMessage ?? "unknown error")")
                }
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
