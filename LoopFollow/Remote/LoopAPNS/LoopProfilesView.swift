// LoopFollow
// LoopProfilesView.swift

import HealthKit
import SwiftUI

/// Lists the profiles saved in Loop. Selecting one shows its values before it can be activated.
struct LoopProfilesView: View {
    @ObservedObject private var loopProfiles = Observable.shared.loopProfiles

    var body: some View {
        List {
            if let profileSet = loopProfiles.value, !profileSet.profiles.isEmpty {
                Section(
                    header: Text("Saved profiles"),
                    footer: uploadedFooter(profileSet.uploadedAt)
                ) {
                    ForEach(profileSet.profiles) { profile in
                        NavigationLink(destination: LoopProfilePreviewView(profile: profile)) {
                            HStack {
                                Text(profile.name)
                                Spacer()
                                if profile.name == profileSet.activeName {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No saved profiles found. Profiles are saved in Loop under Settings → Profiles.")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .navigationBarTitle("Remote Profiles", displayMode: .inline)
    }

    private func uploadedFooter(_ date: Date?) -> Text {
        guard let date else { return Text("") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return Text("Uploaded by Loop \(formatter.string(from: date)).")
    }
}

/// Shows the values a profile switch would activate, the same sections Loop shows before loading a profile.
struct LoopProfilePreviewView: View {
    let profile: LoopProfile

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var loopProfiles = Observable.shared.loopProfiles
    @ObservedObject private var tracker = RemoteCommandTracker.shared
    @State private var alertType: AlertType?

    private enum AlertType: Identifiable {
        case confirm
        case result(success: Bool, message: String)

        var id: String {
            switch self {
            case .confirm: return "confirm"
            case let .result(success, message): return "result-\(success)-\(message)"
            }
        }
    }

    private var commandKey: String {
        LoopProfileAckAdapter.key(for: profile.name)
    }

    private var isActive: Bool {
        loopProfiles.value?.activeName == profile.name
    }

    private var isSending: Bool {
        tracker.isBusy(key: commandKey)
    }

    /// Only one profile switch is in flight at a time.
    private var otherSwitchPending: Bool {
        !isSending && tracker.isBusy(keyPrefix: LoopProfileAckAdapter.keyPrefix)
    }

    private var commandState: RemoteCommandTracker.State? {
        tracker.states[commandKey]
    }

    var body: some View {
        List {
            Section(footer: Text("Loop writes the basal rates to the pump when the profile is activated.")) {
                Text("Review the profile before activating it in Loop.")
            }

            Section(header: Text("Correction Range")) {
                ForEach(profile.correctionRange, id: \.seconds) { item in
                    LabeledValueRow(
                        label: Self.timeText(item.seconds),
                        value: "\(glucoseText(item.low)) – \(glucoseText(item.high)) \(glucoseUnitText)"
                    )
                }
            }

            Section(header: Text("Carb Ratios")) {
                ForEach(profile.carbRatio, id: \.seconds) { item in
                    LabeledValueRow(
                        label: Self.timeText(item.seconds),
                        value: "\(Localizer.formatToLocalizedString(item.value, maxFractionDigits: 1)) g/U"
                    )
                }
            }

            Section(header: Text("Basal Rates")) {
                ForEach(profile.basal, id: \.seconds) { item in
                    LabeledValueRow(
                        label: Self.timeText(item.seconds),
                        value: "\(Localizer.formatToLocalizedString(item.value, maxFractionDigits: 3)) U/hr"
                    )
                }
                HStack {
                    Text("Total").bold()
                    Spacer()
                    Text("\(Localizer.formatToLocalizedString(profile.basalTotal, maxFractionDigits: 2, minFractionDigits: 2)) U/day")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Insulin Sensitivities")) {
                ForEach(profile.sensitivity, id: \.seconds) { item in
                    LabeledValueRow(
                        label: Self.timeText(item.seconds),
                        value: "\(glucoseText(item.value)) \(glucoseUnitText)/U"
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                alertType = .confirm
            } label: {
                if isSending {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for Loop...")
                    }
                    .frame(maxWidth: .infinity)
                } else if otherSwitchPending {
                    Text("Another Switch Is Pending").frame(maxWidth: .infinity)
                } else {
                    Text(isActive ? "Active Profile" : "Activate Profile").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isActive || isSending || otherSwitchPending)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationBarTitle(profile.name, displayMode: .inline)
        .onAppear { showResult(commandState) }
        .onChange(of: commandState) { _, state in showResult(state) }
        .alert(item: $alertType) { type in
            switch type {
            case .confirm:
                return Alert(
                    title: Text("Activate \(profile.name) in Loop?"),
                    message: Text("Loop replaces its correction range, carb ratios, basal rates and insulin sensitivities with these values and writes the basal rates to the pump."),
                    primaryButton: .default(Text("Activate"), action: authenticateAndSend),
                    secondaryButton: .cancel()
                )
            case let .result(success, message):
                return Alert(
                    title: Text(success ? "Profile Activated" : message == LoopProfileAckAdapter.timeoutMessage ? "No Reply From Loop" : "Profile Not Activated"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        if success { presentationMode.wrappedValue.dismiss() }
                    }
                )
            }
        }
    }

    /// Shows a finished command once, also when the view was left while it was pending.
    private func showResult(_ state: RemoteCommandTracker.State?) {
        guard case let .done(success, message) = state else { return }
        tracker.consume(key: commandKey)
        presentResult(success: success, message: message)
    }

    /// A result that arrives at once comes while the confirmation alert is still closing.
    private func presentResult(success: Bool, message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alertType = .result(success: success, message: message)
        }
    }

    private func authenticateAndSend() {
        AuthService.authenticate(reason: "Confirm your identity to activate \(profile.name) in Loop.") { result in
            switch result {
            case .success:
                send()
            case let .unavailable(message):
                presentResult(success: false, message: message)
            case .failed:
                presentResult(success: false, message: "Authentication failed")
            case .canceled:
                break
            }
        }
    }

    private func send() {
        RemoteCommandTracker.shared.sendLoopProfileSwitch(profile: profile) { success, error in
            if !success {
                LogManager.shared.log(category: .apns, message: "Profile switch not sent: \(error ?? "unknown error")")
            }
        }
    }

    private var glucoseUnitText: String {
        Localizer.getPreferredUnit() == .milligramsPerDeciliter ? "mg/dL" : "mmol/L"
    }

    private func glucoseText(_ value: Double) -> String {
        Localizer.formatQuantity(HKQuantity(unit: profile.units, doubleValue: value))
    }

    /// Schedule start times are offsets from midnight in the profile's time zone.
    static func timeText(_ seconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}

/// A remote command button for a command the connected Loop build does not offer.
struct UnavailableCommandButtonView: View {
    let command: String
    let iconName: String
    let title: String
    let message: String

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            VStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Text(command)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(Color.gray.opacity(0.35))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .alert(isPresented: $showInfo) {
            Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("OK")))
        }
    }
}
