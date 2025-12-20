// LoopFollow
// SnoozerView.swift

import SwiftUI

struct SnoozerView: View {
    @StateObject private var vm = SnoozerViewModel()

    @ObservedObject var showDisplayName = Storage.shared.showDisplayName
    @ObservedObject var minAgoText = Observable.shared.minAgoText
    @ObservedObject var bgText = Observable.shared.bgText
    @ObservedObject var bgTextColor = Observable.shared.bgTextColor
    @ObservedObject var directionText = Observable.shared.directionText
    @ObservedObject var deltaText = Observable.shared.deltaText
    @ObservedObject var bgStale = Observable.shared.bgStale
    @ObservedObject var bg = Observable.shared.bg
    @ObservedObject var snoozerEmoji = Storage.shared.snoozerEmoji

    @ObservedObject private var cfgStore = Storage.shared.alarmConfiguration

    // Snoozer Bar state
    @State private var showSnoozerBar: Bool = false
    @State private var showDatePickerDate: Bool = false
    @State private var showDatePickerTime: Bool = false
    @State private var autoHideTask: DispatchWorkItem? = nil
    @State private var lastActiveState: Bool = false

    private var isGlobalSnoozeActive: Bool {
        if let until = cfgStore.value.snoozeUntil { return until > Date() }
        return false
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let barShowing = showSnoozerBar || isGlobalSnoozeActive
            let landscapeScale: CGFloat = 0.8

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLandscape {
                        HStack(spacing: 0) {
                            leftColumn(isLandscape: true, barShowing: barShowing)
                            rightColumn(isLandscape: true)
                        }
                    } else {
                        VStack(spacing: 0) {
                            leftColumn(isLandscape: false, barShowing: barShowing)
                            rightColumn(isLandscape: false)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { presentSnoozerBar() }
                .onAppear {
                    presentSnoozerBar()
                    lastActiveState = isGlobalSnoozeActive
                }
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    let active = isGlobalSnoozeActive
                    if lastActiveState != active {
                        lastActiveState = active
                        if active {
                            showSnoozerBar = true
                            cancelAutoHide()
                        } else {
                            scheduleAutoHide()
                        }
                    }
                }
                .onReceive(vm.$activeAlarm) { alarm in
                    if alarm != nil {
                        showSnoozerBar = true
                        cancelAutoHide()
                    } else {
                        // When alarm is dismissed, schedule auto-hide if no global snooze is active
                        if !isGlobalSnoozeActive {
                            scheduleAutoHide()
                        }
                    }
                }
                .onChange(of: isGlobalSnoozeActive) { active in
                    if active {
                        showSnoozerBar = true
                        cancelAutoHide()
                    } else {
                        scheduleAutoHide()
                    }
                }
                .scaleEffect((isLandscape && barShowing) ? landscapeScale : 1.0, anchor: .top)
                .animation(.easeOut(duration: 0.18), value: barShowing)
            }
            .safeAreaInset(edge: .top) {
                if showSnoozerBar || isGlobalSnoozeActive {
                    snoozerBar(compact: isLandscape)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if let alarm = vm.activeAlarm {
                    VStack(spacing: 16) {
                        // Alarm name at the top
                        Text(alarm.name)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.top, 20)

                        Divider()

                        // Snooze duration controls
                        if alarm.type.snoozeTimeUnit != .none {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Snooze for")
                                        .font(.headline)
                                    Text("\(vm.snoozeUnits) \(vm.timeUnitLabel)")
                                        .font(.title3).bold()
                                }
                                Spacer()
                                Stepper("", value: $vm.snoozeUnits,
                                        in: alarm.type.snoozeRange,
                                        step: alarm.type.snoozeStep)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 24)
                        }

                        // Snooze button anchored to tab bar edge (bottom of VStack)
                        Button(action: vm.snoozeTapped) {
                            Text(vm.snoozeUnits == 0 ? "Acknowledge" : "Snooze")
                                .font(.system(size: 30, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: vm.activeAlarm != nil)
                    .padding(.bottom, 0) // Anchor directly to bottom edge
                }
            }
            .sheet(isPresented: $showDatePickerDate) { datePickerSheetDate() }
            .sheet(isPresented: $showDatePickerTime) { datePickerSheetTime() }
        }
    }

    // MARK: - Columns

