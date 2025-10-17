// LoopFollow
// ImportExportSettingsView.swift

import SwiftUI

struct ImportExportSettingsView: View {
    @StateObject private var viewModel = ImportExportSettingsViewModel()

    var body: some View {
        NavigationView {
            List {
                // MARK: - Import Section

                Section("Import Settings") {
                    Button(action: {
                        viewModel.isShowingQRCodeScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundColor(.blue)
                            Text("Scan QR Code to Import Settings")
                        }
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - Export Section

                Section("Export Settings To QR Code") {
                    ForEach(ImportExportSettingsViewModel.ExportType.allCases, id: \.self) { exportType in
                        Button(action: {
                            if exportType == .alarms {
                                viewModel.showAlarmSelection()
                            } else {
                                viewModel.exportType = exportType
                                if let qrString = viewModel.generateQRCodeForExport() {
                                    viewModel.qrCodeString = qrString
                                    viewModel.isShowingQRCodeDisplay = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: exportType.icon)
                                    .foregroundColor(.blue)
                                Text("Export \(exportType.rawValue)")
                                Spacer()
                                Image(systemName: exportType == .alarms ? "list.bullet" : "qrcode")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: - iCloud Section

                Section("iCloud Backup") {
                    Button(action: {
                        viewModel.exportToiCloud()
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Export All Settings to iCloud")
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.importFromiCloud()
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.green)
                            Text("Import Settings from iCloud")
                        }
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - Status Message

                if !viewModel.qrCodeErrorMessage.isEmpty {
                    Section {
                        let isSuccess = viewModel.qrCodeErrorMessage.contains("successfully") || viewModel.qrCodeErrorMessage.contains("Successfully imported")
                        let displayText = isSuccess ? "✅ \(viewModel.qrCodeErrorMessage)" : viewModel.qrCodeErrorMessage

                        Text(displayText)
                            .foregroundColor(isSuccess ? .green : .red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Import/Export Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $viewModel.isShowingQRCodeScanner) {
            SimpleQRCodeScannerView { result in
                viewModel.handleQRCodeScanResult(result)
            }
        }
        .sheet(isPresented: $viewModel.isShowingQRCodeDisplay) {
            NavigationView {
                VStack {
                    if !viewModel.qrCodeString.isEmpty {
                        QRCodeDisplayView(
                            qrCodeString: viewModel.qrCodeString,
                            size: CGSize(width: 300, height: 300)
                        )
                        .padding()

                        Text("Scan this QR code with another LoopFollow app to import \(viewModel.exportType.rawValue.lowercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    } else {
                        Text("Failed to generate QR code")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .navigationTitle("Export \(viewModel.exportType.rawValue)")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    viewModel.isShowingQRCodeDisplay = false
                })
            }
        }
        .sheet(isPresented: $viewModel.isShowingAlarmSelection) {
            AlarmSelectionView(
                exportedAlarmIds: viewModel.exportedAlarmIds,
                onConfirm: { selectedAlarms in
                    viewModel.exportSelectedAlarms(selectedAlarms)
                },
                onCancel: {
                    viewModel.cancelAlarmSelection()
                }
            )
        }
        .onDisappear {
            viewModel.resetExportedAlarms()
        }
    }
}

#Preview {
    ImportExportSettingsView()
}
