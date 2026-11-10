// LoopFollow
// CarPlayWidgetPublisher.swift

#if !targetEnvironment(macCatalyst)

    import Foundation
    import UIKit
    import WidgetKit

    /// Writes the CarPlay widget's state and asks WidgetKit to redraw it, only
    /// when something it shows has changed: redraws are rationed.
    enum CarPlayWidgetPublisher {
        private static var lastPublished: Data?
        private static var lastState: CarPlayWidgetState?

        /// Changes this close together share one widget push, since each
        /// push spends part of the widget's daily allowance.
        static let pushDelay: TimeInterval = 10

        private static var pendingPush: DispatchWorkItem?
        private static var pushAssertion: UIBackgroundTaskIdentifier = .invalid

        /// After each alarm check: the reading, the 3 h history and the alerts.
        static func publish(alarmData: AlarmData, readings: [ShareGlucoseData], now: Date = Date()) {
            let unit = PreferredGlucoseUnit.snapshotUnit()
            let alerts = AlarmManager.shared.carPlayAlarms(data: alarmData, now: now).map {
                CarPlayAlert(alarm: $0.alarm, title: $0.title, data: alarmData, unit: unit)
            }
            write(CarPlayWidgetState(
                snapshot: GlucoseSnapshotBuilder.build(from: StorageCurrentGlucoseStateProvider()),
                history: history(from: readings, now: now),
                alerts: alerts
            ), reason: "alarm check")
        }

        /// After each Live Activity refresh, so the widget's reading, IOB,
        /// COB and override change when the Live Activity's do. The history
        /// and alerts stay as the last alarm check left them.
        static func publish(snapshot: GlucoseSnapshot) {
            guard let previous = lastState ?? CarPlayWidgetStore.load() else { return }
            var state = previous
            state.snapshot = snapshot
            write(state, reason: "live activity")
        }

        private static func write(_ state: CarPlayWidgetState, reason: String) {
            guard let data = CarPlayWidgetStore.encode(state), data != lastPublished else { return }
            CarPlayWidgetStore.save(data)
            lastPublished = data
            lastState = state

            // The widget notes when it last built a timeline. If that stays
            // older than the previous request, the system is holding reloads back.
            let built = CarPlayWidgetStore.timelineBuiltAt.map { "\(Int(Date().timeIntervalSince($0)))s ago" } ?? "never"
            LogManager.shared.log(
                category: .carPlay,
                message: "Widget reload requested (\(reason)); last timeline built \(built)",
                isDebug: true
            )
            WidgetCenter.shared.reloadTimelines(ofKind: CarPlayWidgetStore.kind)
            schedulePush()
        }

        /// In the background the system holds reload requests back, so a
        /// widget push follows the request there. In the foreground the
        /// request is enough.
        private static func schedulePush() {
            guard #available(iOS 26.0, *) else { return }
            DispatchQueue.main.async {
                guard UIApplication.shared.applicationState != .active else { return }
                pendingPush?.cancel()
                if pushAssertion == .invalid {
                    // Keeps the app running until the delayed push has gone.
                    pushAssertion = UIApplication.shared.beginBackgroundTask(withName: "CarPlay widget push") {
                        endPushAssertion()
                    }
                }
                let work = DispatchWorkItem {
                    pendingPush = nil
                    Task { @MainActor in
                        await sendPush()
                        if pendingPush == nil { endPushAssertion() }
                    }
                }
                pendingPush = work
                DispatchQueue.main.asyncAfter(deadline: .now() + pushDelay, execute: work)
            }
        }

        @available(iOS 26.0, *)
        private static func sendPush() async {
            // WidgetKit's current token, else the one the widget last stored.
            let info = await WidgetCenter.shared.currentPushInfo
            guard let token = info.map({ CarPlayWidgetStore.hex($0.token) }) ?? CarPlayWidgetStore.pushToken else {
                LogManager.shared.log(category: .carPlay, message: "Widget push skipped: no push token yet", isDebug: true)
                return
            }
            if await APNSClient.shared.sendWidgetUpdate(pushToken: token) == .tokenInvalid {
                CarPlayWidgetStore.pushToken = nil
            }
        }

        private static func endPushAssertion() {
            guard pushAssertion != .invalid else { return }
            UIApplication.shared.endBackgroundTask(pushAssertion)
            pushAssertion = .invalid
        }

        /// Readings inside the 3 h page's window, oldest first.
        static func history(from readings: [ShareGlucoseData], now: Date) -> [GlucosePoint] {
            let start = now.timeIntervalSince1970 - CarPlayWidgetState.historyWindow
            return readings
                .filter { $0.sgv > 0 && $0.date >= start }
                .sorted { $0.date < $1.date }
                .map { GlucosePoint(date: Date(timeIntervalSince1970: $0.date), mgdl: Double($0.sgv)) }
        }
    }

