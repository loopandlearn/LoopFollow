// LoopFollow
// AlarmsContainerView.swift

import SwiftUI

struct AlarmsContainerView: View {
    var onBack: (() -> Void)?

    var body: some View {
        NavigationStack {
            AlarmListView()
                .toolbar {
                    if let onBack {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
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
