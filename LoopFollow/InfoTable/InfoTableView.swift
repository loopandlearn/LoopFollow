// LoopFollow
// InfoTableView.swift

import SwiftUI

struct InfoTableView: View {
    @ObservedObject var infoManager: InfoManager
    var timeZoneOverride: String?
    @ObservedObject private var retro = RetroSelection.shared

    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 21

    var body: some View {
        List {
            if let tz = timeZoneOverride {
                row(name: "Time Zone", value: tz)
            }
            ForEach(infoManager.visibleRows) { item in
                if let snapshot = retro.snapshot {
                    // Scrubbing: the value at the scrubbed time, or "—" when unknown.
                    let retroRow = InfoType(rawValue: item.id).flatMap { snapshot.rows[$0] }
                    row(name: item.name, value: retroRow?.value ?? "", valueColor: color(for: item.id, numericValue: retroRow?.numericValue))
                        .listRowBackground(Color.clear)
                } else {
                    row(name: item.name, value: item.value, valueColor: color(for: item.id, numericValue: item.numericValue))
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, rowHeight)
        .scrollContentBackground(retro.snapshot != nil ? .hidden : .automatic)
        .background {
            if retro.snapshot != nil {
                RetroCardBackground()
            }
        }
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

    private func row(name: String, value: String, valueColor: Color? = nil) -> some View {
        // Show a placeholder for any field that has no value yet,
        // so the row reads as "no data" rather than appearing empty.
        let displayValue = value.isEmpty ? "—" : value

        return ViewThatFits(in: .horizontal) {
            // Preferred: compact single line (label — value)
            HStack {
                Text(name)
                Spacer()
                Text(displayValue)
                    .foregroundStyle(valueColor ?? .primary)
            }

            // Fallback when the single line won't fit: label over value
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                Text(displayValue)
                    .foregroundStyle(valueColor ?? .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: fontSize))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(minHeight: rowHeight)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
    }
}