#endif

extension CarPlayAlert {
    /// A triggered alarm, worded for the widget with the icon LoopFollow uses
    /// for its type.
    init(alarm: Alarm, title: String, data: AlarmData, unit: GlucoseSnapshot.Unit) {
        self.init(
            id: alarm.id,
            title: title,
            detail: Self.detail(for: alarm, data: data, unit: unit),
            symbol: alarm.type.icon,
            isUrgent: Self.isUrgent(alarm.type)
        )
    }

    /// Red rather than orange: the alarms about glucose or the loop that
    /// need attention now.
    static func isUrgent(_ type: AlarmType) -> Bool {
        switch type {
        case .low, .fastDrop, .missedReading, .notLooping, .temporary:
            true
        default:
            false
        }
    }

    /// The value behind the alarm. Missed reading and not looping use the
    /// alarm notification's own text when the CGM reported a state.
    static func detail(for alarm: Alarm, data: AlarmData, unit: GlucoseSnapshot.Unit) -> String? {
        if let body = alarm.notificationBody {
            return body
        }

        switch alarm.type {
        case .low, .high, .fastDrop, .fastRise, .temporary:
            guard let sgv = data.bgReadings.last?.sgv, sgv > 0 else { return nil }
            return glucose(Double(sgv), unit: unit)
        case .missedReading:
            return data.bgReadings.last.map { "Last reading \(GlucoseSnapshot.clock($0.date))" }
        case .notLooping:
            guard let loop = data.lastLoopTime, loop > 0 else { return nil }
            return "Last loop \(GlucoseSnapshot.clock(Date(timeIntervalSince1970: loop)))"
        case .sensorChange:
            guard let inserted = data.sageInsertTime, inserted > 0 else { return nil }
            let lifetime = Double(alarm.sensorLifetimeDays ?? 10) * 86400
            return "Expires \(GlucoseSnapshot.clock(Date(timeIntervalSince1970: inserted + lifetime)))"
        case .pumpChange:
            // The same 3-day site life the pump change alarm uses.
            guard let inserted = data.pumpInsertTime, inserted > 0 else { return nil }
            return "Expires \(GlucoseSnapshot.clock(Date(timeIntervalSince1970: inserted + 3 * 86400)))"
        case .pump:
            return data.latestPumpVolume.map { "\(Int($0.rounded())) U left" }
        case .pumpBattery:
            return data.latestPumpBattery.map { "\(Int($0.rounded()))%" }
        case .battery, .batteryDrop:
            return data.latestBattery.map { "\(Int($0.rounded()))%" }
        case .iob:
            return data.IOB.map { "\($0.formatted(.number.precision(.fractionLength(1)))) U" }
        case .cob:
            return data.COB.map { "\(Int($0.rounded())) g" }
        case .recBolus:
            return data.recBolus.map { "\($0.formatted(.number.precision(.fractionLength(2)))) U" }
        case .buildExpire:
            return data.expireDate.map { "Expires \($0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))" }
        case .dbSize:
            return data.dbSizePercentage.map { "\(Int($0.rounded()))% full" }
        case .missedBolus, .futureCarbs, .overrideStart, .overrideEnd, .tempTargetStart, .tempTargetEnd:
            return nil
        }
    }

    private static func glucose(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            "\(Int(mgdl.rounded())) mg/dL"
        case .mmol:
            "\(GlucoseConversion.toMmol(mgdl).formatted(.number.precision(.fractionLength(1)))) mmol/L"
        }
    }
}
