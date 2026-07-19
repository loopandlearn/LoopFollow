// LoopFollow
// BLEManager.swift

import Combine
import CoreBluetooth
import Foundation

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    /// Whether the shared instance has been created (and therefore a
    /// CBCentralManager exists / the Bluetooth prompt has been triggered).
    /// Reading this does not instantiate `shared`, so callers can avoid forcing
    /// Bluetooth initialization — and its permission prompt — when not needed.
    private(set) static var isInitialized = false

    @Published private(set) var devices: [BLEDevice] = []

    private var centralManager: CBCentralManager!
    private var activeDevice: BluetoothDevice?
    private var readinessCancellable: AnyCancellable?

    /// Arrival times of recent heartbeat dropouts. Main-queue-confined
    /// (centralManager delivers on .main) and deliberately not persisted:
    /// stale history must not resurrect the banner after a relaunch.
    private var heartbeatDropoutTimes: [Date] = []

    /// A beat this much later than expected counts as one dropout event.
    /// Stricter than the 15% logging margin - normal jitter must not count.
    private let dropoutFactor = 1.5

    /// Sliding window over which dropout events are counted.
    private let dropoutWindow: TimeInterval = 60 * 60

    /// Dropout events within the window needed to raise the banner.
    private let dropoutTriggerCount = 5

    override private init() {
        super.init()
        BLEManager.isInitialized = true

        centralManager = CBCentralManager(
            delegate: self,
            queue: .main
        )
        connectSelectedDeviceIfNeeded()

        // After BFU, selectedBLEDevice reads nil until hydration — reconnect when
        // storage becomes ready. dropFirst skips the current value (init handled the
        // already-ready case), so this fires only on the false→true recovery.
        readinessCancellable = StorageReadiness.ready.$value
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.connectSelectedDeviceIfNeeded()
            }
    }

    private func connectSelectedDeviceIfNeeded() {
        guard activeDevice == nil, let device = Storage.shared.selectedBLEDevice.value else { return }
        if !devices.contains(where: { $0.id == device.id }) {
            devices.append(device)
        }
        findAndUpdateDevice(with: device.id.uuidString) { device in
            device.rssi = 0
        }
        connect(device: device)
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
        heartbeatDropoutTimes.removeAll()
        BannerManager.shared.clear(.heartbeat)
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
            case .omnipodDash:
                activeDevice = OmnipodDashHeartbeatBluetoothTransmitter(address: device.id.uuidString, name: device.name, bluetoothDeviceDelegate: self)
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
        LogManager.shared.log(category: .bluetooth, message: "Adding or updating BLE device: \(device)", isDebug: true)
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

    func centralManager(_: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber)
    {
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

        let marginPercentage = 0.15 // 15% margin
        let margin = expectedInterval * marginPercentage
        let threshold = expectedInterval + margin

        if let last = device.lastHeartbeatTime {
            let elapsedTime = now.timeIntervalSince(last)
            if elapsedTime > threshold {
                let delay = elapsedTime - expectedInterval
                LogManager.shared.log(category: .bluetooth, message: "Heartbeat triggered (Delayed by \(String(format: "%.1f", delay)) seconds)")
            }
            recordHeartbeatOutcome(elapsed: elapsedTime, expectedInterval: expectedInterval, now: now)
        } else {
            LogManager.shared.log(category: .bluetooth, message: "Heartbeat triggered (First heartbeat)")
        }

        device.lastHeartbeatTime = now

        TaskScheduler.shared.checkTasksNow()
    }

    /// Counts late heartbeats over a sliding window and raises a banner when
    /// dropouts become frequent - the typical symptom of a dying transmitter
    /// battery. Detection is arrival-based on purpose: a struggling battery
    /// still delivers (late) beats, whereas total silence usually means
    /// out-of-range or a dead device and is already surfaced by the
    /// connection status in Background Refresh settings and by BG alarms.
    private func recordHeartbeatOutcome(elapsed: TimeInterval, expectedInterval: TimeInterval, now: Date) {
        heartbeatDropoutTimes.removeAll { now.timeIntervalSince($0) > dropoutWindow }

        // A gap this large means out-of-range, Bluetooth off or a suspended
        // app - not a struggling battery. Discard the history collected
        // before the blind spot instead of counting it.
        let resetGap = max(6 * expectedInterval, 30 * 60)
        if elapsed > resetGap {
            if !heartbeatDropoutTimes.isEmpty {
                heartbeatDropoutTimes.removeAll()
                LogManager.shared.log(category: .bluetooth, message: "Heartbeat gap of \(Int(elapsed)) seconds, resetting dropout history")
            }
        } else if elapsed > expectedInterval * dropoutFactor {
            heartbeatDropoutTimes.append(now)
            LogManager.shared.log(category: .bluetooth, message: "Heartbeat dropout recorded (\(heartbeatDropoutTimes.count) in the last hour)")
        }

        // Hysteresis: raise at the trigger count, clear only once the window
        // is completely clean, so the banner doesn't flap at the boundary.
        if heartbeatDropoutTimes.count >= dropoutTriggerCount {
            BannerManager.shared.report(source: .heartbeat, severity: .warning, text: heartbeatDropoutBannerText())
        } else if heartbeatDropoutTimes.isEmpty {
            BannerManager.shared.clear(.heartbeat)
        }
    }

    /// The text must stay stable while the condition persists (no counts or
    /// durations) so BannerManager's dedupe keeps the banner from
    /// re-animating on every beat and user dismissal keeps working.
    private func heartbeatDropoutBannerText() -> String {
        let name = activeDevice?.deviceName ?? "heartbeat device"
        let cause: String
        switch Storage.shared.backgroundRefreshType.value {
        case .rileyLink:
            cause = "a low RileyLink battery"
        case .omnipodDash:
            cause = "a low pod battery"
        default:
            cause = "a low transmitter battery"
        }
        return "Heartbeat: repeated Bluetooth dropouts from \(name). This can be a sign of \(cause) or a weak Bluetooth connection."
    }
}

