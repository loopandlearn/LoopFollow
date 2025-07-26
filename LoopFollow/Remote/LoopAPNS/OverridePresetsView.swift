// LoopFollow
// OverridePresetsView.swift
// Created by codebymini.

import SwiftUI

struct OverridePresetsView: View {
    @StateObject private var viewModel = OverridePresetsViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Available Overrides")) {
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading override presets...")
                                    .foregroundColor(.secondary)
                            }
                        } else if viewModel.overridePresets.isEmpty {
                            Text("No override presets found. Configure presets in your Loop app.")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(viewModel.overridePresets, id: \.name) { preset in
                                OverridePresetRow(
                                    preset: preset,
                                    isActivating: viewModel.isActivating && viewModel.selectedPreset?.name == preset.name,
                                    onActivate: {
                                        viewModel.selectedPreset = preset
                                        viewModel.alertType = .confirmActivation
                                        viewModel.showAlert = true
                                    }
                                )
                            }
                        }
                    }

                    if !viewModel.overridePresets.isEmpty {
                        Section {
                            Button(action: {
                                viewModel.alertType = .confirmCancellation
                                viewModel.showAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Text("Cancel Active Override")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                if viewModel.isActivating {
                    ProgressView("Please wait...")
                        .padding()
                }
            }
            .navigationBarTitle("Remote Overrides", displayMode: .inline)
            .onAppear {
                Task {
                    await viewModel.loadOverridePresets()
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
                case .confirmActivation:
                    return Alert(
                        title: Text("Activate Override"),
                        message: Text("Do you want to activate the override '\(viewModel.selectedPreset?.name ?? "")'?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            if let preset = viewModel.selectedPreset {
                                Task {
                                    await viewModel.activateOverride(preset: preset)
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Cancel Override"),
                        message: Text("Are you sure you want to cancel the active override?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            Task {
                                await viewModel.cancelOverride()
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Success"),
                        message: Text(viewModel.statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Error"),
                        message: Text(viewModel.statusMessage ?? "An error occurred."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }
}

struct OverridePresetRow: View {
    let preset: OverridePreset
    let isActivating: Bool
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack {
                if let symbol = preset.symbol {
                    Text(symbol)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let targetRange = preset.targetRange {
                            Text("Target: \(Int(targetRange.lowerBound))-\(Int(targetRange.upperBound))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let insulinNeedsScaleFactor = preset.insulinNeedsScaleFactor {
                            Text("Insulin: \(Int(insulinNeedsScaleFactor * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("Duration: \(preset.durationDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isActivating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isActivating)
    }
}

class OverridePresetsViewModel: ObservableObject {
    @Published var overridePresets: [OverridePreset] = []
    @Published var isLoading = false
    @Published var isActivating = false
    @Published var showAlert = false
    @Published var alertType: AlertType? = nil
    @Published var statusMessage: String? = nil
    @Published var selectedPreset: OverridePreset? = nil

    enum AlertType {
        case confirmActivation
        case confirmCancellation
        case statusSuccess
        case statusFailure
    }

    func loadOverridePresets() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let presets = try await fetchOverridePresetsFromNightscout()
            await MainActor.run {
                self.overridePresets = presets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Failed to load override presets: \(error.localizedDescription)"
                self.alertType = .statusFailure
                self.showAlert = true
                self.isLoading = false
            }
        }
    }

    func activateOverride(preset: OverridePreset) async {
        await MainActor.run {
            isActivating = true
        }

        do {
            try await sendOverrideNotification(preset: preset)
            await MainActor.run {
                self.isActivating = false
                self.statusMessage = "\(preset.name) override activated successfully."
                self.alertType = .statusSuccess
                self.showAlert = true
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Failed to activate override: \(error.localizedDescription)"
                self.alertType = .statusFailure
                self.showAlert = true
                self.isActivating = false
            }
        }
    }

    func cancelOverride() async {
        await MainActor.run {
            isActivating = true
        }

        do {
            try await sendCancelOverrideNotification()
            await MainActor.run {
                self.isActivating = false
                self.statusMessage = "Active override cancelled successfully."
                self.alertType = .statusSuccess
                self.showAlert = true
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Failed to cancel override: \(error.localizedDescription)"
                self.alertType = .statusFailure
                self.showAlert = true
                self.isActivating = false
            }
        }
    }

    private func fetchOverridePresetsFromNightscout() async throws -> [OverridePreset] {
        // Use ProfileManager's already loaded overrides instead of fetching from Nightscout
        let loopOverrides = ProfileManager.shared.loopOverrides

        return loopOverrides.map { override in
            let targetRange: ClosedRange<Double>?
            if override.targetRange.count >= 2 {
                let lowValue = override.targetRange[0].doubleValue(for: ProfileManager.shared.units)
                let highValue = override.targetRange[1].doubleValue(for: ProfileManager.shared.units)
                targetRange = lowValue ... highValue
            } else {
                targetRange = nil
            }

            return OverridePreset(
                name: override.name,
                symbol: override.symbol.isEmpty ? nil : override.symbol,
                targetRange: targetRange,
                insulinNeedsScaleFactor: override.insulinNeedsScaleFactor,
                duration: TimeInterval(override.duration ?? 0)
            )
        }
    }

    private func sendOverrideNotification(preset: OverridePreset) async throws {
        let apnsService = LoopAPNSService()
        try await apnsService.sendOverrideNotification(
            presetName: preset.name,
            duration: preset.duration
        )
    }

    private func sendCancelOverrideNotification() async throws {
        let apnsService = LoopAPNSService()
        try await apnsService.sendCancelOverrideNotification()
    }
}

// MARK: - Data Models

struct OverridePreset {
    let name: String
    let symbol: String?
    let targetRange: ClosedRange<Double>?
    let insulinNeedsScaleFactor: Double?
    let duration: TimeInterval

    var durationDescription: String {
        if duration == 0 {
            return "Indefinite"
        } else {
            let hours = Int(duration) / 3600
            let minutes = Int(duration) % 3600 / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
}

enum OverrideError: LocalizedError {
    case nightscoutNotConfigured
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .nightscoutNotConfigured:
            return "Nightscout URL and token not configured in settings"
        case .invalidResponse:
            return "Invalid response from server"
        case let .serverError(code):
            return "Server error: \(code)"
        }
    }
}
