// LoopFollow
// BluetoothDeviceDelegate.swift

import CoreBluetooth
import Foundation

protocol BluetoothDeviceDelegate: AnyObject {
    func didConnectTo(bluetoothDevice: BluetoothDevice)

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice)

    func heartBeat()
}
