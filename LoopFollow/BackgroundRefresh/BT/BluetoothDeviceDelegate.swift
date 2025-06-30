// LoopFollow
// BluetoothDeviceDelegate.swift
// Created by Jonas Björkert.

import CoreBluetooth
import Foundation

protocol BluetoothDeviceDelegate: AnyObject {
    func didConnectTo(bluetoothDevice: BluetoothDevice)

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice)

    func heartBeat()
}
