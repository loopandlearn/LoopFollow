// LoopFollow
// BGDisplayView.swift

import SwiftUI

struct BGDisplayView: View {
    @ObservedObject var serverText = Observable.shared.serverText
    @ObservedObject var bgText = Observable.shared.bgText
    @ObservedObject var bgTextColor = Observable.shared.bgTextColor
    @ObservedObject var bgStale = Observable.shared.bgStale
    @ObservedObject var directionText = Observable.shared.directionText
    @ObservedObject var deltaText = Observable.shared.deltaText
    @ObservedObject var minAgoText = Observable.shared.minAgoText
    @ObservedObject var loopStatusText = Observable.shared.loopStatusText
    @ObservedObject var loopStatusColor = Observable.shared.loopStatusColor
    @ObservedObject var predictionText = Observable.shared.predictionText
    @ObservedObject var predictionColor = Observable.shared.predictionColor
    @ObservedObject var isNotLooping = Observable.shared.isNotLooping
    @ObservedObject var retro = RetroSelection.shared

    var onRefresh: (() -> Void)?

    var body: some View {
        // While scrubbing the chart, the display shows the scrubbed time.
        let snapshot = retro.snapshot
        let isStale = snapshot == nil && bgStale.value

        ScrollView {
            VStack(spacing: 0) {
                Text(serverText.value)
                    .font(.system(size: 13))

                Text(snapshot?.bgText ?? bgText.value)
                    .font(.system(size: 85, weight: .black))
                    .foregroundColor(snapshot?.bgColor ?? bgTextColor.value)
                    .strikethrough(
                        isStale,
                        pattern: .solid,
                        color: isStale ? .red : .clear
                    )
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                HStack {
                    Text(snapshot?.directionText ?? directionText.value)
                        .font(.system(size: 60, weight: .black))
                    Text(snapshot?.deltaText ?? deltaText.value)
                        .font(.system(size: 32))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)

                if let snapshot {
                    Label(snapshot.timeText, systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(RetroSnapshot.accent.opacity(0.3)))
                    Text(snapshot.predictionText)
                        .foregroundColor(snapshot.predictionColor)
                        .font(.system(size: 17))
                } else {
                    Text(minAgoText.value)
                        .font(.system(size: 17))

                    if isNotLooping.value {
                        Text(loopStatusText.value)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(loopStatusColor.value)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Spacer()
                            Text(loopStatusText.value)
                                .foregroundColor(loopStatusColor.value)
                            Text(predictionText.value)
                                .foregroundColor(predictionColor.value)
                            Spacer()
                        }
                        .font(.system(size: 17))
                    }
                }
            }
        }
        .background {
            if snapshot != nil {
                RetroCardBackground()
            }
        }
        .refreshable {
            onRefresh?()
        }
    }
}
