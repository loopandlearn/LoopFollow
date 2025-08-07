// LoopFollow
// BluetoothDevice.swift
// Created by Jonas Björkert.

import CoreBluetooth
import Foundation
import os
import UIKit

class BluetoothDevice: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    weak var bluetoothDeviceDelegate: BluetoothDeviceDelegate?
    private(set) var deviceAddress: String
    private(set) var deviceName: String?
    private let CBUUID_Advertisement: String?
    private let servicesCBUUIDs: [CBUUID]?
    private let CBUUID_ReceiveCharacteristic: String
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var timeStampLastStatusUpdate: Date
    private var receiveCharacteristic: CBCharacteristic?
    private let maxTimeToWaitForPeripheralResponse = 5.0
    private var connectTimeOutTimer: Timer?
    var lastHeartbeatTime: Date?

    init(address: String, name: String?, CBUUID_Advertisement: String?, servicesCBUUIDs: [CBUUID]?, CBUUID_ReceiveCharacteristic: String, bluetoothDeviceDelegate: BluetoothDeviceDelegate) {
        lastHeartbeatTime = nil
        deviceAddress = address
        deviceName = name

        self.servicesCBUUIDs = servicesCBUUIDs
        self.CBUUID_Advertisement = CBUUID_Advertisement
        self.CBUUID_ReceiveCharacteristic = CBUUID_ReceiveCharacteristic

        timeStampLastStatusUpdate = Date()

        self.bluetoothDeviceDelegate = bluetoothDeviceDelegate

        super.init()

        initialize()
    }

    deinit {
        disconnect()
    }

    func connect() {
        if let centralManager = centralManager, !retrievePeripherals(centralManager) {
            _ = startScanning()
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func disconnectAndForget() {
        disconnect()

        peripheral = nil
        deviceName = nil
        // deviceAddress = nil
    }

    func stopScanning() {
        centralManager?.stopScan()
    }

    func isScanning() -> Bool {
        if let centralManager = centralManager {
            return centralManager.isScanning
        }
        return false
    }

    func startScanning() -> BluetoothDevice.startScanningResult {
        LogManager.shared.log(category: .bluetooth, message: "Start Scanning", isDebug: true)

        var returnValue = BluetoothDevice.startScanningResult.unknown

        if let peripheral = peripheral {
            switch peripheral.state {
            case .connected:
                return .alreadyConnected
            case .connecting:
                if Date() > Date(timeInterval: maxTimeToWaitForPeripheralResponse, since: timeStampLastStatusUpdate) {
                    disconnect()
                }
                return .connecting
            default: ()
            }
        }

        var services: [CBUUID]?
        if let CBUUID_Advertisement = CBUUID_Advertisement {
            services = [CBUUID(string: CBUUID_Advertisement)]
        }

        if let centralManager = centralManager {
            if centralManager.isScanning {
                return .alreadyScanning
            }
            switch centralManager.state {
            case .poweredOn:
                centralManager.scanForPeripherals(withServices: services, options: nil)
                returnValue = .success
            case .poweredOff:
                return .poweredOff
            case .unknown:
                return .unknown
            case .unauthorized:
                return .unauthorized
            default:
                return returnValue
            }
        } else {
            returnValue = .other(reason: "centralManager is nil, can not start scanning")
        }

        return returnValue
    }

    func readValueForCharacteristic(for characteristic: CBCharacteristic) {
        peripheral?.readValue(for: characteristic)
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        if let peripheral = peripheral {
            peripheral.setNotifyValue(enabled, for: characteristic)
        }
    }

    fileprivate func stopScanAndconnect(to peripheral: CBPeripheral) {
        LogManager.shared.log(category: .bluetooth, message: "Stop Scan And Connect", isDebug: true)

        centralManager?.stopScan()
        deviceAddress = peripheral.identifier.uuidString
        deviceName = peripheral.name
        peripheral.delegate = self
        self.peripheral = peripheral

        if peripheral.state == .disconnected {
            connectTimeOutTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(stopConnectAndRestartScanning), userInfo: nil, repeats: false)
            centralManager?.connect(peripheral, options: nil)
        } else {
            if let newCentralManager = centralManager {
                centralManager(newCentralManager, didConnect: peripheral)
            }
        }
    }

    @objc fileprivate func stopConnectAndRestartScanning() {
        disconnectAndForget()
        _ = startScanning()
    }

    func cancelConnectionTimer() {
        if let connectTimeOutTimer = connectTimeOutTimer {
            connectTimeOutTimer.invalidate()
            self.connectTimeOutTimer = nil
        }
    }

    fileprivate func retrievePeripherals(_ central: CBCentralManager) -> Bool {
        if let uuid = UUID(uuidString: deviceAddress) {
            // trace("    uuid is not nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            let peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
            if peripheralArr.count > 0 {
                peripheral = peripheralArr[0]
                if let peripheral = peripheral {
                    peripheral.delegate = self
                    central.connect(peripheral, options: nil)
                    return true
                }
            }
        }
        return false
    }

    func centralManager(_: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData _: [String: Any], rssi _: NSNumber) {
        print("[BLE] didDiscover")

        timeStampLastStatusUpdate = Date()

        if peripheral.identifier.uuidString == deviceAddress {
            stopScanAndconnect(to: peripheral)
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cancelConnectionTimer()

        timeStampLastStatusUpdate = Date()

        bluetoothDeviceDelegate?.didConnectTo(bluetoothDevice: self)

        peripheral.discoverServices(servicesCBUUIDs)
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        timeStampLastStatusUpdate = Date()

        let peripheralName = peripheral.name ?? "Unknown"
        let errorMessage = error?.localizedDescription ?? "No error details provided"

        LogManager.shared.log(category: .bluetooth, message: "Failed to connect to peripheral '\(peripheralName)' (UUID: \(peripheral.identifier.uuidString)). Error: \(errorMessage). Retrying...")

        centralManager?.connect(peripheral, options: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        LogManager.shared.log(category: .bluetooth, message: "Central Manager Did Update State", isDebug: true)

        timeStampLastStatusUpdate = Date()

        if central.state == .poweredOn {
            _ = retrievePeripherals(central)
        }
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        timeStampLastStatusUpdate = Date()

        bluetoothDeviceDelegate?.didDisconnectFrom(bluetoothDevice: self)

        if let ownPeripheral = peripheral {
            centralManager?.connect(ownPeripheral, options: nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        timeStampLastStatusUpdate = Date()

        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            disconnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        timeStampLastStatusUpdate = Date()

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    receiveCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    func peripheral(_: CBPeripheral, didWriteValueFor _: CBCharacteristic, error _: Error?) {
        timeStampLastStatusUpdate = Date()
    }

    func peripheral(_: CBPeripheral, didUpdateNotificationStateFor _: CBCharacteristic, error _: Error?) {
        timeStampLastStatusUpdate = Date()
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor _: CBCharacteristic, error _: Error?) {
        timeStampLastStatusUpdate = Date()
    }

    func centralManager(_: CBCentralManager, willRestoreState _: [String: Any]) {
        LogManager.shared.log(category: .bluetooth, message: "Restoring BLE after crash/kill")
    }

    private func initialize() {
        var cBCentralManagerOptionRestoreIdentifierKeyToUse: String?

        cBCentralManagerOptionRestoreIdentifierKeyToUse = "LoopFollow-" + deviceAddress

        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: cBCentralManagerOptionRestoreIdentifierKeyToUse!])
    }

    enum startScanningResult: Equatable {
        case success
        case alreadyScanning
        case poweredOff
        case alreadyConnected
        case connecting
        case unknown
        case unauthorized
        case nfcScanNeeded
        case other(reason: String)

        func description() -> String {
            switch self {
            case .success:
                return "success"
            case .alreadyScanning:
                return "alreadyScanning"
            case .poweredOff:
                return "poweredOff"
            case .alreadyConnected:
                return "alreadyConnected"
            case .connecting:
                return "connecting"
            case let .other(reason):
                return "other reason : " + reason
            case .unknown:
                return "unknown"
            case .unauthorized:
                return "unauthorized"
            case .nfcScanNeeded:
                return "nfcScanNeeded"
            }
        }
    }

    func expectedHeartbeatInterval() -> TimeInterval? {
        return nil
    }
}
