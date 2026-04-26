// LoopFollow
// DexcomSettingsView.swift

import SwiftUI

struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel
    var usesModalCloseButton: Bool = false
    var onContinueToUnits: (() -> Void)? = nil
    @State private var showUnitsSetup = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("Dexcom Settings")) {
                HStack {
                    Text("User Name")
                    TextField("Enter User Name", text: $viewModel.userName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Password")
                    TogglableSecureInput(
                        placeholder: "Enter Password",
                        text: $viewModel.password,
                        style: .singleLine
                    )
                }

                Picker("Server", selection: $viewModel.server) {
                    Text("US").tag("US")
                    Text("NON-US").tag("NON-US")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            if viewModel.isFreshSetup {
                Section {
                    Button(action: {
                        if let onContinueToUnits {
                            onContinueToUnits()
                        } else {
                            showUnitsSetup = true
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.hasCredentials)
                    .listRowBackground(Color.clear)
                }
            }

            importSection
        }
        .navigationDestination(isPresented: $showUnitsSetup) {
            UnitsOnboardingView {
                dismiss()
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Dexcom Settings", displayMode: .inline)
        .navigationBarBackButtonHidden(usesModalCloseButton)
    }

    private var importSection: some View {
        Section(header: Text("Import Settings")) {
            NavigationLink(destination: ImportExportSettingsView()) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                    Text("Import Settings from QR Code")
                }
            }
        }
    }
}
