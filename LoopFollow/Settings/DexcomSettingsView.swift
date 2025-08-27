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
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Dexcom Settings", displayMode: .inline)
    }
}
