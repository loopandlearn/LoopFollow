// LoopFollow
// InfoTableView.swift

import SwiftUI

/// The table scrolls row by row: when scrolling ends, the top row sits at the top edge,
/// and rows that only partly fit are hidden until the next scroll.
struct InfoTableView: View {
    @ObservedObject var infoManager: InfoManager
    var timeZoneOverride: String?
    @ObservedObject private var retro = RetroSelection.shared

    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 21
    @Environment(\.displayScale) private var displayScale

    @State private var rowHeights: [Int: CGFloat] = [:]
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isScrolling = false

    private struct Row: Identifiable {
        let id: Int
        let name: String
        let value: String
        let valueColor: Color?
    }

    private static let timeZoneRowID = -1
    /// How much of a row's bottom edge may be cut off while it still counts as whole; the text sits above it.
    private static let bottomTolerance: CGFloat = 3

    private var rows: [Row] {
        var rows: [Row] = []
        if let tz = timeZoneOverride {
            rows.append(Row(id: Self.timeZoneRowID, name: "Time Zone", value: tz, valueColor: nil))
        }
        for item in infoManager.visibleRows {
            if let snapshot = retro.snapshot {
                // Scrubbing: the value at the scrubbed time, or "—" when unknown.
                let retroRow = InfoType(rawValue: item.id).flatMap { snapshot.rows[$0] }
                rows.append(Row(id: item.id, name: item.name, value: retroRow?.value ?? "", valueColor: color(for: item.id, numericValue: retroRow?.numericValue)))
            } else {
                rows.append(Row(id: item.id, name: item.name, value: item.value, valueColor: color(for: item.id, numericValue: item.numericValue)))
            }
        }
        return rows
    }

    var body: some View {
        let rows = rows
        let heights = rows.map { rowHeights[$0.id] ?? rowHeight }

        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row, showsSeparator: index < rows.count - 1)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[row.id] = $0 }
                    }
                }
                .scrollTargetLayout()

                Color.clear.frame(height: endSpace(heights))
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .onScrollGeometryChange(for: [CGFloat].self) { geometry in
            [geometry.contentOffset.y + geometry.contentInsets.top, geometry.containerSize.height]
        } action: { _, values in
            scrollOffset = values[0]
            viewportHeight = values[1]
        }
        .onScrollPhaseChange { _, phase in
            isScrolling = phase.isScrolling
        }
        .mask(alignment: .top) {
            let visible = wholeRows(heights)
            Rectangle()
                .frame(height: max(visible.upperBound - visible.lowerBound, 0))
                .offset(y: visible.lowerBound)
                .animation(.easeOut(duration: 0.15), value: visible)
        }
        .background {
            if retro.snapshot != nil {
                RetroCardBackground()
            }
        }
    }

    /// Space below the last row so that the end of the table also stops with a row at the top edge.
    private func endSpace(_ heights: [CGFloat]) -> CGFloat {
        guard viewportHeight > 0, heights.reduce(0, +) > viewportHeight else { return 0 }
        var fitting: CGFloat = 0
        for height in heights.reversed() {
            if fitting + height > viewportHeight + Self.bottomTolerance { break }
            fitting += height
        }
        return max(viewportHeight - fitting, 0)
    }

    /// The part of the viewport, from its top edge, covered by rows that fit whole. While scrolling, the whole viewport.
    private func wholeRows(_ heights: [CGFloat]) -> ClosedRange<CGFloat> {
        let full: ClosedRange<CGFloat> = 0 ... max(viewportHeight, 0)
        guard !isScrolling, viewportHeight > 0 else { return full }
        var top: CGFloat = 0
        var first: CGFloat?
        var last: CGFloat?
        for height in heights {
            let bottom = top + height
            if top >= scrollOffset - 0.5, bottom <= scrollOffset + viewportHeight + Self.bottomTolerance {
                if first == nil { first = top }
                last = bottom
            }
            top = bottom
        }
        guard let first, let last else { return full }
        return (first - scrollOffset) ... (last - scrollOffset)
    }

    /// Threshold-based color for a row's value, or nil to use the default color.
    private func color(for id: Int, numericValue: Double?) -> Color? {
        guard let numericValue,
              let type = InfoType(rawValue: id),
              let config = type.colorConfig
        else { return nil }
        return Storage.shared.infoDisplayItems.value.item(for: type)?
            .coloring.color(for: numericValue, direction: config.direction)
    }

    private func rowView(_ row: Row, showsSeparator: Bool) -> some View {
        // Show a placeholder for any field that has no value yet,
        // so the row reads as "no data" rather than appearing empty.
        let displayValue = row.value.isEmpty ? "—" : row.value

        return ViewThatFits(in: .horizontal) {
            // Preferred: compact single line (label — value)
            HStack {
                Text(row.name)
                Spacer()
                Text(displayValue)
                    .foregroundStyle(row.valueColor ?? .primary)
            }

            // Fallback when the single line won't fit: label over value
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                Text(displayValue)
                    .foregroundStyle(row.valueColor ?? .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: fontSize))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(minHeight: rowHeight)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 1 / displayScale)
                    .padding(.horizontal, 8)
            }
        }
    }
}
