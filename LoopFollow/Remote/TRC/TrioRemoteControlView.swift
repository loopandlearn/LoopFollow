// LoopFollow
// TrioRemoteControlView.swift
// Created by Jonas Björkert.

import SwiftUI

struct TrioRemoteControlView: View {
    @ObservedObject var viewModel: TrioRemoteControlViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    CommandButtonView(command: "Meal", iconName: "fork.knife", destination: MealView())
                    CommandButtonView(command: "Bolus", iconName: "syringe", destination: BolusView())
                    CommandButtonView(command: "Temp Target", iconName: "scope", destination: TempTargetView())
                    CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: OverrideView())
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitle("Trio Remote Control", displayMode: .inline)
        }
    }
}

struct CommandButtonView<Destination: View>: View {
    let command: String
    let iconName: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Text(command)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
