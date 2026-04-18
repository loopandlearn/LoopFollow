// LoopFollow
// BackgroundRefreshSettingsView.swift

import SwiftUI

struct BackgroundRefreshSettingsView: View {
    @ObservedObject var viewModel: BackgroundRefreshSettingsViewModel
    @State private var forceRefresh = false
    @State private var timer: Timer?
    @State private var showInfo = false

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
            .sheet(isPresented: $showInfo) {
                backgroundRefreshInfoSheet
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Background Refresh Settings", displayMode: .inline)
    }

    // MARK: - Subviews / Computed Properties

    private var refreshTypeSection: some View {
        Section(header: refreshTypeSectionHeader) {
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

                    deviceConnectionStatus(for: storedDevice)

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
            .id(forceRefresh)
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

    private func deviceConnectionStatus(for device: BLEDevice) -> some View {
        let expectedConnectionTime: TimeInterval = bleManager.expectedHeartbeatInterval() ?? 300
        let now = Date()
        let timeSinceLastConnection = device.isConnected ? 0 : now.timeIntervalSince(device.lastConnected ?? now)

        if device.isConnected {
            return Text("Connected")
                .foregroundColor(.green)
        } else if let lastConnected = device.lastConnected {
            let timeRatio = timeSinceLastConnection / expectedConnectionTime
            let timeString = formattedTimeString(from: timeSinceLastConnection)

            if timeRatio < 1.0 {
                return Text("Disconnected for \(timeString)")
                    .foregroundColor(.green)
            } else if timeRatio <= 1.15 {
                return Text("Disconnected for \(timeString)")
                    .foregroundColor(.orange)
            } else if timeRatio <= 3.0 {
                return Text("Disconnected for \(timeString)")
                    .foregroundColor(.red)
            } else {
                let date = dateTimeUtils.formattedDate(from: lastConnected)
                return Text("Last connection: \(date)")
                    .foregroundColor(.red)
            }
        } else {
            return Text("Reconnecting...")
                .foregroundColor(.orange)
        }
    }

    // MARK: - Section Header & Info Sheet

    private var refreshTypeSectionHeader: some View {
        HStack(spacing: 4) {
            Text("Background Refresh")
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    private var backgroundRefreshInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("LoopFollow needs to stay active in the background to check for alarms and update glucose values. There are several methods available:")

                    Text("Silent Tune")
                        .font(.headline)
                    Text("Plays a silent audio track to keep the app active. This has several drawbacks including battery drain and limited reliability — it may be interrupted by other apps.")

                    Text("Bluetooth Heartbeat")
                        .font(.headline)
                    Text("Uses an external Bluetooth device to keep LoopFollow awake. This can save significantly on battery and provides more reliable background operation.")

                    Text("Supported Bluetooth Devices")
                        .font(.headline)
                    Text(verbatim: """
                    • Radiolink: RileyLink, OrangeLink, Emalink — heartbeat every minute
                    • Dexcom G5/G6/ONE/Anubis transmitter — heartbeat every ~5 minutes
                    • Dexcom G7/ONE+ sensor — heartbeat every ~5 minutes

                    Dexcom device batteries continue to provide Bluetooth power for months after they are no longer in service with a sensor.
                    """)

                    Text("If the person using LoopFollow is also wearing a Dexcom or radiolink, they should choose their own device.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Background Refresh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showInfo = false }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.forceRefresh.toggle()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
