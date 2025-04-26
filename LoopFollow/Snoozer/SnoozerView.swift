//
//  SnoozerView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct SnoozerView: View {
    @ObservedObject var minAgoText = Observable.shared.minAgoText
    @ObservedObject var bgText     = Observable.shared.bgText
    @ObservedObject var bgTextColor = Observable.shared.bgTextColor
    @ObservedObject var directionText = Observable.shared.directionText
    @ObservedObject var deltaText   = Observable.shared.deltaText
    @ObservedObject var bgStale     = Observable.shared.bgStale

    @Binding var snoozeMinutes: Int
    var onSnooze: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                Group {
                    if geo.size.width > geo.size.height {
                        // Landscape: two columns
                        HStack(spacing: 0) {
                            leftColumn
                            rightColumn
                        }
                    } else {
                        // Portrait: single column
                        VStack(spacing: 0) {
                            leftColumn
                            rightColumn
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    // MARK: - Left Column (BG / Direction / Delta / Age)
    private var leftColumn: some View {
        VStack(spacing: 0) {
            Text(bgText.value)
                .font(.system(size: 220, weight: .black))
                .minimumScaleFactor(0.5)
                .foregroundColor(bgTextColor.value)
                .strikethrough(
                    bgStale.value,
                    pattern: .solid,
                    color: bgStale.value ? .red : .clear
                )
                .frame(maxWidth: .infinity, maxHeight: 167)

            Text(directionText.value)
                .font(.system(size: 110, weight: .black))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: 96)

            Text(deltaText.value)
                .font(.system(size: 70))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: 78)

            Text(minAgoText.value)
                .font(.system(size: 70))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: 48)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Right Column (Clock/Alert + Snooze Controls)
    private var rightColumn: some View {
        VStack(spacing: 0) {
            Spacer()

            // Clock and (optional) alert
            VStack(spacing: 8) {
                Text("19:59" /* replace with time.value */)
                    .font(.system(size: 70))
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .frame(height: 78)

                /*
                if let alarm = alarmText.value, !alarm.isEmpty {
                    Text(alarm)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(height: 48)
                }
                */
            }

            Spacer()

            // Snooze controls
            HStack(spacing: 12) {
                Text("Snooze for")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                Text("\(snoozeMinutes) min")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Stepper("", value: $snoozeMinutes, in: 1...60)
                    .labelsHidden()
            }
            .padding(.horizontal, 32)
            .frame(height: 44)

            Button(action: onSnooze) {
                Text("Snooze")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .background(Color(white: 0.15))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .padding(.top, 16)
    }
}
