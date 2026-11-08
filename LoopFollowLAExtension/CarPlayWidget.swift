// LoopFollow
// CarPlayWidget.swift

import AppIntents
import Charts
import SwiftUI
import WidgetKit

/// A small widget for the CarPlay Widgets screen, also usable on the Home
/// Screen. One page at a time; the button in the corner steps through them.
/// iOS 26 and later, which brought widgets to CarPlay and lets the app wake
/// the widget with a push while it runs in the background.
@available(iOS 26.0, *)
struct CarPlayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CarPlayWidgetStore.kind, provider: CarPlayWidgetProvider()) { entry in
            CarPlayWidgetView(entry: entry)
        }
        .configurationDisplayName("LoopFollow")
        .description("Glucose with any override, alerts when there are any, and the last 3 hours.")
        .supportedFamilies([.systemSmall])
        .pushHandler(CarPlayWidgetPushHandler.self)
    }
}

/// Leaves the widget's push token in the App Group. The app sends a widget
/// push to it after a change, since the system holds back the reloads an app
/// asks for while it runs in the background.
@available(iOS 26.0, *)
struct CarPlayWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets _: [WidgetInfo]) {
        CarPlayWidgetStore.pushToken = CarPlayWidgetStore.hex(pushInfo.token)
    }
}

/// Moves the widget to its next page. Runs in the widget extension; WidgetKit
/// redraws the widget as soon as it returns.
struct NextCarPlayWidgetPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Widget Page"
    static var description = IntentDescription("Shows the next page of the LoopFollow widget.")
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        let hasAlerts = CarPlayWidgetStore.load()?.hasAlerts ?? false
        CarPlayWidgetStore.page = CarPlayWidgetStore.page.next(hasAlerts: hasAlerts)
        return .result()
    }
}

// MARK: - Timeline

struct CarPlayWidgetEntry: TimelineEntry {
    let date: Date
    let state: CarPlayWidgetState?
    let page: CarPlayWidgetPage
}

struct CarPlayWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> CarPlayWidgetEntry {
        CarPlayWidgetEntry(date: Date(), state: nil, page: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping (CarPlayWidgetEntry) -> Void) {
        completion(CarPlayWidgetEntry(date: Date(), state: CarPlayWidgetStore.load(), page: CarPlayWidgetStore.page))
    }

    /// The app asks for a reload whenever the data changes. In between, one
    /// entry a minute for half an hour, then every five minutes to the hour,
    /// brings in the stale cue on time, ends an override when it ends and
    /// moves the 3 h chart along, including when the app has stopped updating.
    /// The text itself holds clock times, so nothing ticks while driving.
    func getTimeline(in _: Context, completion: @escaping (Timeline<CarPlayWidgetEntry>) -> Void) {
        let now = Date()
        CarPlayWidgetStore.timelineBuiltAt = now
        let state = CarPlayWidgetStore.load()
        let page = CarPlayWidgetStore.page
        let minutes = Array(0 ..< 30) + Array(stride(from: 30, through: 60, by: 5))
        let entries = minutes.map {
            CarPlayWidgetEntry(date: now.addingTimeInterval(Double($0) * 60), state: state, page: page)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct CarPlayWidgetView: View {
    let entry: CarPlayWidgetEntry

    var body: some View {
        let alerts = entry.state?.alerts ?? []
        let page = entry.page.resolved(hasAlerts: !alerts.isEmpty)

        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let state = entry.state, let snapshot = state.snapshot {
                    switch page {
                    case .now:
                        CarPlayNowPage(snapshot: snapshot, date: entry.date, hasAlerts: !alerts.isEmpty)
                    case .alerts:
                        CarPlayAlertsPage(alerts: alerts)
                    case .trend:
                        CarPlayTrendPage(snapshot: snapshot, history: state.history, date: entry.date)
                    }
                } else {
                    CarPlayNoDataPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .invalidatableContent()

            CarPlayWidgetFooter(page: page, hasAlerts: !alerts.isEmpty)
        }
        .foregroundStyle(.white)
        .containerBackground(Color(white: 0.17), for: .widget)
    }
}

/// The reading, trend, delta and reading time, any running override, then
/// projected BG, IOB, COB and basal with the same icons as the tight CarPlay
/// layout. A yellow warning sign by the reading means there are alerts.
private struct CarPlayNowPage: View {
    let snapshot: GlucoseSnapshot
    let date: Date
    let hasAlerts: Bool

    var body: some View {
        let isStale = snapshot.isStale(at: date)
        let color = isStale ? Color.white.opacity(0.55) : LAColors.keyline(for: snapshot)

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Group {
                    Text(LAFormat.glucose(snapshot))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .strikethrough(isStale, pattern: .solid, color: .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(LAFormat.trendArrow(snapshot))
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(color)

                Spacer(minLength: 2)

                if hasAlerts {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Alerts on the next page")
                }
            }

            Text("\(LAFormat.delta(snapshot)) \(snapshot.unit.displayName) · \(GlucoseSnapshot.clock(snapshot.updatedAt, now: date))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isStale ? Color.red : Color.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if snapshot.hasActiveOverride(at: date) {
                CarPlayOverrideLine(details: snapshot.carPlayOverrideDetails(now: date))
            }

            Spacer(minLength: 4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    metric(LAFormat.projected(snapshot), label: "Projected glucose") { Image(systemName: "target") }
                    metric(LAFormat.cob(snapshot), label: "Carbs on board") { Image(systemName: "fork.knife") }
                }
                Spacer(minLength: 4)
                VStack(alignment: .leading, spacing: 4) {
                    metric(LAFormat.iob(snapshot), label: "Insulin on board") { Image(systemName: "syringe") }
                    metric(LAFormat.activeBasal(snapshot), label: "Basal rate") {
                        BasalStepIcon()
                            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: 13, height: 9)
                    }
                }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }

    private func metric(_ value: String, label: String, @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 4) {
            icon()
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 15)
                .accessibilityHidden(true)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel("\(label) \(value)")
        }
    }
}

/// "105% · 5.0–5.6 · 14:20": the override's insulin needs, target range and
/// end time, or ∞ when it has none.
private struct CarPlayOverrideLine: View {
    let details: [String]

