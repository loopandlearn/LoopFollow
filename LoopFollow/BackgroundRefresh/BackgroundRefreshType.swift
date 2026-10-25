// LoopFollow
// BackgroundRefreshType.swift

import Foundation

enum BackgroundRefreshType: String, Codable, CaseIterable {
    case none = "None"
    case silentTune = "Silent Tune"
    case rileyLink = "RileyLink"
    case dexcom = "Dexcom"
    case omnipodDash = "Omnipod Dash"
    case hub = "LoopFollow Hub"

    /// The mode the app runs in: the selected one, except that LoopFollow Hub runs
    /// as Silent Tune until the hub drives the alarms.
    static var inEffect: BackgroundRefreshType {
        let selected = Storage.shared.backgroundRefreshType.value
        return selected == .hub && !HubClient.shared.drivesAlarms ? .silentTune : selected
    }

    /// The app keeps itself running in the background (and so is watched for
    /// stalls). In Hub mode the hub does the work and the app may be suspended.
    var keepsAppRunning: Bool {
        switch self {
        case .silentTune, .rileyLink, .dexcom, .omnipodDash:
            return true
        case .none, .hub:
            return false
        }
    }

    /// Indicates if the device type uses Bluetooth
    var isBluetooth: Bool {
        switch self {
        case .rileyLink, .dexcom, .omnipodDash:
            return true
        case .silentTune, .none, .hub:
            return false
        }
    }

    var heartBeatInterval: TimeInterval? {
        switch self {
        case .rileyLink:
            return 60
        case .omnipodDash:
            return 3 * 60
        case .dexcom:
            return 5 * 60
        case .silentTune, .none, .hub:
            return nil
        }
    }

    var estimatedDelayBasedOnHeartbeat: Bool {
        switch self {
        case .rileyLink:
            return true
        case .dexcom, .omnipodDash, .silentTune, .none, .hub:
            return false
        }
    }

    /// Determines if a BLEDevice matches the specific device type
    func matches(_ device: BLEDevice) -> Bool {
        switch self {
        case .rileyLink:
            let rileyUUIDString = "0235733b-99c5-4197-b856-69219c2a3845"
            if let services = device.advertisedServices {
                return services.map { $0.lowercased() }
                    .contains(rileyUUIDString.lowercased())
            }
            return false

        case .dexcom:
            if let name = device.name {
                return name.hasPrefix("DXCM") || name.hasPrefix("DX02") || name.hasPrefix("Dexcom")
            }
            return false

        case .omnipodDash:
            if let name = device.name {
                // "TWI BOARD": original DASH pod
                // "InPlay BLE": newer Atlas DASH pod
                // " :: Fake POD ::": rPi DASH simulator
                return name == "TWI BOARD" || name == "InPlay BLE" || name == " :: Fake POD ::"
            }
            return false

        case .silentTune, .none, .hub:
            return false
        }
    }
}
