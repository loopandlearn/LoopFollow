// LoopFollow
// BackgroundRefreshSettingsView.swift

import SwiftUI

struct BackgroundRefreshSettingsView: View {
    @ObservedObject var viewModel: BackgroundRefreshSettingsViewModel

    @ObservedObject var bleManager = BLEManager.shared

    var body: some View {
        NavigationView {
            Form {
                refreshTypeSection

                if viewModel.backgroundRefreshType.isBluetooth {
                    selectedDeviceSection
                    availableDevicesSection
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Background Refresh Settings", displayMode: .inline)
    }

    // MARK: - Subviews / Computed Properties

    private var refreshTypeSection: some View {
        Section {
            Picker("Background Refresh Type", selection: $viewModel.backgroundRefreshType) {
                ForEach(BackgroundRefreshType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Adjust the background refresh type.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                switch viewModel.backgroundRefreshType {
                case .none:
                    Text("No background refresh. Alarms and updates will not work unless the app is open in the foreground.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                case .silentTune:
                    Text("A silent tune will play in the background, keeping the app active. May be interrupted by other apps. Allows continuous updates but consumes more battery.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                case .rileyLink:
                    Text("Requires a RileyLink-compatible device within Bluetooth range. Provides updates once per minute and uses less battery than the silent tune method.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                case .dexcom:
                    Text("Requires a Dexcom G6/ONE/G7/ONE+ transmitter within Bluetooth range. Provides updates every 5 minutes and uses less battery than the silent tune method. If you have more than one device to choose from, select the one with the smallest expected bg delay.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                case .omnipodDash:
                    Text("Requires an OmniPod DASH pod paired with this device within Bluetooth range. Provides updates once every 3 minutes and uses less battery than the silent tune method.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedDeviceSection: some View {
        if let storedDevice = bleManager.getSelectedDevice() {
            Section(header: Text("Selected Device")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storedDevice.name ?? "Unknown Device")
                        .font(.headline)

                    ConnectionStatusView(device: storedDevice)

                    if storedDevice.rssi != 0 {
                        Text("RSSI: \(storedDevice.rssi) dBm")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                    if let offset = BLEManager.shared.expectedSensorFetchOffsetString(for: storedDevice) {
                        Text("Expected bg delay: \(offset)")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }

                    HStack {
                        Spacer()
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            Text("Disconnect")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func formattedTimeString(from seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else {
            let minutes = Int(seconds / 60)
            let seconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes):\(String(format: "%02d", seconds)) minutes"
        }
    }

    private var availableDevicesSection: some View {
        Section(header: scanningStatusHeader) {
            BLEDeviceSelectionView(
                bleManager: bleManager,
                selectedFilter: viewModel.backgroundRefreshType,
                onSelectDevice: { device in
                    bleManager.connect(device: device)
                }
            )
        }
    }

    private var scanningStatusHeader: some View {
        Text("Scanning for \(viewModel.backgroundRefreshType.rawValue)...")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

/// Isolated view that handles the "seconds ticking" for connection status
private struct ConnectionStatusView: View {
    let device: BLEDevice
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if device.isConnected {
                Text("Connected")
                    .foregroundColor(.green)
            } else if let lastConnected = device.lastConnected {
                statusText(lastConnected: lastConnected)
            } else {
                Text("Reconnecting...")
                    .foregroundColor(.orange)
            }
        }
        .onReceive(timer) { input in
            now = input
        }
    }

    private func statusText(lastConnected: Date) -> Text {
        let timeSinceLastConnection = now.timeIntervalSince(lastConnected)
        let expectedConnectionTime: TimeInterval = BLEManager.shared.expectedHeartbeatInterval() ?? 300
        let timeRatio = timeSinceLastConnection / expectedConnectionTime
        let timeString = formattedTimeString(from: timeSinceLastConnection)

        if timeRatio < 1.0 {
            return Text("Disconnected for \(timeString)").foregroundColor(.green)
        } else if timeRatio <= 1.15 {
            return Text("Disconnected for \(timeString)").foregroundColor(.orange)
        } else if timeRatio <= 3.0 {
            return Text("Disconnected for \(timeString)").foregroundColor(.red)
        } else {
            let date = dateTimeUtils.formattedDate(from: lastConnected)
            return Text("Last connection: \(date)").foregroundColor(.red)
        }
    }

    private func formattedTimeString(from seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes):\(String(format: "%02d", remainingSeconds)) minutes"
        }
    }
}
