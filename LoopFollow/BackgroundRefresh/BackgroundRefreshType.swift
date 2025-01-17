//
//  BackgroundRefreshType.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-02.
//

import Foundation

enum BackgroundRefreshType: String, Codable, CaseIterable {
    case none = "None"
    case silentTune = "Silent Tune"
    case rileyLink = "RileyLink"
    case dexcom = "Dexcom"

    /// Indicates if the device type uses Bluetooth
    var isBluetooth: Bool {
        switch self {
        case .rileyLink, .dexcom:
            return true
        case .silentTune, .none:
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

        case .silentTune, .none:
            return false
        }
    }
}
