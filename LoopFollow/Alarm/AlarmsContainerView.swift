// LoopFollow
// AlarmsContainerView.swift

import SwiftUI

struct AlarmsContainerView: View {
    private let embedsInNavigationStack: Bool

    init(embedsInNavigationStack: Bool = true) {
        self.embedsInNavigationStack = embedsInNavigationStack
    }

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    private var content: some View {
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
}
