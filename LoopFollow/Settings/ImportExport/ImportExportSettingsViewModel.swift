// LoopFollow
// ImportExportSettingsViewModel.swift

import Foundation
import SwiftUI

struct ImportPreview {
    let nightscoutURL: String?
    let dexcomUsername: String?
    let remoteType: String?
    let alarmCount: Int
    let alarmNames: [String]
}

class ImportExportSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isShowingQRCodeScanner = false
    @Published var isShowingQRCodeDisplay = false
    @Published var isShowingAlarmSelection = false
    @Published var qrCodeErrorMessage = ""
    @Published var qrCodeString = ""
    @Published var exportType: ExportType = .nightscout
    @Published var exportedAlarmIds: Set<UUID> = []
    @Published var importPreview: ImportPreview?
    @Published var showImportConfirmation = false
    @Published var pendingImportSettings: CombinedSettingsExport?
    @Published var pendingImportSource: String = ""
    @Published var showExportSuccessAlert = false
    @Published var exportSuccessMessage = ""
    @Published var exportSuccessDetails: [String] = []
    @Published var showImportNotFoundAlert = false
    @Published var importNotFoundMessage = ""

    // MARK: - Export Types

    enum ExportType: String, CaseIterable {
        case nightscout = "Nightscout Settings"
        case remote = "Remote Settings"
        case alarms = "Alarm Settings"

        var icon: String {
            switch self {
            case .nightscout: return "network"
            case .remote: return "antenna.radiowaves.left.and.right"
            case .alarms: return "bell"
            }
        }
    }

    // MARK: - QR Code Methods

    func handleQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(jsonString):
                self.processImportedSettings(jsonString)
            case let .failure(error):
                self.qrCodeErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingQRCodeScanner = false
        }
    }

    private func processImportedSettings(_ jsonString: String) {
        do {
            LogManager.shared.log(category: .general, message: "Processing QR code data: \(jsonString.prefix(200))...")

            guard let data = jsonString.data(using: .utf8) else {
                qrCodeErrorMessage = "Invalid QR code data"
                return
            }

            LogManager.shared.log(category: .general, message: "QR code data converted to Data, size: \(data.count) bytes")

            // Try to decode as JSON first to see what we get
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                LogManager.shared.log(category: .general, message: "JSON parsing successful: \(jsonObject)")
            } catch {
                LogManager.shared.log(category: .general, message: "JSON parsing failed: \(error.localizedDescription)")
            }

            // Use migration manager to handle version compatibility
            guard let settings = SettingsMigrationManager.migrateSettings(data) else {
                LogManager.shared.log(category: .general, message: "SettingsMigrationManager.migrateSettings returned nil")
                qrCodeErrorMessage = "Failed to decode or migrate settings from QR code"
                return
            }

            LogManager.shared.log(category: .general, message: "QR code decoded successfully. Components: nightscout=\(settings.nightscout != nil), remote=\(settings.remote != nil), alarms=\(settings.alarms != nil)")

            // Check version compatibility
            let currentVersion = AppVersionManager().version()
            if !SettingsMigrationManager.isCompatibleVersion(settings.appVersion) {
                qrCodeErrorMessage = SettingsMigrationManager.getCompatibilityMessage(for: settings.appVersion)
                // Still try to apply settings, but warn user
            }

            // Store settings and create preview for confirmation
            pendingImportSettings = settings
            pendingImportSource = "QR code"
            createImportPreview(from: settings)

        } catch {
            let currentVersion = AppVersionManager().version()
            qrCodeErrorMessage = "Import failed. This might be due to a version change (current: \(currentVersion)). Please try exporting settings from the source device again."
            LogManager.shared.log(category: .general, message: "QR code import failed: \(error.localizedDescription)")
        }
    }

    private func applyImportedSettings(_ settings: CombinedSettingsExport, source: String) throws {
        var importedComponents: [String] = []

        // Apply settings based on what's available
        if let nightscout = settings.nightscout {
            // Check if Nightscout settings are already configured
            let currentNightscout = NightscoutSettingsExport.fromCurrentStorage()
            if currentNightscout.hasValidSettings() {
                // Nightscout is already configured, warn user about overwrite
                LogManager.shared.log(category: .general, message: "Warning: Nightscout settings are already configured. Import will overwrite existing Nightscout settings.")
            }

            nightscout.applyToStorage()
            importedComponents.append("Nightscout settings")
            LogManager.shared.log(category: .general, message: "Nightscout settings imported from \(source) (version: \(nightscout.version))")
        }

        if let dexcom = settings.dexcom {
            // Check if Dexcom settings are already configured
            let currentDexcom = DexcomSettingsExport.fromCurrentStorage()
            if currentDexcom.hasValidSettings() {
                LogManager.shared.log(category: .general, message: "Warning: Dexcom settings are already configured. Import will overwrite existing Dexcom settings.")
            }

            dexcom.applyToStorage()
            importedComponents.append("Dexcom settings")
            LogManager.shared.log(category: .general, message: "Dexcom settings imported from \(source) (version: \(dexcom.version))")
        }

        if let remote = settings.remote {
            if remote.hasValidSettings() {
                let validation = remote.validateCompatibilityWithCurrentStorage()
                if validation.isCompatible {
                    remote.applyToStorage()
                    importedComponents.append("Remote settings (\(remote.remoteType.rawValue))")
                    LogManager.shared.log(category: .general, message: "Remote settings imported from \(source) (version: \(remote.version), type: \(remote.remoteType.rawValue), device: \(remote.device))")
                } else {
                    throw NSError(domain: "SettingsImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Remote settings conflict: \(validation.message)"])
                }
            } else {
                throw NSError(domain: "SettingsImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid remote settings in \(source)"])
            }
        }

        if let alarms = settings.alarms {
            LogManager.shared.log(category: .general, message: "Attempting to import alarm settings: \(alarms.alarms.count) alarms")
            alarms.applyToStorage()
            importedComponents.append("Alarm settings (\(alarms.alarms.count) alarms)")
            LogManager.shared.log(category: .general, message: "Alarm settings imported from \(source) (version: \(alarms.version), \(alarms.alarms.count) alarms)")
        }

        // Update the success message with what was imported
        if !importedComponents.isEmpty {
            let componentsList = importedComponents.joined(separator: ", ")
            qrCodeErrorMessage = "Successfully imported: \(componentsList)"
        }
    }

    func generateQRCodeForExport() -> String? {
        let settings: CombinedSettingsExport?

        switch exportType {
        case .nightscout:
            let nightscoutSettings = NightscoutSettingsExport.fromCurrentStorage()
            if !nightscoutSettings.hasValidSettings() {
                qrCodeErrorMessage = "Please configure your Nightscout settings first (URL and Token)"
                return nil
            }
            settings = CombinedSettingsExport(
                nightscout: nightscoutSettings,
                exportType: exportType.rawValue
            )
        case .remote:
            let remoteSettings = RemoteSettingsExport.fromCurrentStorage()
            if !remoteSettings.hasValidSettings() {
                let currentRemoteType = Storage.shared.remoteType.value
                if currentRemoteType == .none {
                    qrCodeErrorMessage = "Please configure your Remote settings first (select a remote type and configure required fields)"
                } else {
                    qrCodeErrorMessage = "Please complete your Remote settings configuration (check required fields for \(currentRemoteType.rawValue))"
                }
                return nil
            }
            settings = CombinedSettingsExport(
                remote: remoteSettings,
                exportType: exportType.rawValue
            )
        case .alarms:
            let alarmSettings = AlarmSettingsExport.fromCurrentStorage()
            LogManager.shared.log(category: .general, message: "Generating alarm export: \(alarmSettings.alarms.count) alarms")
            if !alarmSettings.hasValidSettings() {
                qrCodeErrorMessage = "Please configure your Alarm settings first"
                return nil
            }
            settings = CombinedSettingsExport(
                alarms: alarmSettings,
                exportType: exportType.rawValue
            )
        }

        return settings?.encodeToJSON()
    }

    func showAlarmSelection() {
        exportType = .alarms
        isShowingAlarmSelection = true
    }

    func exportSelectedAlarms(_ selectedAlarms: [Alarm]) {
        let settings = AlarmSettingsExport.fromSelectedAlarms(selectedAlarms)
        if let qrString = settings.encodeToJSON() {
            qrCodeString = qrString
            isShowingQRCodeDisplay = true

            // Track which alarms were exported
            let exportedIds = Set(selectedAlarms.map { $0.id })
            exportedAlarmIds.formUnion(exportedIds)
        }
        isShowingAlarmSelection = false
    }

    func cancelAlarmSelection() {
        isShowingAlarmSelection = false
    }

    func resetExportedAlarms() {
        exportedAlarmIds.removeAll()
    }

    // MARK: - iCloud Methods (using Key-Value Storage)

    private var iCloudSettingsKey: String {
        "\(AppConstants.appInstanceId)_settings"
    }

    /// Check if iCloud Key-Value Storage is available
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    func exportToiCloud() {
        // Create a comprehensive settings export for iCloud
        let nightscoutSettings = NightscoutSettingsExport.fromCurrentStorage()
        let dexcomSettings = DexcomSettingsExport.fromCurrentStorage()
        let remoteSettings = RemoteSettingsExport.fromCurrentStorage()
        let alarmSettings = AlarmSettingsExport.fromCurrentStorage()

        let allSettings = CombinedSettingsExport(
            nightscout: nightscoutSettings,
            dexcom: dexcomSettings,
            remote: remoteSettings,
            alarms: alarmSettings,
            exportType: "All Settings"
        )

        guard let jsonString = allSettings.encodeToJSON() else {
            qrCodeErrorMessage = "Failed to prepare settings for iCloud export"
            return
        }

        guard isICloudAvailable() else {
            qrCodeErrorMessage = "iCloud is not available. Please sign in to iCloud in Settings."
            LogManager.shared.log(category: .general, message: "iCloud not available for export")
            return
        }

        LogManager.shared.log(category: .general, message: "Attempting to export settings to iCloud Key-Value Storage")

        let store = NSUbiquitousKeyValueStore.default
        store.set(jsonString, forKey: iCloudSettingsKey)
        store.set(Date(), forKey: "\(iCloudSettingsKey)_date")
        store.set(AppVersionManager().version(), forKey: "\(iCloudSettingsKey)_version")

        // Explicitly synchronize to push changes
        let synchronized = store.synchronize()
        LogManager.shared.log(category: .general, message: "iCloud KVS synchronize called, result: \(synchronized)")

        // Build export details for the success alert
        var details: [String] = []

        if !nightscoutSettings.url.isEmpty {
            details.append("Nightscout: \(nightscoutSettings.url)")
        }
        if !dexcomSettings.userName.isEmpty {
            details.append("Dexcom: \(dexcomSettings.userName)")
        }
        if remoteSettings.remoteType != .none {
            details.append("Remote: \(remoteSettings.remoteType.rawValue)")
        }
        if !alarmSettings.alarms.isEmpty {
            details.append("Alarms: \(alarmSettings.alarms.count) alarm(s)")
        }

        exportSuccessDetails = details
        exportSuccessMessage = "Settings saved to iCloud"
        showExportSuccessAlert = true
        qrCodeErrorMessage = ""

        LogManager.shared.log(category: .general, message: "All settings exported to iCloud Key-Value Storage successfully")
    }

    func importFromiCloud() {
        LogManager.shared.log(category: .general, message: "Attempting to import settings from iCloud Key-Value Storage")

        guard isICloudAvailable() else {
            importNotFoundMessage = "iCloud is not available.\n\nPlease sign in to iCloud in Settings."
            showImportNotFoundAlert = true
            LogManager.shared.log(category: .general, message: "iCloud not available for import")
            return
        }

        let store = NSUbiquitousKeyValueStore.default

        // Synchronize to get latest from iCloud
        store.synchronize()

        guard let jsonString = store.string(forKey: iCloudSettingsKey),
              let jsonData = jsonString.data(using: .utf8)
        else {
            importNotFoundMessage = "No settings file found in iCloud.\n\nMake sure you have previously exported settings to iCloud from this app."
            showImportNotFoundAlert = true
            LogManager.shared.log(category: .general, message: "No settings found in iCloud Key-Value Storage")
            return
        }

        LogManager.shared.log(category: .general, message: "Settings found in iCloud Key-Value Storage, attempting to decode")

        guard let settings = SettingsMigrationManager.migrateSettings(jsonData) else {
            qrCodeErrorMessage = "Failed to decode settings from iCloud"
            return
        }

        // Check version compatibility
        if !SettingsMigrationManager.isCompatibleVersion(settings.appVersion) {
            qrCodeErrorMessage = SettingsMigrationManager.getCompatibilityMessage(for: settings.appVersion)
        }

        // Store settings and create preview for confirmation
        pendingImportSettings = settings
        pendingImportSource = "iCloud"
        createImportPreview(from: settings)
    }

    private func createImportPreview(from settings: CombinedSettingsExport) {
        let nightscoutURL = settings.nightscout?.url.isEmpty == false ? settings.nightscout?.url : nil
        let dexcomUsername = settings.dexcom?.userName.isEmpty == false ? settings.dexcom?.userName : nil
        let remoteType = settings.remote?.remoteType != .none ? settings.remote?.remoteType.rawValue : nil
        let alarmCount = settings.alarms?.alarms.count ?? 0
        let alarmNames = settings.alarms?.alarms.map { $0.name } ?? []

        // Check if any settings are actually present
        let hasAnySettings = (nightscoutURL != nil && !nightscoutURL!.isEmpty) ||
            (dexcomUsername != nil && !dexcomUsername!.isEmpty) ||
            (remoteType != nil && !remoteType!.isEmpty && remoteType != "None") ||
            alarmCount > 0

        LogManager.shared.log(category: .general, message: "Import preview check - nightscoutURL: \(nightscoutURL ?? "nil"), dexcomUsername: \(dexcomUsername ?? "nil"), remoteType: \(remoteType ?? "nil"), alarmCount: \(alarmCount), hasAnySettings: \(hasAnySettings)")

        if hasAnySettings {
            LogManager.shared.log(category: .general, message: "Creating import preview with settings")
            importPreview = ImportPreview(
                nightscoutURL: nightscoutURL,
                dexcomUsername: dexcomUsername,
                remoteType: remoteType,
                alarmCount: alarmCount,
                alarmNames: alarmNames
            )
            LogManager.shared.log(category: .general, message: "Created importPreview - nightscoutURL: \(importPreview?.nightscoutURL ?? "nil"), remoteType: \(importPreview?.remoteType ?? "nil"), alarmCount: \(importPreview?.alarmCount ?? 0)")
            showImportConfirmation = true
            LogManager.shared.log(category: .general, message: "Set showImportConfirmation = true")
        } else {
            LogManager.shared.log(category: .general, message: "No settings found, clearing import data")
            // No settings found, show alert and clear any pending data
            importNotFoundMessage = "The settings file exists but contains no valid settings to import."
            showImportNotFoundAlert = true
            showImportConfirmation = false
            importPreview = nil
            pendingImportSettings = nil
            pendingImportSource = ""
            LogManager.shared.log(category: .general, message: "Set showImportConfirmation = false")
        }
    }

    func confirmImport() {
        guard let settings = pendingImportSettings else { return }

        do {
            try applyImportedSettings(settings, source: pendingImportSource)
        } catch {
            qrCodeErrorMessage = "Import failed: \(error.localizedDescription)"
        }

        // Reset confirmation state
        showImportConfirmation = false
        importPreview = nil
        pendingImportSettings = nil
        pendingImportSource = ""
    }

    func cancelImport() {
        showImportConfirmation = false
        importPreview = nil
        pendingImportSettings = nil
        pendingImportSource = ""
    }
}
