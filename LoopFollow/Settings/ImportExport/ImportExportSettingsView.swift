// LoopFollow
// ImportExportSettingsView.swift

import AVFoundation
import SwiftUI
import UIKit

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

                Section("iCloud Import") {
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

                Section("iCloud Export") {
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
        .sheet(isPresented: $viewModel.showImportConfirmation) {
            ImportConfirmationView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showExportSuccessAlert) {
            ExportSuccessView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showImportNotFoundAlert) {
            ImportNotFoundView(viewModel: viewModel)
        }
    }
}

struct ImportNotFoundView: View {
    @ObservedObject var viewModel: ImportExportSettingsViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("No Settings Found")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(viewModel.importNotFoundMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 30)

                Spacer()

                // Done Button
                Button(action: {
                    viewModel.showImportNotFoundAlert = false
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("OK")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }
}

struct ExportSuccessView: View {
    @ObservedObject var viewModel: ImportExportSettingsViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Export Successful")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(viewModel.exportSuccessMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)

                // Exported Settings Details
                if !viewModel.exportSuccessDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exported Settings")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(viewModel.exportSuccessDetails, id: \.self) { detail in
                                HStack(spacing: 12) {
                                    Image(systemName: iconForDetail(detail))
                                        .font(.title2)
                                        .foregroundColor(colorForDetail(detail))
                                        .frame(width: 30)

                                    Text(detail)
                                        .font(.subheadline)
                                        .lineLimit(2)

                                    Spacer()

                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // Done Button
                Button(action: {
                    viewModel.showExportSuccessAlert = false
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Done")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }

    private func iconForDetail(_ detail: String) -> String {
        if detail.lowercased().contains("nightscout") {
            return "network"
        } else if detail.lowercased().contains("dexcom") {
            return "person.circle"
        } else if detail.lowercased().contains("remote") {
            return "antenna.radiowaves.left.and.right"
        } else if detail.lowercased().contains("alarm") {
            return "bell"
        }
        return "gear"
    }

    private func colorForDetail(_ detail: String) -> Color {
        if detail.lowercased().contains("nightscout") {
            return .blue
        } else if detail.lowercased().contains("dexcom") {
            return .green
        } else if detail.lowercased().contains("remote") {
            return .orange
        } else if detail.lowercased().contains("alarm") {
            return .red
        }
        return .gray
    }
}

struct ImportConfirmationView: View {
    @ObservedObject var viewModel: ImportExportSettingsViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("Import Settings")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Review the settings that will be imported")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Settings Preview
                if let preview = viewModel.importPreview {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Settings to Import")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            if let url = preview.nightscoutURL, !url.isEmpty {
                                SettingRowView(
                                    icon: "network",
                                    title: "Nightscout URL",
                                    value: url,
                                    color: .blue
                                )
                            }

                            if let username = preview.dexcomUsername, !username.isEmpty {
                                SettingRowView(
                                    icon: "person.circle",
                                    title: "Dexcom Username",
                                    value: username,
                                    color: .green
                                )
                            }

                            if let remoteType = preview.remoteType, !remoteType.isEmpty, remoteType != "None" {
                                SettingRowView(
                                    icon: "antenna.radiowaves.left.and.right",
                                    title: "Remote Type",
                                    value: remoteType,
                                    color: .orange
                                )
                            }

                            if preview.alarmCount > 0 {
                                SettingRowView(
                                    icon: "bell",
                                    title: "Alarms",
                                    value: "\(preview.alarmCount) alarm(s): \(preview.alarmNames.joined(separator: ", "))",
                                    color: .red
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Warning
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Warning")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }

                    Text("This will overwrite your current settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.confirmImport()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Import Settings")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.cancelImport()
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SettingRowView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ImportExportSettingsView()
}
