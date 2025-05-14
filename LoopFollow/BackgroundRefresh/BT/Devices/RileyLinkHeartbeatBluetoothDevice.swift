//
//  RileyLinkHeartbeatBluetoothDevice.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-08.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import CoreBluetooth
import Foundation

class RileyLinkHeartbeatBluetoothDevice: BluetoothDevice {
    private let CBUUID_Service_RileyLink: String = "0235733B-99C5-4197-B856-69219C2A3845"
    private let CBUUID_ReceiveCharacteristic_TimerTick: String = "6E6C7910-B89E-43A5-78AF-50C5E2B86F7E"
    private let CBUUID_ReceiveCharacteristic_Data: String = "C842E849-5028-42E2-867C-016ADADA9155"

    init(address: String, name: String?, bluetoothDeviceDelegate: BluetoothDeviceDelegate) {
        super.init(
            address: address,
            name: name,
            CBUUID_Advertisement: nil,
            servicesCBUUIDs: [CBUUID(string: CBUUID_Service_RileyLink)],
            CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_TimerTick,
            bluetoothDeviceDelegate: bluetoothDeviceDelegate
        )
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        guard characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_TimerTick) else {
            return
        }

        bluetoothDeviceDelegate?.heartBeat()
    }

    override func expectedHeartbeatInterval() -> TimeInterval? {
        return 60
    }
}
