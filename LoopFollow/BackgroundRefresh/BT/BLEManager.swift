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
            devices.append(device)
            findAndUpdateDevice(with: device.id.uuidString) { device in
                device.rssi = 0
            }
            connect(device: device)
        }
    }

    func getSelectedDevice() -> BLEDevice? {
        return devices.first { $0.id == Storage.shared.selectedBLEDevice.value?.id }
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

            findAndUpdateDevice(with: device.id.uuidString) { device in
                device.isConnected = false
                device.lastConnected = nil
            }

            switch matchedType {
            case .dexcom:
                activeDevice = DexcomHeartbeatBluetoothDevice(address: device.id.uuidString, name: device.name, bluetoothDeviceDelegate: self)
                activeDevice?.connect()
            case .rileyLink:
                activeDevice = RileyLinkHeartbeatBluetoothDevice(address: device.id.uuidString, name: device.name, bluetoothDeviceDelegate: self)
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

    func expectedHeartbeatInterval() -> TimeInterval? {
        guard let device = activeDevice else {
            return nil
        }

        return device.expectedHeartbeatInterval()
    }

    private func addOrUpdateDevice(_ device: BLEDevice) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            var updatedDevice = devices[idx]
            updatedDevice.rssi = device.rssi
            updatedDevice.lastSeen = Date()
            devices[idx] = updatedDevice
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
            LogManager.shared.log(category: .bluetooth, message: "Central poweredOn", isDebug: true)
        default:
            LogManager.shared.log(category: .bluetooth, message: "Central state = \(central.state.rawValue), not powered on.", isDebug: true)
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

    func findAndUpdateDevice(with deviceAddress: String, update: (inout BLEDevice) -> Void) {
        if let idx = devices.firstIndex(where: { $0.id.uuidString == deviceAddress }) {
            var device = devices[idx]
            update(&device)
            devices[idx] = device

            devices = devices
        } else {
            LogManager.shared.log(category: .bluetooth, message: "Device not found in devices array for update")
        }
    }
}

extension BLEManager: BluetoothDeviceDelegate {
    func didConnectTo(bluetoothDevice: BluetoothDevice) {
        LogManager.shared.log(category: .bluetooth, message: "Connected to: \(bluetoothDevice.deviceName ?? "Unknown")", isDebug: true)

        findAndUpdateDevice(with: bluetoothDevice.deviceAddress) { device in
            device.isConnected = true
            device.lastConnected = Date()
        }
    }

    func didDisconnectFrom(bluetoothDevice: BluetoothDevice) {
        LogManager.shared.log(category: .bluetooth, message: "Disconnect from: \(bluetoothDevice.deviceName ?? "Unknown")", isDebug: true)

        findAndUpdateDevice(with: bluetoothDevice.deviceAddress) { device in
            device.isConnected = false
            device.lastConnected = Date()
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

extension BLEManager {
    /// Returns the expected sensor fetch offset as a formatted string ("mm:ss (fetch delay: XX sec)")
    /// for Dexcom devices. The expected offset is computed as the sensor's schedule offset plus the polling delay.
    /// The device’s lastSeen time is used (mod 300) to calculate the effective delay between when the sensor value
    /// becomes available and when the fetch is actually triggered.
    func expectedSensorFetchOffsetString(for device: BLEDevice) -> String? {
        // Determine the device type using your BackgroundRefreshType matching.
        guard let matchedType = BackgroundRefreshType.allCases.first(where: { $0.matches(device) }) else {
            return nil
        }

        // We only calculate this for Dexcom (G7) devices.
        if matchedType == .dexcom {
            // Return nil if the sensor schedule offset hasn't been set.
            guard let sensorOffset = Storage.shared.sensorScheduleOffset.value else {
                return nil
            }

            // Polling delay: use dynamic setting if enabled, otherwise the default.
            let pollingDelay: TimeInterval = Double(UserDefaultsRepository.bgUpdateDelay.value)

            // T_expected: the time (in seconds) after the sensor reading when the value is available.
            let expectedOffset = sensorOffset + pollingDelay

            // Compute the device’s heartbeat offset within the 5-minute (300 sec) cycle.
            let calendar = Calendar(identifier: .gregorian)
            let startOfDay = calendar.startOfDay(for: device.lastSeen)
            let heartbeatOffset = device.lastSeen.timeIntervalSince(startOfDay).truncatingRemainder(dividingBy: 300)

            // Calculate effective delay:
            // If the heartbeat happens after the sensor value is available, delay = heartbeatOffset - expectedOffset.
            // Otherwise, the fetch will occur on the next cycle:
            // delay = (heartbeatOffset + 300) - expectedOffset.
            let effectiveDelay: TimeInterval = (heartbeatOffset >= expectedOffset)
            ? (heartbeatOffset - expectedOffset)
            : (heartbeatOffset + 300 - expectedOffset)

            return "\(Int(effectiveDelay)) sec"
        }
        return nil
    }
}
