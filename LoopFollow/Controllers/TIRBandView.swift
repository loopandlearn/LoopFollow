// LoopFollow
// TIRBandView.swift

import SwiftUI

/// Time in Range band for the home screen: today's in-range
/// percentage above a segmented bar (very low / low / in range / high).
/// The range follows the Range Mode in Settings (TIR, TITR or Custom).
/// Tapping opens the statistics screen.
struct TIRBandView: View {
    @ObservedObject var model: StatsDisplayModel
    var onTap: (() -> Void)?

    private var percentText: String {
        guard model.bandHasData else { return "-- %" }
        return model.bandInRangePct.formatted(.number.precision(.fractionLength(0 ... 1))) + " %"
    }

    private var segments: [(color: Color, fraction: CGFloat)] {
        guard model.bandHasData else { return [(Color.secondary.opacity(0.3), 1)] }
        return [
            (.red, CGFloat(model.bandVeryLowPct / 100)),
            (.orange, CGFloat(model.bandLowPct / 100)),
            (.green, CGFloat(model.bandInRangePct / 100)),
            (.purple, CGFloat(model.bandHighPct / 100)),
        ]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(percentText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    (Text(model.bandTitle).fontWeight(.semibold) + Text(" today"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                DistributionBar(segments: segments)
                    .frame(height: 6)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

/// Horizontal bar of capsules, one per non-empty segment, sized by share.
private struct DistributionBar: View {
    let segments: [(color: Color, fraction: CGFloat)]

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let shown = segments.filter { $0.fraction > 0.005 }
            let available = max(geo.size.width - spacing * CGFloat(max(shown.count - 1, 0)), 0)
            HStack(spacing: spacing) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: available * segment.fraction)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
