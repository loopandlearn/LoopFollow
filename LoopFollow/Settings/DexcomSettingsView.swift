// LoopFollow
// DexcomSettingsView.swift

import SwiftUI

struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel

    var body: some View {
        Form {
            Section {
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
                .pickerStyle(.segmented)
            } header: {
                Label("Dexcom Settings", systemImage: "drop.fill")
            } footer: {
                Text("Enter your Dexcom Share credentials. Select 'US' for accounts created in the United States, otherwise select 'NON-US'.")
            }

            importSection
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Dexcom Settings", displayMode: .inline)
    }

    private var importSection: some View {
        Section {
            NavigationLink(destination: ImportExportSettingsView()) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.blue)
                    Text("Import Settings from QR Code")
                }
            }
        } header: {
            Label("Import Settings", systemImage: "square.and.arrow.down")
        }
    }
}
