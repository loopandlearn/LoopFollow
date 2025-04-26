//
//  SnoozerView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI
import Combine

struct SnoozerView: View {
    @ObservedObject var bg = Observable.shared.bgValue
    @ObservedObject var trend = Observable.shared.trendArrow
    @ObservedObject var delta = Observable.shared.delta
    @ObservedObject var minutesAgo = Observable.shared.minutesAgo
    @ObservedObject var alarmTitle = Observable.shared.alarmTitle

    @State private var snoozeMinutes = 10
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var bgColor: Color {
        switch bg.value {
        case ..<4.0:
            return .red
        case 4.0..<10:
            return .yellow
        default:
            return .blue
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(String(format: "%.1f", bg.value).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: 100, weight: .bold))
                .foregroundColor(bgColor)

            Text(trend.value)
                .font(.system(size: 40))

            Text(String(format: "%+.1f", delta.value))
                .font(.title2)

            Text("\(minutesAgo.value) min ago")
                .font(.subheadline)

            Text(currentTimeFormatted)
                .font(.largeTitle)
                .onReceive(timer) { _ in currentTime = Date() }

            if let alarm = alarmTitle.value {
                Text(alarm)
                    .font(.title2)
                    .foregroundColor(.red)
                    .padding(.top)

                Stepper("Snooze for \(snoozeMinutes) min", value: $snoozeMinutes, in: 5...60, step: 5)
                    .padding(.horizontal)

                Button("Snooze") {
                    // Call snooze logic
                    print("Snoozing \(alarm) for \(snoozeMinutes) minutes")
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
        .ignoresSafeArea()
    }

    private var currentTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
}