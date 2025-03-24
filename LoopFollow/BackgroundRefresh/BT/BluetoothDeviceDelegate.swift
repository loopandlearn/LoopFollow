//
//  BluetoothDeviceDelegate.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-04.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BluetoothDeviceDelegate: AnyObject {
    func didConnectTo(bluetoothDevice: BluetoothDevice)

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice)

    func heartBeat()
}
