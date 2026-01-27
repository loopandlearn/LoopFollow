// LoopFollow
// DexcomSettingsView.swift

import SwiftUI

struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel

    var body: some View {
        NavigationView {
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

                importSection
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Dexcom Settings", displayMode: .inline)
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
