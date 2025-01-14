//
//  BLEManager.swift
//  LoopFollow
//

import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    @Published private(set) var devices: [BLEDevice] = []

    private var centralManager: CBCentralManager!
    private var activeDevice: BluetoothDevice?

    private override init() {
        super.init()

        centralManager = CBCentralManager(
            delegate: self,
            queue: .main
        )
        if let device = Storage.shared.selectedBLEDevice.value {
            connect(device: device)
        }
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            LogManager.shared.log(category: .bluetooth, message: "Not powered on, cannot start scan.")
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        cleanupOldDevices()
    }

    func disconnect() {
        if let device = activeDevice {
            device.disconnect()
            activeDevice = nil
            device.lastHeartbeatTime = nil
        }
        Storage.shared.selectedBLEDevice.value = nil
    }

    func connect(device: BLEDevice) {
        disconnect()

        if let matchedType = BackgroundRefreshType.allCases.first(where: { $0.matches(device) }) {
            Storage.shared.backgroundRefreshType.value = matchedType
            Storage.shared.selectedBLEDevice.value = device

            switch matchedType {
            case .dexcomG7:
                activeDevice = DexcomG7HeartbeatBluetoothDevice(bluetoothDeviceDelegate: self)
                activeDevice?.connect()
            case .rileyLink:
                activeDevice = RileyLinkHeartbeatBluetoothDevice(bluetoothDeviceDelegate: self)
                activeDevice?.connect()
            case .silentTune, .none:
                return
            }
        } else {
            LogManager.shared.log(category: .bluetooth, message: "No matching BackgroundRefreshType found for this device.")
        }
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    private func addOrUpdateDevice(_ device: BLEDevice) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device.updateLastSeen()
        } else {
            var newDevice = device
            newDevice.lastSeen = Date()
            devices.append(newDevice)
        }
        devices = devices
    }

    private func cleanupOldDevices() {
        let expirationDate = Date().addingTimeInterval(-600) // 10 minutes ago

        // Get the selected device's ID (if any)
        let selectedDeviceID = Storage.shared.selectedBLEDevice.value?.id

        // Filter devices, keeping those seen within the last 10 minutes or the selected device
        devices = devices.filter { $0.lastSeen > expirationDate || $0.id == selectedDeviceID }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BLE] Central poweredOn.")
        default:
            print("[BLE] Central state = \(central.state.rawValue), not powered on.")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let uuid = peripheral.identifier
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map { $0.uuidString }

        let device = BLEDevice(
            id: uuid,
            name: peripheral.name,
            rssi: RSSI.intValue,
            advertisedServices: services,
            lastSeen: Date()
        )

        addOrUpdateDevice(device)
    }
}

extension BLEManager: BluetoothDeviceDelegate {
    func didConnectTo(bluetoothDevice: BluetoothDevice) {
        LogManager.shared.log(category: .bluetooth, message: "Connected to: \(String(describing: bluetoothDevice.deviceName))")
        if var device = Storage.shared.selectedBLEDevice.value {
            device.isConnected = true
            Storage.shared.selectedBLEDevice.value = device.updateLastConnected()
        }
    }

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice) {
        LogManager.shared.log(category: .bluetooth, message: "Disconnect from: \(String(describing: bluetoothDevice.deviceName))")
        if var device = Storage.shared.selectedBLEDevice.value {
            device.isConnected = false
            Storage.shared.selectedBLEDevice.value = device
        }
    }

    func heartBeat() {
        guard let device = activeDevice else {
            return
        }

        let now = Date()
        guard let expectedInterval = device.expectedHeartbeatInterval() else {
            LogManager.shared.log(category: .bluetooth, message: "Heartbeat triggered")
            device.lastHeartbeatTime = now
            TaskScheduler.shared.checkTasksNow()
            return
        }

        let marginPercentage: Double = 0.15 // 15% margin
        let margin = expectedInterval * marginPercentage
        let threshold = expectedInterval + margin

        if let last = device.lastHeartbeatTime {
            let elapsedTime = now.timeIntervalSince(last)
            if elapsedTime > threshold {
                let delay = elapsedTime - expectedInterval
                LogManager.shared.log(category: .bluetooth, message: "Heartbeat triggered (Delayed by \(String(format: "%.1f", delay)) seconds)")
            }
        } else {
            LogManager.shared.log(category: .bluetooth, message: "Heartbeat triggered (First heartbeat)")
        }

        device.lastHeartbeatTime = now

        TaskScheduler.shared.checkTasksNow()
    }
}
