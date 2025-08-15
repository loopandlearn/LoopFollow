// LoopFollow
// AlarmsContainerView.swift

import SwiftUI

struct AlarmsContainerView: View {
    var body: some View {
        NavigationStack {
            AlarmListView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            AlarmSettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }
}
