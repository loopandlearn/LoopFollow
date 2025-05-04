//
//  SnoozerView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct SnoozerView: View {
    @StateObject private var vm = SnoozerViewModel()

    @ObservedObject var minAgoText = Observable.shared.minAgoText
    @ObservedObject var bgText     = Observable.shared.bgText
    @ObservedObject var bgTextColor = Observable.shared.bgTextColor
    @ObservedObject var directionText = Observable.shared.directionText
    @ObservedObject var deltaText   = Observable.shared.deltaText
    @ObservedObject var bgStale     = Observable.shared.bgStale

    var body: some View {
        GeometryReader { geo in
            Color.black.ignoresSafeArea()
                .overlay(contentColumn(size: geo.size))
                .animation(.easeInOut, value: vm.activeAlarm != nil)
        }
    }


    // MARK: – Layout helper
    @ViewBuilder private func contentColumn(size: CGSize) -> some View {
        if size.width > size.height {   // landscape
            HStack(spacing: 0) { leftPanel ; rightPanel }
        } else {                        // portrait
            VStack(spacing: 0) { leftPanel ; rightPanel }
        }
    }

    // MARK: - Left Column (BG / Direction / Delta / Age)
    private var leftPanel: some View  {
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

    // MARK: – Right (Clock + Snooze)
    private var rightPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(ctx.date, style: .time)
                    .font(.system(size: 70, weight: .regular))
                    .foregroundColor(.white)
            }
            .frame(height: 80)

            if let alarm = vm.activeAlarm {
                Text(alarm.name)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.red)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)

                Spacer(minLength: 32)

                snoozeControls(alarm: alarm)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: – Snooze UI
    @ViewBuilder private func snoozeControls(alarm: Alarm) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Snooze for")
                Spacer()
                Text("\(vm.snoozeMins) \(vm.timeUnitLabel)")
            }
            .font(.title3)
            .foregroundColor(.white)

            Stepper("", value: $vm.snoozeMins,
                    in: 1...120,
                    step: alarm.type.timeUnit == .minute ? 5 : 1)
            .labelsHidden()

            Button(action: vm.snoozeTapped) {
                Text("Snooze")
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
        }
    }
}
