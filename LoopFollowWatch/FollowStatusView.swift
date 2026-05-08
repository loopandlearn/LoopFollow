// LoopFollow
// FollowStatusView.swift
//
// Full-screen sheet shown when the user taps the loop-status icon. Two tabs:
// "Device Status" mirrors the iPhone "Follow Status" view (LOOP / OVERRIDE /
// REASON / PUMP / SITE / TODAY / UPDATED), and "Profile" lists the active
// profile schedules. All data is sourced from BGFetcher state already
// downloaded for the main view — no new fetches.

import SwiftUI

struct FollowStatusView: View {
    @ObservedObject var bgFetcher: BGFetcher
    @ObservedObject var sessionManager: WatchSessionManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 4) {
            header
            tabSelector

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if selectedTab == 0 {
                        DeviceStatusTab(bgFetcher: bgFetcher, sessionManager: sessionManager)
                    } else {
                        ProfileTab(bgFetcher: bgFetcher, sessionManager: sessionManager)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }
            .id(selectedTab)
        }
    }

    /// Two-button segmented selector — watchOS doesn't support `.segmented`
    /// Picker style, so we render this ourselves.
    private var tabSelector: some View {
        HStack(spacing: 4) {
            tabButton(title: "Device", tag: 0)
            tabButton(title: "Profile", tag: 1)
        }
        .padding(.horizontal, 6)
    }

    private func tabButton(title: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedTab == tag ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(selectedTab == tag ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(bgFetcher.lastError == nil ? Color.green : Color.red)
                .frame(width: 5, height: 5)
            Text(bgFetcher.activeSource.isEmpty ? "—" : bgFetcher.activeSource)
                .foregroundColor(.secondary)
            if let ts = bgFetcher.loopStatus?.timestamp {
                Text("·")
                    .foregroundColor(.secondary)
                Text(FollowStatusFormat.relative(ts))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
}

// MARK: - Device Status tab

private struct DeviceStatusTab: View {
    @ObservedObject var bgFetcher: BGFetcher
    @ObservedObject var sessionManager: WatchSessionManager

    private var units: String {
        sessionManager.config?.units ?? "mg/dL"
    }

    var body: some View {
        updatedSection
        loopSection
        overrideSection
        devicesSection
        todaySection
        reasonSection
    }

    private var loopSection: some View {
        let s = bgFetcher.loopStatus
        let target = s?.currentTarget ?? bgFetcher.lookupScheduleValue(bgFetcher.targetSchedule)
        // Loop: direct recommendedBolus from devicestatus.
        // OpenAPS: bgFetcher computes one in updateRecommendedBolus().
        let recBolus: Double? = s?.recommendedBolus
            ?? (bgFetcher.recommendedBolus > 0 ? bgFetcher.recommendedBolus : nil)

        return VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Loop")
            Group {
                StatusRow("IOB", FollowStatusFormat.units(s?.iob, decimals: 2, suffix: " U"))
                StatusRow("COB", FollowStatusFormat.units(s?.cob, decimals: 0, suffix: " g"))
                // Prefer the temp-basal treatment's `absolute` (what the pump
                // actually delivered, matching the iPhone Follow display) over
                // devicestatus.enacted.rate (the algorithm's request, which can
                // round differently).
                StatusRow("Basal", FollowStatusFormat.currentVsScheduled(
                    current: bgFetcher.currentTempBasal ?? s?.basalRate,
                    scheduled: bgFetcher.scheduledBasal,
                    valueFormatter: { String(format: "%.2f", $0) },
                    suffix: " U/hr"
                ))
                if s?.isOpenAPS == true {
                    StatusRow("ISF", FollowStatusFormat.currentVsScheduled(
                        current: s?.isf,
                        scheduled: bgFetcher.lookupScheduleValue(bgFetcher.isfSchedule),
                        valueFormatter: { FollowStatusFormat.bgLike($0, units: units) ?? "—" }
                    ))
                    StatusRow("CR", FollowStatusFormat.currentVsScheduled(
                        current: s?.carbRatio,
                        scheduled: bgFetcher.lookupScheduleValue(bgFetcher.carbRatioSchedule),
                        valueFormatter: { String(format: "%.1f", $0) },
                        suffix: " g/U"
                    ))
                }
            }
            Group {
                StatusRow("Target", FollowStatusFormat.bgLike(target, units: units, withUnits: true))
                if s?.isOpenAPS == true {
                    StatusRow("Eventual BG", FollowStatusFormat.bgLike(s?.eventualBG, units: units, withUnits: true))
                    if let mn = s?.minPredBG, let mx = s?.maxPredBG {
                        StatusRow("Min/Max", "\(FollowStatusFormat.bgLike(mn, units: units) ?? "—")/\(FollowStatusFormat.bgLike(mx, units: units) ?? "—")")
                    }
                    if let auto = s?.autosensRatio {
                        StatusRow("Autosens", String(format: "%.0f%%", auto * 100))
                    }
                }
                if recBolus != nil {
                    StatusRow("Rec. Bolus", FollowStatusFormat.units(recBolus, decimals: 2, suffix: " U"))
                }
                if s?.isOpenAPS == true, let req = s?.insulinReq {
                    StatusRow("Req. Insulin", String(format: "%.2f U", req))
                }
            }
        }
    }

    @ViewBuilder
    private var overrideSection: some View {
        let s = bgFetcher.loopStatus
        if (s?.overrideActive == true && s?.overrideText != nil)
            || (s?.tempTargetActive == true && s?.tempTargetText != nil) {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader("Override")
                if let oText = s?.overrideText, s?.overrideActive == true {
                    StatusRow("Override", oText)
                }
                if let tText = s?.tempTargetText, s?.tempTargetActive == true {
                    StatusRow("Temp Target", tText)
                }
            }
        }
    }

    @ViewBuilder
    private var reasonSection: some View {
        if let reason = bgFetcher.loopStatus?.reason, !reason.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader("Reason")
                Text(FollowStatusFormat.formatReason(reason))
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var devicesSection: some View {
        let hasAny = bgFetcher.pumpBattery != nil
            || bgFetcher.uploaderBattery != nil
            || bgFetcher.cannulaChangeDate != nil
            || bgFetcher.sensorChangeDate != nil
            || bgFetcher.insulinChangeDate != nil
            || bgFetcher.pumpReservoir != nil
        if hasAny {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader("Devices")
                if let pb = bgFetcher.pumpBattery {
                    StatusRow("Pump Battery", "\(pb)%")
                }
                if let tb = bgFetcher.uploaderBattery {
                    StatusRow("Trio Battery", "\(tb)%")
                }
                if let d = bgFetcher.cannulaChangeDate {
                    StatusRow("Cannula (CAGE)", FollowStatusFormat.age(d))
                }
                if let d = bgFetcher.sensorChangeDate {
                    StatusRow("Sensor (SAGE)", FollowStatusFormat.age(d))
                }
                if let d = bgFetcher.insulinChangeDate {
                    StatusRow("Insulin (IAGE)", FollowStatusFormat.age(d))
                }
                if let reservoir = bgFetcher.pumpReservoir {
                    StatusRow("Reservoir", String(format: "%.0f U", reservoir))
                }
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        let tdd = bgFetcher.loopStatus?.tdd
        if bgFetcher.carbsToday != nil || tdd != nil {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader("Today")
                if let carbs = bgFetcher.carbsToday {
                    StatusRow("Carbs", String(format: "%.0f g", carbs))
                }
                if let tdd = tdd {
                    StatusRow("TDD", String(format: "%.1f U", tdd))
                }
            }
        }
    }

    private var updatedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Updated")
            if let ts = bgFetcher.loopStatus?.timestamp {
                StatusRow("Last loop", "\(FollowStatusFormat.clock(ts)) (\(FollowStatusFormat.relative(ts)))")
            }
            StatusRow("Source", bgFetcher.activeSource.isEmpty ? "—" : bgFetcher.activeSource)
        }
    }
}

