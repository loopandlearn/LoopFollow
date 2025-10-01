// LoopFollow
// OverridePresetsView.swift

import SwiftUI

struct OverridePresetsView: View {
    @StateObject private var viewModel = OverridePresetsViewModel()
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var overrideNote = Observable.shared.override

    var body: some View {
        NavigationView {
            VStack {
                List {
                    // Current Active Override Section
                    if let activeNote = overrideNote.value {
                        Section(header: Text("Active Override")) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Override")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(activeNote)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)

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
                                        viewModel.showOverrideModal = true
                                    }
                                )
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
            .sheet(isPresented: $viewModel.showOverrideModal) {
                if let preset = viewModel.selectedPreset {
                    OverrideActivationModal(
                        preset: preset,
                        onActivate: { duration in
                            viewModel.showOverrideModal = false
                            Task {
                                await viewModel.activateOverride(preset: preset, duration: duration)
                            }
                        },
                        onCancel: {
                            viewModel.showOverrideModal = false
                        }
                    )
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
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
                            Text("Target: \(Localizer.formatLocalDouble(targetRange.lowerBound))-\(Localizer.formatLocalDouble(targetRange.upperBound))")
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

struct OverrideActivationModal: View {
    let preset: OverridePreset
    let onActivate: (TimeInterval?) -> Void
    let onCancel: () -> Void

    @State private var enableIndefinitely: Bool
    @State private var durationHours: Double = 1.0

    init(preset: OverridePreset, onActivate: @escaping (TimeInterval?) -> Void, onCancel: @escaping () -> Void) {
        self.preset = preset
        self.onActivate = onActivate
        self.onCancel = onCancel

        // Initialize state based on preset duration
        if preset.duration == 0 {
            // Indefinite override - allow user to choose
            _enableIndefinitely = State(initialValue: true)
        } else {
            // Override with predefined duration - use preset duration
            _enableIndefinitely = State(initialValue: false)
            _durationHours = State(initialValue: preset.duration / 3600)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preset Info
                VStack(spacing: 12) {
                    if let symbol = preset.symbol {
                        Text(symbol)
                            .font(.largeTitle)
                    }

                    Text(preset.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    if let targetRange = preset.targetRange {
                        Text("Target: \(Localizer.formatLocalDouble(targetRange.lowerBound))-\(Localizer.formatLocalDouble(targetRange.upperBound))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let insulinNeedsScaleFactor = preset.insulinNeedsScaleFactor {
                        Text("Insulin: \(Int(insulinNeedsScaleFactor * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Only show duration for overrides with predefined duration
                    if preset.duration != 0 {
                        Text("Duration: \(preset.durationDescription)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)

                Spacer()

                // Duration Settings (only show for overrides without predefined duration)
                if preset.duration == 0 {
                    VStack(spacing: 16) {
                        // Duration Input (only show when not indefinite)
                        if !enableIndefinitely {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Duration")
                                        .font(.headline)
                                    Spacer()
                                    Text(formatDuration(durationHours))
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }

                                Slider(value: $durationHours, in: 0.25 ... 24.0, step: 0.25)
                                    .accentColor(.blue)
                                HStack {
                                    Text("15m")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Spacer()
                                    Text("24h")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .trailing)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Indefinitely Toggle
                        HStack {
                            Toggle("Enable indefinitely", isOn: $enableIndefinitely)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        let duration: TimeInterval?
                        if preset.duration == 0 {
                            // For indefinite overrides, use user selection
                            duration = enableIndefinitely ? nil : (durationHours * 3600)
                        } else {
                            // For overrides with predefined duration, use preset duration
                            duration = preset.duration
                        }
                        onActivate(duration)
                    }) {
                        Text("Activate Override")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitle("Activate Override", displayMode: .inline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }

    // Helper function to format duration in hours and minutes
    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
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
    @Published var showOverrideModal = false

    enum AlertType {
        case confirmCancellation
        case statusSuccess
        case statusFailure
    }

    func loadOverridePresets() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let presets = try await fetchOverridePresetsFromStorage()
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

    func activateOverride(preset: OverridePreset, duration: TimeInterval?) async {
        await MainActor.run {
            isActivating = true
        }

        do {
            try await sendOverrideNotification(preset: preset, duration: duration)
            await MainActor.run {
                self.isActivating = false
                self.statusMessage = "\(preset.name) override activated successfully."
                self.alertType = .statusSuccess
                self.showAlert = true
            }
        } catch {
            await MainActor.run {
                self.isActivating = false
                self.statusMessage = "Failed to activate override: \(error.localizedDescription)"
                self.alertType = .statusFailure
                self.showAlert = true
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
                self.isActivating = false
                self.statusMessage = "Failed to cancel override: \(error.localizedDescription)"
                self.alertType = .statusFailure
                self.showAlert = true
            }
        }
    }

    private func fetchOverridePresetsFromStorage() async throws -> [OverridePreset] {
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

    private func sendOverrideNotification(preset: OverridePreset, duration: TimeInterval?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let apnsService = LoopAPNSService()
            apnsService.sendOverrideNotification(
                presetName: preset.name,
                duration: duration
            ) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "OverrideError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Unknown error"]))
                }
            }
        }
    }

    private func sendCancelOverrideNotification() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let apnsService = LoopAPNSService()
            apnsService.sendCancelOverrideNotification { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "OverrideError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Unknown error"]))
                }
            }
        }
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