    private func leftColumn(isLandscape: Bool, barShowing: Bool) -> some View {
        let topPad: CGFloat = barShowing ? 0 : 16
        let bigMaxH: CGFloat = barShowing ? (isLandscape ? 210 : 220) : 240
        let dirMaxH: CGFloat = barShowing ? (isLandscape ? 72 : 72) : 80
        let deltaMaxH: CGFloat = barShowing ? (isLandscape ? 60 : 60) : 68
        let ageMaxH: CGFloat = barShowing ? 36 : 40

        return VStack(spacing: 0) {
            if !isLandscape && showDisplayName.value {
                Text(Bundle.main.displayName)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(bgText.value)
                .font(.system(size: 300, weight: .black))
                .minimumScaleFactor(0.5)
                .foregroundColor(bgTextColor.value)
                .strikethrough(
                    bgStale.value,
                    pattern: .solid,
                    color: bgStale.value ? .red : .clear
                )
                .frame(maxWidth: .infinity, maxHeight: bigMaxH)

            if isLandscape {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text(directionText.value)
                        .font(.system(size: 90, weight: .black))
                    Text(deltaText.value)
                        .font(.system(size: 70))
                }
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: dirMaxH)
            } else {
                Text(directionText.value)
                    .font(.system(size: 110, weight: .black))
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: dirMaxH)

                Text(deltaText.value)
                    .font(.system(size: 70))
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: deltaMaxH)
            }

            Text(minAgoText.value)
                .font(.system(size: 60))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: ageMaxH)
        }
        .padding(.top, topPad)
        .padding(.horizontal, 16)
    }

    private func rightColumn(isLandscape: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            if showDisplayName.value && isLandscape {
                Text(Bundle.main.displayName)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 8)
            }

            if snoozerEmoji.value {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 4) {
                        Text(bgEmoji)
                            .font(.system(size: 128))
                            .minimumScaleFactor(0.5)

                        Text(context.date, format: Date.FormatStyle(date: .omitted, time: .shortened))
                            .font(.system(size: 70))
                            .minimumScaleFactor(0.5)
                            .foregroundColor(.white)
                            .frame(height: 78)
                    }
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 4) {
                        Text(context.date, format: Date.FormatStyle(date: .omitted, time: .shortened))
                            .font(.system(size: 70))
                            .minimumScaleFactor(0.5)
                            .foregroundColor(.white)
                            .frame(height: 78)
                    }
                }
            }
            Spacer()
        }
    }

    private var bgEmoji: String {
        guard let bg = bg.value, !bgStale.value else { return "🤷" }
        if Localizer.getPreferredUnit() == .millimolesPerLiter,
           Localizer.removePeriodAndCommaForBadge(bgText.value) == "55" { return "🦄" }
        if Localizer.getPreferredUnit() == .milligramsPerDeciliter, bg == 100 { return "🦄" }
        switch bg {
        case ..<40: return "❌"
        case ..<55: return "🥶"
        case ..<73: return "😱"
        case ..<98: return "😊"
        case ..<102: return "🥇"
        case ..<109: return "😎"
        case ..<127: return "🥳"
        case ..<145: return "🤔"
        case ..<163: return "😳"
        case ..<181: return "😵‍💫"
        case ..<199: return "🎃"
        case ..<217: return "🙀"
        case ..<235: return "🔥"
        case ..<253: return "😬"
        case ..<271: return "😡"
        case ..<289: return "🤬"
        case ..<307: return "🥵"
        case ..<325: return "🫣"
        case ..<343: return "😩"
        case ..<361: return "🤯"
        default: return "👿"
        }
    }

    // MARK: - Snoozer Bar

    private func snoozerBar(compact: Bool) -> some View {
        let active = isGlobalSnoozeActive
        let until = cfgStore.value.snoozeUntil
        let vPad: CGFloat = compact ? 6 : 10
        let controlH: CGFloat = compact ? 40 : 44
        let primaryH: CGFloat = compact ? 48 : 54
        let primaryMinW: CGFloat = compact ? 210 : 230

        return VStack(spacing: compact ? 6 : 10) {
            if active {
                if compact {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.red)

                        Text("All alerts snoozed")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .layoutPriority(1)

                        Spacer(minLength: 6)

                        Button(action: { showDatePickerDate = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                                Text((until ?? Date().addingTimeInterval(3600)).formatted(date: .abbreviated, time: .omitted))
                                    .font(.footnote)
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(action: { showDatePickerTime = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
                                Text((until ?? Date().addingTimeInterval(3600)).formatted(date: .omitted, time: .shortened))
                                    .font(.footnote)
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(action: { adjustSnooze(byMinutes: -30) }) {
                            Text("− 30m").bold()
                                .frame(minWidth: 76, minHeight: controlH)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(action: { adjustSnooze(byMinutes: +30) }) {
                            Text("+ 30m").bold()
                                .frame(minWidth: 76, minHeight: controlH)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(role: .destructive, action: { endSnooze() }) {
                            Text("End now").bold()
                                .frame(minWidth: 96, minHeight: controlH)
                                .background(Color.red.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Image(systemName: phaseIconName())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 2)
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("All alerts snoozed")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Button(action: { showDatePickerDate = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                                        Text((until ?? Date().addingTimeInterval(3600)).formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                }.buttonStyle(.plain)

                                Button(action: { showDatePickerTime = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
                                        Text((until ?? Date().addingTimeInterval(3600)).formatted(date: .omitted, time: .shortened))
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        Image(systemName: phaseIconName())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 12) {
                        Button(action: { adjustSnooze(byMinutes: -30) }) {
                            Text("− 30m").font(.title3).bold()
                                .frame(minWidth: 90, minHeight: 44)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(action: { adjustSnooze(byMinutes: +30) }) {
                            Text("+ 30m").font(.title3).bold()
                                .frame(minWidth: 90, minHeight: 44)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button(role: .destructive, action: { endSnooze() }) {
                            Text("End now").font(.title3).bold()
                                .frame(minWidth: 110, minHeight: 44)
                                .background(Color.red.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: { activateSnooze1h() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.slash")
                            Text("Snooze all · 1h").bold()
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .font(.title3)
                        .frame(minWidth: primaryMinW, minHeight: primaryH)
                        .padding(.horizontal, 6)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .shadow(radius: 3)
                    }.buttonStyle(.plain)

                    Spacer()

                    Image(systemName: phaseIconName())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, compact ? 6 : 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, vPad)
        .background(
            Color.white.opacity(0.08)
                .cornerRadius(18, corners: [.bottomLeft, .bottomRight])
        )
        .onTapGesture { resetAutoHide() }
    }

    // MARK: - Snoozer Bar helpers

    private func presentSnoozerBar() {
        showSnoozerBar = true
        if isGlobalSnoozeActive || vm.activeAlarm != nil {
            cancelAutoHide()
        } else {
            scheduleAutoHide()
        }
    }

    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        // Always schedule the task - it will check conditions when it executes
        // This ensures auto-hide works even if conditions change between scheduling and execution
        let task = DispatchWorkItem {
            // Only hide if neither global snooze nor active alarm exists
            if !self.isGlobalSnoozeActive && self.vm.activeAlarm == nil {
                withAnimation { self.showSnoozerBar = false }
            }
        }
        autoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }

    private func resetAutoHide() {
        if !isGlobalSnoozeActive, vm.activeAlarm == nil {
            scheduleAutoHide()
        } else {
            cancelAutoHide()
        }
    }

    private func activateSnooze1h() {
        if vm.activeAlarm != nil {
            vm.snoozeTapped()
        }

        cfgStore.value.snoozeUntil = Date().addingTimeInterval(3600)

        showSnoozerBar = true
        cancelAutoHide()
    }

    private func endSnooze() {
        cfgStore.value.snoozeUntil = nil
        if vm.activeAlarm == nil {
            scheduleAutoHide()
        } else {
            cancelAutoHide()
        }
    }

    private func adjustSnooze(byMinutes delta: Int) {
        guard let current = cfgStore.value.snoozeUntil else { return }
        let newDate = current.addingTimeInterval(TimeInterval(delta * 60))
        if newDate <= Date() { endSnooze() } else { cfgStore.value.snoozeUntil = newDate }
    }

    private func snoozeUntilBindingForDate() -> Binding<Date> {
        Binding<Date>(
            get: { cfgStore.value.snoozeUntil ?? Date().addingTimeInterval(3600) },
            set: { newDateOnly in
                let base = cfgStore.value.snoozeUntil ?? Date().addingTimeInterval(3600)
                let cal = Calendar.current
                let time = cal.dateComponents([.hour, .minute, .second], from: base)
                var comps = cal.dateComponents([.year, .month, .day], from: newDateOnly)
                comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
                cfgStore.value.snoozeUntil = cal.date(from: comps) ?? newDateOnly
            }
        )
    }

    private func snoozeUntilBindingForTime() -> Binding<Date> {
        Binding<Date>(
            get: { cfgStore.value.snoozeUntil ?? Date().addingTimeInterval(3600) },
            set: { newTimeOnly in
                let base = cfgStore.value.snoozeUntil ?? Date().addingTimeInterval(3600)
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: base)
                let time = cal.dateComponents([.hour, .minute, .second], from: newTimeOnly)
                comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
                cfgStore.value.snoozeUntil = cal.date(from: comps) ?? newTimeOnly
            }
        )
    }

    private func phaseIconName() -> String {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        func time(_ t: TimeOfDay) -> Date {
            var c = comps
            c.hour = t.hour
            c.minute = t.minute
            return cal.date(from: c) ?? now
        }
        let dayStart = time(cfgStore.value.dayStart)
        let nightStart = time(cfgStore.value.nightStart)

        let isNight: Bool
        if dayStart <= nightStart {
            if now >= nightStart { isNight = true }
            else if now >= dayStart { isNight = false } else { isNight = true }
        } else { // crosses midnight
            if now >= dayStart { isNight = false }
            else if now >= nightStart { isNight = true } else { isNight = false }
        }
        return isNight ? "moon.fill" : "sun.max.fill"
    }

    // MARK: - Sheets

    private func datePickerSheetDate() -> some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Snooze until (date)",
                    selection: snoozeUntilBindingForDate(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                Spacer()
            }
            .navigationTitle("Snooze Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePickerDate = false }
                }
            }
        }
        .onAppear { cancelAutoHide() }
        .onDisappear { if !isGlobalSnoozeActive { scheduleAutoHide() } }
    }

    private func datePickerSheetTime() -> some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Snooze until (time)",
                    selection: snoozeUntilBindingForTime(),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                Spacer()
            }
            .navigationTitle("Snooze Time")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePickerTime = false }
                }
            }
        }
        .onAppear { cancelAutoHide() }
        .onDisappear { if !isGlobalSnoozeActive { scheduleAutoHide() } }
    }
}

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
