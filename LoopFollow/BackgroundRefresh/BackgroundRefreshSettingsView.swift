//
//  BackgroundRefreshSettingsView.swift
//  LoopFollow
//

import SwiftUI

struct BackgroundRefreshSettingsView: View {
    @ObservedObject var viewModel: BackgroundRefreshSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var selectedBLEDevice = Storage.shared.selectedBLEDevice

    var body: some View {
        NavigationView {
            Form {
                refreshTypeSection

                if viewModel.backgroundRefreshType.isBluetooth {
                    selectedDeviceSection
                    availableDevicesSection
                }
            }
            .navigationBarTitle("Background Refresh Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
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

            Text("Adjust the background refresh type.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var selectedDeviceSection: some View {
        if let storedDevice = selectedBLEDevice.value {
            Section(header: Text("Selected Device")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storedDevice.name ?? "Unknown Device")
                        .font(.headline)

                    deviceConnectionStatus(for: storedDevice)

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

    private var availableDevicesSection: some View {
        Section(header: Text("Available Devices")) {
            BLEDeviceSelectionView(
                bleManager: bleManager,
                selectedFilter: viewModel.backgroundRefreshType,
                onSelectDevice: { device in
                    bleManager.connect(device: device)
                }
            )
        }
    }

    private func deviceConnectionStatus(for device: BLEDevice) -> some View {
        if device.isConnected {
            return Text("Connected")
                .foregroundColor(.green)
        } else if let lastConnected = device.lastConnected {
            let date = dateTimeUtils.formattedDate(from: lastConnected)
            return Text("Last connection: \(date)")
                .foregroundColor(.orange)
        } else if let item = bleManager.devices.first(where: { $0.id == device.id }) {
            let date = dateTimeUtils.formattedDate(from: item.lastSeen)
            return Text("Last seen: \(date)")
                .foregroundColor(.orange)
        } else {
            return Text("Not found")
                .foregroundColor(.red)
        }
    }
}
