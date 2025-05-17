// LoopFollow
// BLEDeviceSelectionView.swift
// Created by Jonas Björkert on 2025-01-13.

import SwiftUI

struct BLEDeviceSelectionView: View {
    @ObservedObject var bleManager: BLEManager
    var selectedFilter: BackgroundRefreshType
    var onSelectDevice: (BLEDevice) -> Void

    var body: some View {
        VStack {
            List {
                let filteredDevices = bleManager.devices.filter { selectedFilter.matches($0) && !isSelected($0) }
                if filteredDevices.isEmpty {
                    Text("No devices found yet. They'll appear here when discovered.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(filteredDevices, id: \.id) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name ?? "Unknown")

                                Text("RSSI: \(device.rssi) dBm")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)

                                if let offset = BLEManager.shared.expectedSensorFetchOffsetString(for: device) {
                                    Text("Expected bg delay: \(offset)")
                                        .foregroundColor(.secondary)
                                        .font(.footnote)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectDevice(device)
                        }
                    }
                }
            }
        }
        .onAppear {
            bleManager.startScanning()
        }
        .onDisappear {
            bleManager.stopScanning()
        }
    }

    private func isSelected(_ device: BLEDevice) -> Bool {
        guard let selectedDevice = Storage.shared.selectedBLEDevice.value else {
            return false
        }
        return selectedDevice.id == device.id
    }
}
