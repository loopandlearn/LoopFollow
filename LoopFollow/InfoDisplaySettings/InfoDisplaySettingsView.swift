// LoopFollow
// InfoDisplaySettingsView.swift

import SwiftUI

struct InfoDisplaySettingsView: View {
    @ObservedObject var viewModel: InfoDisplaySettingsViewModel
    @State private var selectedID: Int?

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle(isOn: Binding(
                    get: { Storage.shared.hideInfoTable.value },
                    set: { Storage.shared.hideInfoTable.value = $0 }
                )) {
                    Text("Hide Information Table")
                }
            }

            Section(
                header: Text("Information Display Settings"),
                footer: Text("Drag to reorder. Tap a row to set its visibility and colors.")
            ) {
                // The list stays in edit mode so rows are always draggable; a
                // Button (unlike NavigationLink) still receives taps in edit
                // mode, so reordering and navigation work at the same time.
                ForEach(viewModel.items) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        rowLabel(for: item)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: viewModel.move)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationDestination(isPresented: Binding(
            get: { selectedID != nil },
            set: { if !$0 { selectedID = nil } }
        )) {
            if let id = selectedID {
                InfoRowSettingsView(item: viewModel.binding(for: id))
            }
        }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Information Display Settings", displayMode: .inline)
    }

    private func rowLabel(for item: InfoDisplayItem) -> some View {
        HStack {
            Text(item.type.name)
            Spacer()
            if item.type.isColorable, item.coloring.enabled {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Coloring enabled")
            }
            Text(item.isVisible ? "On" : "Off")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
