//
//  TrioRemoteControlView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct TrioRemoteControlView: View {
    @ObservedObject var viewModel: TrioRemoteControlViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    CommandButtonView(command: "Meal", iconName: "fork.knife", destination: MealView())
                    CommandButtonView(command: "Bolus", iconName: "syringe", destination: BolusView())
                    CommandButtonView(command: "Temp Target", iconName: "scope", destination: TempTargetView())
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitle("Trio Remote Control", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
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
