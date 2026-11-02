// LoopFollow
// TreatmentMenuView.swift

import SwiftUI

struct TreatmentMenuView: View {
    @EnvironmentObject private var navigator: WatchNavigator

    var body: some View {
        List {
            Button {
                navigator.push(.meal)
            } label: {
                Label("Meal", systemImage: "fork.knife")
            }
            Button {
                navigator.push(.bolus)
            } label: {
                Label("Bolus", systemImage: "syringe")
            }
        }
        .navigationTitle("Treatment")
    }
}