extension BLEManager {
    /// Returns the expected sensor fetch offset as a formatted string ("mm:ss (fetch delay: XX sec)")
    /// for Dexcom and RileyLink devices. The expected offset is computed as the sensor's schedule offset plus the polling delay.
    /// The device’s lastSeen time is used (mod cycleDuration) to calculate the effective delay between when the sensor value
    /// becomes available and when the fetch is actually triggered.
    func expectedSensorFetchOffsetString(for device: BLEDevice) -> String? {
        guard
            let matchedType = BackgroundRefreshType.allCases.first(where: { $0.matches(device) }),
            let heartBeatInterval = matchedType.heartBeatInterval,
            let sensorOffset = Storage.shared.sensorScheduleOffset.value
        else {
            return nil
        }

        let heartbeatLast: Date? = {
            if matchedType.estimatedDelayBasedOnHeartbeat {
                guard device.isConnected, let lastHeartbeat = activeDevice?.lastHeartbeatTime else {
                    return nil
                }
                return lastHeartbeat
            } else {
                return device.lastSeen
            }
        }()

        guard let heartbeatLast = heartbeatLast else {
            return nil
        }

        let pollingDelay: TimeInterval = Double(Storage.shared.bgUpdateDelay.value)

        let expectedOffset = sensorOffset + pollingDelay

        // If the heartbeat interval isn't a typical 60 or 300 seconds,
        // we simply return a string indicating that the delay is "up to" the heartbeat interval.
        if heartBeatInterval != 60, heartBeatInterval != 300 {
            return "up to \(Int(heartBeatInterval)) sec"
        }

        let effectiveDelay = CycleHelper.computeDelay(sensorOffset: expectedOffset, heartbeatLast: heartbeatLast, heartbeatInterval: heartBeatInterval)

        return "\(Int(effectiveDelay)) sec"
    }
}
