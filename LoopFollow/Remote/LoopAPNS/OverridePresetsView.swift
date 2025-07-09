// LoopFollow
// OverridePresetsView.swift
// Created by codebymini.

import SwiftUI

struct OverridePresetsView: View {
    @StateObject private var viewModel = OverridePresetsViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
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
                                isActivating: viewModel.isActivating,
                                onActivate: {
                                    Task {
                                        await viewModel.activateOverride(preset: preset)
                                    }
                                }
                            )
                        }
                    }
                }

                if !viewModel.overridePresets.isEmpty {
                    Section {
                        Button(action: {
                            Task {
                                await viewModel.cancelOverride()
                            }
                        }) {
                            HStack {
                                if viewModel.isActivating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.red)
                                } else {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                                Text("Cancel Active Override")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(viewModel.isActivating)
                    }
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if let successMessage = viewModel.successMessage, !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Remote Overrides", displayMode: .inline)
            .onAppear {
                viewModel.dismiss = { presentationMode.wrappedValue.dismiss() }
                Task {
                    await viewModel.loadOverridePresets()
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {}
            } message: {
                Text(viewModel.successAlertMessage)
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
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showSuccessAlert = false
    @Published var successAlertMessage = ""

    var dismiss: (() -> Void)?

    func loadOverridePresets() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let presets = try await fetchOverridePresetsFromNightscout()
            await MainActor.run {
                self.overridePresets = presets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load override presets: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func activateOverride(preset: OverridePreset) async {
        await MainActor.run {
            isActivating = true
            errorMessage = nil
            successMessage = nil
        }

        do {
            try await sendOverrideNotification(preset: preset)
            await MainActor.run {
                self.isActivating = false
                self.successMessage = "\(preset.name) override activated successfully!"
                self.successAlertMessage = "\(preset.name) Override Activated!"
                self.showSuccessAlert = true

                // Dismiss the view after successful activation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.dismiss?()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to activate override: \(error.localizedDescription)"
                self.isActivating = false
            }
        }
    }

    func cancelOverride() async {
        await MainActor.run {
            isActivating = true
            errorMessage = nil
            successMessage = nil
        }

        do {
            try await sendCancelOverrideNotification()
            await MainActor.run {
                self.isActivating = false
                self.successMessage = "Active override cancelled successfully!"

                // Dismiss the view after successful cancellation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.dismiss?()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to cancel override: \(error.localizedDescription)"
                self.isActivating = false
            }
        }
    }

    private func fetchOverridePresetsFromNightscout() async throws -> [OverridePreset] {
        let url = Storage.shared.url.value
        guard !url.isEmpty else {
            throw OverrideError.nightscoutNotConfigured
        }

        let token = Storage.shared.token.value
        guard !token.isEmpty else {
            throw OverrideError.nightscoutNotConfigured
        }

        let nightscoutURL = URL(string: url)!
        let profileURL = nightscoutURL.appendingPathComponent("api/v1/profile.json")

        var request = URLRequest(url: profileURL)

        // Add token authentication
        var components = URLComponents(url: profileURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        if let urlWithToken = components?.url {
            request.url = urlWithToken
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OverrideError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OverrideError.serverError(httpResponse.statusCode)
        }

        let profiles = try JSONDecoder().decode([ProfileData].self, from: data)

        // Find the most recent profile with loopSettings
        guard let latestProfile = profiles.first(where: { $0.loopSettings?.overridePresets != nil }) else {
            return []
        }

        return latestProfile.loopSettings!.overridePresets.map { preset in
            OverridePreset(
                name: preset.name,
                symbol: preset.symbol,
                targetRange: preset.targetRange,
                insulinNeedsScaleFactor: preset.insulinNeedsScaleFactor,
                duration: preset.duration
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

struct ProfileData: Codable {
    let loopSettings: LoopSettings?
}

struct LoopSettings: Codable {
    let overridePresets: [OverridePresetData]
}

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