// MARK: - Profile tab

private struct ProfileTab: View {
    @ObservedObject var bgFetcher: BGFetcher
    @ObservedObject var sessionManager: WatchSessionManager

    private var units: String {
        sessionManager.config?.units ?? "mg/dL"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            scheduleSection(title: "Basal Rates", schedule: bgFetcher.basalSchedule) { value in
                String(format: "%.2f U/hr", value)
            }
            scheduleSection(title: "ISF", schedule: bgFetcher.isfSchedule) { value in
                FollowStatusFormat.bgLike(value, units: units) ?? "—"
            }
            scheduleSection(title: "Carb Ratios", schedule: bgFetcher.carbRatioSchedule) { value in
                String(format: "%.1f g/U", value)
            }
            scheduleSection(title: "Targets", schedule: bgFetcher.targetSchedule) { value in
                FollowStatusFormat.bgLike(value, units: units, withUnits: true) ?? "—"
            }
        }
    }

    @ViewBuilder
    private func scheduleSection(
        title: String,
        schedule: [(timeAsSeconds: Double, value: Double)],
        formatter: @escaping (Double) -> String
    ) -> some View {
        if !schedule.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title)
                ForEach(schedule.indices, id: \.self) { i in
                    let entry = schedule[i]
                    StatusRow(
                        FollowStatusFormat.timeOfDay(entry.timeAsSeconds, timezone: bgFetcher.profileTimezone),
                        formatter(entry.value)
                    )
                }
            }
        }
    }
}

