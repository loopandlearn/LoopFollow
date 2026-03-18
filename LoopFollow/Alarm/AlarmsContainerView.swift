// LoopFollow
// AlarmsContainerView.swift

import SwiftUI

struct AlarmsContainerView: View {
    var onDismiss: (() -> Void)?

    var body: some View {
        NavigationStack {
            AlarmListView()
                .toolbar {
                    if let onDismiss {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            AlarmSettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }
}
