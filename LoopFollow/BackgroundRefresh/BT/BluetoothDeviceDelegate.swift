// LoopFollow
// BluetoothDeviceDelegate.swift
// Created by Jonas Björkert on 2025-01-13.

import CoreBluetooth
import Foundation

protocol BluetoothDeviceDelegate: AnyObject {
    func didConnectTo(bluetoothDevice: BluetoothDevice)

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice)

    func heartBeat()
}
