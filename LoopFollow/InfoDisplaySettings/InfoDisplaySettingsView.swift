// LoopFollow
// InfoDisplaySettingsView.swift

import SwiftUI

struct InfoDisplaySettingsView: View {
    @ObservedObject var viewModel: InfoDisplaySettingsViewModel

    var body: some View {
        Form {
            Section("General") {
                Toggle(isOn: Binding(
                    get: { Storage.shared.hideInfoTable.value },
                    set: { Storage.shared.hideInfoTable.value = $0 }
                )) {
                    Text("Hide Information Table")
                }
            }

            Section("Information Display Settings") {
                List {
                    ForEach(viewModel.infoSort, id: \.self) { sortedIndex in
                        HStack {
                            Text(viewModel.getName(for: sortedIndex))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.infoVisible[sortedIndex] },
                                set: { _ in
                                    viewModel.toggleVisibility(for: sortedIndex)
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove(perform: viewModel.move)
                }
                .environment(\.editMode, .constant(.active))
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Information Display Settings", displayMode: .inline)
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }
    }
}
