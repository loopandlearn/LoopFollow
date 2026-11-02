// LoopFollow
// TIRBandView.swift

import SwiftUI

/// Time in Range band for the home screen: today's in-range
/// percentage above a segmented bar (very low / low / in range / high / very high).
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
            (TIRGraphView.Band.veryLow.color, CGFloat(model.bandVeryLowPct / 100)),
            (TIRGraphView.Band.low.color, CGFloat(model.bandLowPct / 100)),
            (TIRGraphView.Band.inRange.color, CGFloat(model.bandInRangePct / 100)),
            (TIRGraphView.Band.high.color, CGFloat(model.bandHighPct / 100)),
            (TIRGraphView.Band.veryHigh.color, CGFloat(model.bandVeryHighPct / 100)),
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
                    (Text(model.bandTitle).fontWeight(.semibold) + Text(" " + model.bandPeriod))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                DistributionBar(segments: segments)
                    .frame(height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
/// Every non-empty segment is at least `minSegmentWidth` wide so a single
/// reading stays visible.
private struct DistributionBar: View {
    let segments: [(color: Color, fraction: CGFloat)]

    private let spacing: CGFloat = 2
    private let minSegmentWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let shown = segments.filter { $0.fraction > 0 }
            let available = max(geo.size.width - spacing * CGFloat(max(shown.count - 1, 0)), 0)
            let widths = segmentWidths(shown.map(\.fraction), available: available)
            HStack(spacing: spacing) {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: widths[index])
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func segmentWidths(_ fractions: [CGFloat], available: CGFloat) -> [CGFloat] {
        var widths = fractions.map { max($0 * available, minSegmentWidth) }
        let excess = widths.reduce(0, +) - available
        if excess > 0, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }) {
            widths[widest] = max(widths[widest] - excess, minSegmentWidth)
        }
        return widths
    }
}
