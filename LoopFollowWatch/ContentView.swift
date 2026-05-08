// LoopFollow
// ContentView.swift

import SwiftUI
import WatchKit
import WidgetKit

struct ContentView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @ObservedObject var bgFetcher: BGFetcher

    @State private var now = Date()
    @State private var timeOffset: Double = 7.2 // zoomHours(2) * 3.6 — aligns marker with "now"
    @State private var zoomHours: Double = 2
    @State private var showReloadCheck = false
    @State private var showLoopDetail = false
    @State private var timeTravelDebounce: Timer?
    @Environment(\.scenePhase) private var scenePhase
    let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Whether the user has scrolled away from the present (more than 1 reading back)
    private var isTimeTravel: Bool { timeOffset < -1 }

    /// The inspected point — 70% through the visible chart window
    private var viewCenterTime: Date {
        Date().addingTimeInterval(timeOffset * 300 - zoomHours * 3600 * 0.3)
    }

    var body: some View {
        Group {
            if let config = sessionManager.config, config.hasAnySource {
                if let reading = displayReading {
                    mainView(reading: reading, config: config)
                } else if let error = bgFetcher.lastError {
                    VStack(spacing: 4) {
                        Text("---")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .offset(y: -20)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No Config")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Open LoopFollow on\nyour iPhone to sync\nsettings.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onReceive(secondTimer) { _ in now = Date() }
        .onChange(of: zoomHours) { newZoom in
            // Re-align inspection marker to "now" when zoom changes
            timeOffset = newZoom * 3.6
        }
        .onChange(of: timeOffset) { _ in
            timeTravelDebounce?.invalidate()
            if isTimeTravel, let config = sessionManager.config {
                timeTravelDebounce = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                    bgFetcher.fetchDeviceStatusAt(config: config, date: viewCenterTime)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive {
                WidgetCenter.shared.reloadTimelines(ofKind: "BGComplication")
            }
            if newPhase == .active {
                refreshIfStale()
            }
        }
    }

    /// Refresh data if the last BG reading is older than 5 minutes
    private func refreshIfStale() {
        guard let reading = bgFetcher.currentBG else {
            bgFetcher.reload()
            return
        }
        if Date().timeIntervalSince(reading.timestamp) > 300 {
            bgFetcher.reload()
        }
    }

    /// Visible chart window edges (mirrors BGChartView's calculation)
    private var visibleStart: Date {
        Date().addingTimeInterval(-zoomHours * 3600 + timeOffset.rounded() * 300)
    }

    private var visibleEnd: Date {
        Date().addingTimeInterval(timeOffset.rounded() * 300)
    }

    private func bgBarGradient(bgHistory: [BGReading]) -> LinearGradient {
        let start = visibleStart
        let end = visibleEnd
        let visible = bgHistory.filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp < $1.timestamp }
        guard visible.count >= 2,
              let first = visible.first?.timestamp,
              let last = visible.last?.timestamp,
              last > first
        else {
            // Fall back to single color from current reading
            if let reading = visible.first ?? bgHistory.last {
                return LinearGradient(colors: [bgDynamicColor(Double(reading.bgValue)).opacity(0.4)], startPoint: .leading, endPoint: .trailing)
            }
            return LinearGradient(colors: [bgDynamicColor(100).opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        }
        let span = last.timeIntervalSince(first)
        let step = max(1, visible.count / 10)
        var stops: [Gradient.Stop] = []
        for i in stride(from: 0, to: visible.count, by: step) {
            let t = visible[i].timestamp.timeIntervalSince(first) / span
            stops.append(.init(color: bgDynamicColor(Double(visible[i].bgValue)).opacity(0.4), location: t))
        }
        if let lastReading = visible.last {
            stops.append(.init(color: bgDynamicColor(Double(lastReading.bgValue)).opacity(0.4), location: 1.0))
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private var displayReading: BGReading? {
        bgFetcher.bgHistory.min(by: {
            abs($0.timestamp.timeIntervalSince(viewCenterTime)) < abs($1.timestamp.timeIntervalSince(viewCenterTime))
        }) ?? bgFetcher.currentBG
    }

    @ViewBuilder
    private func mainView(reading: BGReading, config: WatchConfig) -> some View {
        let bgColor = bgDynamicColor(Double(reading.bgValue))
        let stale = isTimeTravel ? false : reading.isStale

        ZStack {
            VStack(spacing: 0) {
                // Row 1: BG + trend/delta stack ... loop indicator + reload
                HStack(alignment: .center, spacing: 2) {
                    Text(reading.bgText(units: config.units))
                        .font(.system(size: 48, weight: .regular, design: .default))
                        .foregroundColor(bgColor)
                        .lineLimit(1)
                        .fixedSize()

                    VStack(alignment: .center, spacing: -3) {
                        Text(reading.direction)
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .foregroundColor(.white)

                        if !reading.deltaText(units: config.units).isEmpty {
                            Text(reading.deltaText(units: config.units))
                                .font(.system(size: 20, weight: .medium, design: .default))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .offset(y: -2)
                        }
                    }
                    .fixedSize()

                    Spacer()

                    // Loop success indicator
                    Button {
                        showLoopDetail = true
                    } label: {
                        Image(systemName: loopStatusIcon)
                            .font(.system(size: 27, weight: .medium))
                            .foregroundColor(loopStatusColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    .sheet(isPresented: $showLoopDetail) {
                        FollowStatusView(bgFetcher: bgFetcher, sessionManager: sessionManager)
                    }

                    // Reload button
                    Button {
                        timeOffset = zoomHours * 3.6
                        bgFetcher.reload()
                    } label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.top, 30)

                // Row 2: Gray bar — IOB (left), COB (center), Basal (right)
                HStack(spacing: 0) {
                    if let status = displayStatus {
                        let dataColor: Color = isTimeTravel && !bgFetcher.statusMatchesScroll ? .gray : .white
                        if let iob = status.iob {
                            Text(String(format: "%.1fU", iob))
                                .foregroundColor(dataColor)
                        }
                        Spacer()
                        if let cob = status.cob {
                            Text(String(format: "%.0fg", cob))
                                .foregroundColor(dataColor)
                        }
                        Spacer()
                        if let currentBasal = status.basalRate {
                            let scheduled = bgFetcher.scheduledBasal ?? currentBasal
                            Text(String(format: "%.1f\u{2192}%.1fU/h", scheduled, currentBasal))
                                .foregroundColor(dataColor)
                        }
                    }
                }
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    bgBarGradient(bgHistory: bgFetcher.bgHistory)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white, location: 0.06),
                                    .init(color: .white, location: 0.94),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.3), location: 0),
                                    .init(color: .white, location: 0.45),
                                    .init(color: .white, location: 0.55),
                                    .init(color: .white.opacity(0.3), location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )

                // Spacer so chart y-axis "300" label doesn't overlap gray bar
                Spacer().frame(height: 6)

                // Row 3: Chart — takes all remaining space
                BGChartView(
                    bgHistory: bgFetcher.bgHistory,
                    loopStatus: bgFetcher.loopStatus,
                    treatments: bgFetcher.treatments,
                    tempTargetEntries: bgFetcher.tempTargetEntries,
                    overrideEntries: bgFetcher.overrideEntries,
                    config: config,
                    timeOffset: $timeOffset,
                    zoomHours: $zoomHours
                )
                .frame(maxHeight: .infinity)

                // Row 4: Status + source combined in one row
                HStack(spacing: 4) {
                    Circle()
                        .fill(bgFetcher.lastError == nil ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(freshnessText(reading: reading))
                        .foregroundColor(isTimeTravel ? .blue : .white)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(bgFetcher.activeSource.isEmpty ? "---" : bgFetcher.activeSource)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13))
                .lineLimit(1)

                // Footer: Override and/or Temp Target (only when active)
                if let status = displayStatus {
                    if status.overrideActive, let text = status.overrideText {
                        Text("Override: \(text)")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }
                    if status.tempTargetActive, let text = status.tempTargetText {
                        Text("Temp Target: \(text)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.bottom, 10)
            .opacity(stale ? 0.6 : 1.0)

            // Reload overlay
            if bgFetcher.isReloading {
                reloadOverlay(success: false)
            } else if showReloadCheck {
                reloadOverlay(success: true)
            }
        }
        .onChange(of: bgFetcher.isReloading) { newValue in
            if !newValue {
                showReloadCheck = true
                WKInterfaceDevice.current().play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showReloadCheck = false
                }
            }
        }
    }

    private var displayStatus: LoopStatus? {
        bgFetcher.loopStatus
    }

    /// Whether Trio looped successfully on the most recent BG reading.
    /// Compares loop status timestamp to latest BG — if within 6 minutes, it looped.
    private var loopedOnLatestReading: Bool {
        guard let loopTime = bgFetcher.loopStatus?.timestamp,
              let bgTime = bgFetcher.currentBG?.timestamp else { return false }
        return abs(loopTime.timeIntervalSince(bgTime)) < 360
    }

    private var loopStatusIcon: String {
        loopedOnLatestReading ? "circle.circle.fill" : "circle.dashed"
    }

    private var loopStatusColor: Color {
        guard bgFetcher.loopStatus != nil else { return .gray }
        return loopedOnLatestReading ? .green : .orange
    }

    @ViewBuilder
    private func reloadOverlay(success: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .cornerRadius(16)
                .frame(width: 80, height: 80)

            if success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    private func freshnessText(reading: BGReading) -> String {
        // When not showing the latest reading, display the clock time
        if let latest = bgFetcher.currentBG,
           reading.timestamp != latest.timestamp
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: reading.timestamp)
        }
        // At current reading: live countdown
        let totalSeconds = Int(now.timeIntervalSince(reading.timestamp))
        if totalSeconds < 5 { return "now" }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)m \(seconds)s"
    }
}
