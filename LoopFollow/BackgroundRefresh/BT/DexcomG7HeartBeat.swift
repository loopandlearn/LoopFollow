//
//  DexcomG7HeartBeat.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-04.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

// Denna behövs

import Foundation

/// A simple class to represent the Dexcom G7 Heartbeat.
/// It wraps around a `BLEPeripheral` to store relevant information.
public class DexcomG7HeartBeat {
    // MARK: - Properties

    /// The BLEPeripheral instance associated with this heartbeat.
    public let blePeripheral: BLEPeripheral

    // MARK: - Initialization

    /// Initializes a new DexcomG7HeartBeat instance.
    /// - Parameters:
    ///   - address: The unique address of the BLE device.
    ///   - name: The name of the BLE device.
    ///   - alias: An optional alias for the device.
    public init(address: String, name: String, alias: String? = nil) {
        blePeripheral = BLEPeripheral(
            address: address,
            name: name,
            alias: alias,
            peripheralType: .DexcomG7HeartBeatType
        )
    }
}
