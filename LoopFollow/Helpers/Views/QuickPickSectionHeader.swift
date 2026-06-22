// LoopFollow
// QuickPickSectionHeader.swift

import SwiftUI

struct QuickPickSectionHeader: View {
    let title: String
    let infoText: String
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showInfo) {
            QuickPickInfoSheet(title: title, text: infoText)
        }
    }
}

private struct QuickPickInfoSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

extension QuickPickSectionHeader {
    static let bolusInfoText = """
    These buttons show your most-used recent bolus amounts.

    They're based on what you've sent before at similar times on similar days — so if you usually give 4 units before breakfast on weekdays, that button will show up on weekday mornings.

    Tap a button to fill in the amount. Nothing is sent until you review and confirm.
    """

    static let mealInfoText = """
    These buttons show your most-used recent meals.

    They're based on what you've sent before at similar times on similar days — so if you usually send the same breakfast on weekday mornings, it'll appear as an option.

    Tap a button to fill in the details. Nothing is sent until you review and confirm.
    """
}
