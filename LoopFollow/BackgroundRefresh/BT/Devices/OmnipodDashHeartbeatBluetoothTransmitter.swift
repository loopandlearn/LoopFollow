// LoopFollow
// OmnipodDashHeartbeatBluetoothTransmitter.swift
// Created by Jonas Björkert.

import CoreBluetooth
import Foundation

class OmnipodDashHeartbeatBluetoothTransmitter: BluetoothDevice {
    private let CBUUID_Service: String = "1A7E4024-E3ED-4464-8B7E-751E03D0DC5F"
    private let CBUUID_Advertisement: String = "00004024-0000-1000-8000-00805f9b34fb"
    private let CBUUID_ReceiveCharacteristic: String = "1A7E2442-E3ED-4464-8B7E-751E03D0DC5F"

    private let CBUUID_ReceiveCharacteristic_Data: String = ""

    init(address: String, name: String?, bluetoothDeviceDelegate: BluetoothDeviceDelegate) {
        super.init(
            address: address,
            name: name,
            CBUUID_Advertisement: nil,
            servicesCBUUIDs: [CBUUID(string: CBUUID_Service)],
            CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic,
            bluetoothDeviceDelegate: bluetoothDeviceDelegate
        )
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        bluetoothDeviceDelegate?.heartBeat()
    }

    override func expectedHeartbeatInterval() -> TimeInterval? {
        return 3 * 60
    }
}