// MARK: - Row primitives

private struct StatusRow: View {
    let label: String
    let value: String?

    init(_ label: String, _ value: String?) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer(minLength: 4)
            Text(value ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5)
        }
        .padding(.top, 6)
    }
}

// MARK: - Formatters

private enum FollowStatusFormat {
    /// "1.47 U" / "27.5 U" / "—" if value is nil.
    static func units(_ value: Double?, decimals: Int, suffix: String) -> String? {
        guard let value = value else { return nil }
        return String(format: "%.\(decimals)f%@", value, suffix)
    }

    /// Break an OpenAPS/Trio "reason" blob onto multiple lines so each piece
    /// of data is readable on the watch. The reason text uses a mix of `,`,
    /// `;`, and `.` to separate phrases — split on any of those when followed
    /// by whitespace (or end-of-string), which preserves numeric periods like
    /// "0.13U" while breaking phrases like "Eventual BG 117 >= 99 ; Insulin
    /// req 0.13U" into two lines.
    static func formatReason(_ reason: String) -> String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let pattern = "\\s*[,;.](?:\\s+|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return trimmed }
        let ns = trimmed as NSString
        let normalized = regex.stringByReplacingMatches(
            in: trimmed,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "\n"
        )
        return normalized
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Merge a "currently enacted" value with its scheduled counterpart into a
    /// single row string. When they're equal (or one side is missing) just the
    /// available value is shown; when they differ, "scheduled → current".
    /// `suffix` is appended once at the end so we don't repeat units like
    /// "1.10 U/hr → 0.95 U/hr".
    static func currentVsScheduled(
        current: Double?,
        scheduled: Double?,
        valueFormatter: (Double) -> String,
        suffix: String = ""
    ) -> String? {
        let c = current.map(valueFormatter)
        let s = scheduled.map(valueFormatter)
        if let c = c, let s = s {
            return c == s ? "\(c)\(suffix)" : "\(s) \u{2192} \(c)\(suffix)"
        }
        if let c = c { return "\(c)\(suffix)" }
        if let s = s { return "\(s)\(suffix)" }
        return nil
    }

    /// Format a BG-like value (target / eventual / ISF) respecting the user's units.
    /// OpenAPS may emit values in either mg/dL or mmol/L; we auto-detect by magnitude.
    static func bgLike(_ value: Double?, units: String, withUnits: Bool = false) -> String? {
        guard let value = value else { return nil }
        if units == "mmol/L" {
            // If the value already looks like mmol/L (small), keep it. Otherwise convert.
            let mmol = value < 40 ? value : value / 18.0182
            return String(format: withUnits ? "%.1f mmol/L" : "%.1f", mmol)
        }
        // mg/dL: if value looks like mmol/L (small), convert up.
        let mgdl = value < 40 ? value * 18.0182 : value
        return String(format: withUnits ? "%.0f mg/dL" : "%.0f", mgdl.rounded())
    }

    /// "9:41 PM"
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// "now" / "1m" / "12m"
    static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 30 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    /// "1d 14h" / "9h 32m"
    static func age(_ date: Date) -> String {
        let total = Int(Date().timeIntervalSince(date))
        guard total > 0 else { return "—" }
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Render a profile-schedule timeAsSeconds (seconds since local midnight)
    /// in the profile's timezone — "12:00 AM", "2:00 AM" …
    static func timeOfDay(_ secondsFromMidnight: Double, timezone: TimeZone) -> String {
        let hour = Int(secondsFromMidnight) / 3600
        let minute = (Int(secondsFromMidnight) % 3600) / 60
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.timeZone = timezone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}
