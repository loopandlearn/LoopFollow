// LoopFollow
// ConnectImportStepView.swift

import SwiftUI

/// The "copy from another phone" connect path: scan a QR code exported from an
/// already-configured LoopFollow and apply those settings. Reuses the same
/// scanner, preview, and import logic as Settings → Import/Export.
struct ConnectImportStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var importVM = ImportExportSettingsViewModel()

    private var importSucceeded: Bool {
        importVM.qrCodeErrorMessage.contains("Successfully imported")
    }

    var body: some View {
        VStack(spacing: 0) {
            form
            OnboardingNavFooter(
                continueEnabled: viewModel.didImportSettings,
                showBack: viewModel.canGoBack,
                onBack: { viewModel.goBack() },
                onContinue: { viewModel.advance() }
            )
        }
    }

    private var form: some View {
        Form {
            Section {
                EmptyView()
            } header: {
                OnboardingStepHeader(
                    systemImage: "qrcode",
                    title: "Copy from another phone",
                    subtitle: "On your other phone, open Settings → Nightscout (or Dexcom Share) → Import/Export and export to a QR code. Then scan it here."
                )
                .textCase(nil)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Button {
                    importVM.isShowingQRCodeScanner = true
                } label: {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(.accentColor)
                        Text(viewModel.didImportSettings ? "Scan a different code" : "Scan QR Code")
                    }
                }
            }

            if viewModel.didImportSettings {
                Section {
                    Label("Settings imported — you're connected.", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else if !importVM.qrCodeErrorMessage.isEmpty {
                Section {
                    Text(importVM.qrCodeErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $importVM.isShowingQRCodeScanner) {
            SimpleQRCodeScannerView { result in
                importVM.handleQRCodeScanResult(result)
            }
        }
        .sheet(isPresented: $importVM.showImportConfirmation) {
            ImportConfirmationView(viewModel: importVM)
        }
        .onChange(of: importVM.qrCodeErrorMessage) { message in
            if message.contains("Successfully imported") {
                viewModel.didImportSettings = true
            }
        }
    }
}
