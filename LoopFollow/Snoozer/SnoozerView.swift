//
//  SnoozerView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

struct SnoozerView: View {
    @ObservedObject var bgValue: ObservableValue<String>
    @ObservedObject var deltaValue: ObservableValue<String>
    @ObservedObject var direction: ObservableValue<String>
    @ObservedObject var age: ObservableValue<String>
    @ObservedObject var time: ObservableValue<String>
    @ObservedObject var alarmText: ObservableValue<String?>

    @Binding var snoozeMinutes: Int
    var onSnooze: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(bgValue.value)
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.yellow)

            if let alarm = alarmText.value, !alarm.isEmpty {
                Text(alarm)
                    .font(.title2)
                    .foregroundColor(.red)
            }

            Text(direction.value)
                .font(.title)

            Text(deltaValue.value)
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))

            Text(age.value + " ago")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            Text(time.value)
                .font(.title3)

            HStack {
                Text("Snooze for \(snoozeMinutes) min")
                Stepper("", value: $snoozeMinutes, in: 1...60)
                    .labelsHidden()
            }
            .padding(.top)

            Button("Snooze", action: onSnooze)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}
