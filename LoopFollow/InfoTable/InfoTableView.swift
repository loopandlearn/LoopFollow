// LoopFollow
// InfoTableView.swift

import SwiftUI

struct InfoTableView: View {
    @ObservedObject var infoManager: InfoManager
    var timeZoneOverride: String?

    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 21

    var body: some View {
        List {
            if let tz = timeZoneOverride {
                row(name: "Time Zone", value: tz)
            }
            ForEach(infoManager.visibleRows) { item in
                row(name: item.name, value: item.value)
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, rowHeight)
    }

    private func row(name: String, value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: fontSize))
        .frame(height: rowHeight)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
    }
}
