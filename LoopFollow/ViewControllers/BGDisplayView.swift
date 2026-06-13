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

    var onRefresh: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(serverText.value)
                    .font(.system(size: 13))

                Text(bgText.value)
                    .font(.system(size: 85, weight: .black))
                    .foregroundColor(bgTextColor.value)
                    .strikethrough(
                        bgStale.value,
                        pattern: .solid,
                        color: bgStale.value ? .red : .clear
                    )
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                HStack {
                    Text(directionText.value)
                        .font(.system(size: 60, weight: .black))
                    Text(deltaText.value)
                        .font(.system(size: 32))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)

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
        .refreshable {
            onRefresh?()
        }
    }
}
