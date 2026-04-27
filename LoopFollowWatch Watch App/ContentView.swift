// LoopFollow
// ContentView.swift

import Combine
import SwiftUI
import WatchConnectivity

// MARK: - Root view

struct ContentView: View {
    @StateObject private var model = WatchViewModel()

    var body: some View {
        TabView {
            GlucoseView(model: model)

            ForEach(Array(model.pages.enumerated()), id: \.offset) { _, page in
                DataGridPage(slots: page, snapshot: model.snapshot)
            }

            SlotSelectionView(model: model)
        }
        .tabViewStyle(.page)
        .onAppear { model.refresh() }
    }
}

// MARK: - View model

final class WatchViewModel: ObservableObject {
    @Published var snapshot: GlucoseSnapshot?
    @Published var selectedSlots: [LiveActivitySlotOption] = LAAppGroupSettings.watchSelectedSlots()

    private var timer: Timer?
    private var notificationObserver: Any?

    init() {
        snapshot = GlucoseSnapshotStore.shared.load()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // Subscribe in init so notifications fired before the view appears are not missed.
        notificationObserver = NotificationCenter.default.addObserver(
            forName: WatchSessionReceiver.snapshotReceivedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let s = notification.userInfo?["snapshot"] as? GlucoseSnapshot {
                self?.update(snapshot: s)
            } else {
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func refresh() {
        if let loaded = GlucoseSnapshotStore.shared.load() {
            snapshot = loaded
        }
        selectedSlots = LAAppGroupSettings.watchSelectedSlots()
    }

    func update(snapshot: GlucoseSnapshot) {
        self.snapshot = snapshot
        selectedSlots = LAAppGroupSettings.watchSelectedSlots()
    }

    /// Slots grouped into pages of 4 for the swipable grid tabs.
    var pages: [[LiveActivitySlotOption]] {
        guard !selectedSlots.isEmpty else { return [] }
        return stride(from: 0, to: selectedSlots.count, by: 4).map {
            Array(selectedSlots[$0 ..< min($0 + 4, selectedSlots.count)])
        }
    }

    func isSelected(_ option: LiveActivitySlotOption) -> Bool {
        selectedSlots.contains(option)
    }

    func toggleSlot(_ option: LiveActivitySlotOption) {
        if let idx = selectedSlots.firstIndex(of: option) {
            selectedSlots.remove(at: idx)
        } else {
            selectedSlots.append(option)
        }
        LAAppGroupSettings.setWatchSelectedSlots(selectedSlots)
    }
}

// MARK: - Page 1: Glucose

struct GlucoseView: View {
    @ObservedObject var model: WatchViewModel

    var body: some View {
        if let s = model.snapshot, s.age < 900 {
            VStack(alignment: .leading, spacing: 6) {
                // Large BG + trend arrow, single line, auto-scaled to fit 7 chars
                Text("\(WatchFormat.glucose(s)) \(WatchFormat.trendArrow(s))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundColor(ComplicationEntryBuilder.thresholdColor(for: s).swiftUIColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Delta: \(WatchFormat.delta(s)) \(s.unit.displayName)")
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    if s.projected != nil {
                        Text("Projected: \(WatchFormat.projected(s)) \(s.unit.displayName)")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }

                    Text("Last update: \(WatchFormat.updateTime(s))")
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    if s.isNotLooping {
                        Text("⚠ Loop inactive")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.horizontal, 4)
        } else {
            VStack(spacing: 4) {
                Text("--")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(model.snapshot == nil ? "No data" : "Stale")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Data grid page (2×2, up to 4 slots)

struct DataGridPage: View {
    let slots: [LiveActivitySlotOption]
    let snapshot: GlucoseSnapshot?

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(0 ..< 4, id: \.self) { i in
                if i < slots.count {
                    let option = slots[i]
                    MetricCell(
                        label: option.gridLabel,
                        value: snapshot.map { WatchFormat.slotValue(option: option, snapshot: $0) } ?? "—"
                    )
                } else {
                    Color.clear.frame(height: 52)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Metric cell

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Last tab: slot selection checklist

struct SlotSelectionView: View {
    @ObservedObject var model: WatchViewModel

    var body: some View {
        List {
            // `.delta` and `.projectedBG` are always shown on the glucose page,
            // so they're excluded from the grid slot picker to avoid duplication.
            ForEach(LiveActivitySlotOption.allCases.filter { $0 != .none && $0 != .delta && $0 != .projectedBG }, id: \.self) { option in
                Button(action: { model.toggleSlot(option) }) {
                    HStack {
                        Text(option.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(
                            systemName: model.isSelected(option)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundColor(model.isSelected(option) ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Data")
    }
}

// MARK: - UIColor → SwiftUI Color bridge

private extension UIColor {
    var swiftUIColor: Color { Color(self) }
}
