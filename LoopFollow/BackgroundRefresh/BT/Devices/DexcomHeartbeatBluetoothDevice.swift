//
//  DexcomHeartbeatBluetoothDevice.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-04.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

class DexcomHeartbeatBluetoothDevice: BluetoothDevice {
    private let CBUUID_Service_G7 = "F8083532-849E-531C-C594-30F1F86A4EA5"
    private let CBUUID_Advertisement_G7 = "FEBC"
    private let CBUUID_ReceiveCharacteristic_G7 = "F8083535-849E-531C-C594-30F1F86A4EA5"

    private var timeStampOfLastHeartBeat: Date

    init(bluetoothDeviceDelegate: BluetoothDeviceDelegate) {
        guard let selectedDevice = Storage.shared.selectedBLEDevice.value else {
            fatalError("No selected BLE device found in storage.")
        }

        let address = selectedDevice.id.uuidString
        let name = selectedDevice.name

        self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)

        super.init(
            address: address,
            name: name,
            CBUUID_Advertisement: CBUUID_Advertisement_G7,
            servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G7)],
            CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G7,
            bluetoothDeviceDelegate: bluetoothDeviceDelegate
        )
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        self.bluetoothDeviceDelegate?.heartBeat()
    }

    override func expectedHeartbeatInterval() -> TimeInterval? {
        return 5 * 60 // 5 minutes in seconds
    }
}
