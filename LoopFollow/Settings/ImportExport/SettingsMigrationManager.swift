// LoopFollow
// SettingsMigrationManager.swift

import Foundation

class SettingsMigrationManager {
    // MARK: - Current Version

    static let currentVersion = "1.0"

    // MARK: - Migration Methods

    static func migrateSettings(_ data: Data) -> CombinedSettingsExport? {
        // Try to decode with the current version
        do {
            let currentSettings = try JSONDecoder().decode(CombinedSettingsExport.self, from: data)
            print("✅ Successfully decoded CombinedSettingsExport")
            return currentSettings
        } catch {
            print("❌ Failed to decode CombinedSettingsExport: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // Try to decode as individual components
            return tryDecodeIndividualComponents(data)
        }
    }

    private static func tryDecodeIndividualComponents(_ data: Data) -> CombinedSettingsExport? {
        // Try to decode as AlarmSettingsExport
        if let alarmSettings = try? JSONDecoder().decode(AlarmSettingsExport.self, from: data) {
            print("✅ Successfully decoded as AlarmSettingsExport")
            return CombinedSettingsExport(
                alarms: alarmSettings,
                exportType: "Alarm Settings"
            )
        }

        // Try to decode as NightscoutSettingsExport
        if let nightscoutSettings = try? JSONDecoder().decode(NightscoutSettingsExport.self, from: data) {
            print("✅ Successfully decoded as NightscoutSettingsExport")
            return CombinedSettingsExport(
                nightscout: nightscoutSettings,
                exportType: "Nightscout Settings"
            )
        }

        // Try to decode as DexcomSettingsExport
        if let dexcomSettings = try? JSONDecoder().decode(DexcomSettingsExport.self, from: data) {
            print("✅ Successfully decoded as DexcomSettingsExport")
            return CombinedSettingsExport(
                dexcom: dexcomSettings,
                exportType: "Dexcom Settings"
            )
        }

        // Try to decode as RemoteSettingsExport
        if let remoteSettings = try? JSONDecoder().decode(RemoteSettingsExport.self, from: data) {
            print("✅ Successfully decoded as RemoteSettingsExport")
            return CombinedSettingsExport(
                remote: remoteSettings,
                exportType: "Remote Settings"
            )
        }

        print("❌ Failed to decode as any known component")
        return nil
    }

    // MARK: - Version Compatibility

    static func isCompatibleVersion(_ version: String) -> Bool {
        let currentVersionComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        let importVersionComponents = version.split(separator: ".").compactMap { Int($0) }

        // For now, accept any version (can be made more strict later)
        return true
    }

    static func getCompatibilityMessage(for version: String) -> String {
        return "Settings from version \(version) may not be fully compatible with current version \(currentVersion). Some features may not work as expected."
    }

    // MARK: - Error Handling

    enum SettingsImportError: Error {
        case unsupportedVersion(String)
        case migrationFailed(String)
        case corruptedData
        case incompatibleAlarmFormat
        case unknownError
    }
}