    var body: some View {
        Text("\(Image(systemName: "slider.horizontal.3")) \(details.joined(separator: " · "))")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.green)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(
                (["Override"] + details.map { $0 == "∞" ? "no end time" : $0 }).joined(separator: ", ")
            )
    }
}

/// The last three hours against the target range, with the reading in the corner.
private struct CarPlayTrendPage: View {
    let snapshot: GlucoseSnapshot
    let history: [GlucosePoint]
    let date: Date

    var body: some View {
        let thresholds = LAAppGroupSettings.thresholdsMgdl()
        let low = display(thresholds.low)
        let high = display(thresholds.high)
        let values = history.map { display($0.mgdl) }
        let yMin = min(values.min() ?? low, low) * 0.9
        let yMax = max(values.max() ?? high, high) * 1.05
        let start = date.addingTimeInterval(-CarPlayWidgetState.historyWindow)
        let isStale = snapshot.isStale(at: date)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 3 h")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("\(LAFormat.glucose(snapshot)) \(LAFormat.trendArrow(snapshot))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .strikethrough(isStale, pattern: .solid, color: .red)
                    .foregroundStyle(isStale ? Color.white.opacity(0.55) : LAColors.keyline(for: snapshot))
            }

            Chart {
                RectangleMark(
                    xStart: .value("Start", start),
                    xEnd: .value("End", date),
                    yStart: .value("Low", low),
                    yEnd: .value("High", high)
                )
                .foregroundStyle(Color.green.opacity(0.18))

                ForEach(history, id: \.date) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", display(point.mgdl))
                    )
                    .symbolSize(10)
                    .foregroundStyle(color(for: point.mgdl, low: thresholds.low, high: thresholds.high))
                }
            }
            .chartXScale(domain: start ... date)
            .chartYScale(domain: yMin ... yMax)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .accessibilityLabel("Glucose over the last 3 hours")

            Text("Range \(format(low))–\(format(high))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func display(_ mgdl: Double) -> Double {
        snapshot.unit == .mmol ? GlucoseConversion.toMmol(mgdl) : mgdl
    }

    private func format(_ value: Double) -> String {
        snapshot.unit == .mmol
            ? value.formatted(.number.precision(.fractionLength(1)))
            : "\(Int(value.rounded()))"
    }

    private func color(for mgdl: Double, low: Double, high: Double) -> Color {
        if mgdl <= low { return .red }
        if mgdl >= high { return .orange }
        return .green
    }
}

/// The triggered alarms marked for CarPlay, most important first. Only in
/// the cycle while there are any.
private struct CarPlayAlertsPage: View {
    let alerts: [CarPlayAlert]

    var body: some View {
        // Three rows fit; with more, two and a count of the rest.
        let shown = alerts.count > 3 ? Array(alerts.prefix(2)) : alerts
        VStack(alignment: .leading, spacing: 6) {
            ForEach(shown) { alert in
                CarPlayAlertRow(alert: alert)
            }
            if alerts.count > shown.count {
                Text("+\(alerts.count - shown.count) more")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private struct CarPlayAlertRow: View {
    let alert: CarPlayAlert

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: alert.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(alert.isUrgent ? Color.red : Color.orange)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(alert.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let detail = alert.detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CarPlayNoDataPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No data yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("Open LoopFollow on your iPhone.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// The page name and dots, and the button to the next page, yellow when it
/// leads to Alerts.
private struct CarPlayWidgetFooter: View {
    let page: CarPlayWidgetPage
    let hasAlerts: Bool

    var body: some View {
        let leadsToAlerts = page.next(hasAlerts: hasAlerts) == .alerts

        HStack(spacing: 5) {
            Text(page.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 3) {
                ForEach(CarPlayWidgetPage.sequence(hasAlerts: hasAlerts), id: \.self) { item in
                    Circle()
                        .fill(item == page ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 5, height: 5)
                }
            }
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Button(intent: NextCarPlayWidgetPageIntent()) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(leadsToAlerts ? Color.black : Color.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(leadsToAlerts ? Color.yellow : Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(leadsToAlerts ? "Show alerts" : "Next page")
        }
    }
}
