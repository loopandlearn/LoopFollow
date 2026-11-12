// LoopFollow
// ProfileValuesEditor.swift

import SwiftUI

/// Formats profile values in the profile's own units. Glucose values in mmol/L have one decimal; other values
/// show as many decimals as they have (up to three), so they are never shown rounded.
enum ProfileValueFormat {
    static func text(_ value: Double, decimals: Int) -> String {
        Localizer.formatToLocalizedString(value, maxFractionDigits: max(decimals, 3), minFractionDigits: decimals)
    }

    static func text(_ value: Double, kind: ProfileScheduleKind, limits: ProfileEditLimits?, glucoseUnits: String) -> String {
        if kind.isGlucose, TherapyProfileValues.normalizedUnits(glucoseUnits) == TherapyProfileValues.mmol {
            return Localizer.formatToLocalizedString(value, maxFractionDigits: 1, minFractionDigits: 1)
        }
        return text(value, decimals: limits.map { kind.decimals(in: $0) } ?? defaultDecimals(kind))
    }

    static func defaultDecimals(_ kind: ProfileScheduleKind) -> Int {
        kind == .basal ? 2 : 0
    }

    static func segmentText(_ segment: EditableSegment, kind: ProfileScheduleKind, limits: ProfileEditLimits?, glucoseUnits: String, singleTarget: Bool = false) -> String {
        if kind.isRange, !singleTarget {
            return "\(text(segment.value, kind: kind, limits: limits, glucoseUnits: glucoseUnits)) – \(text(segment.high, kind: kind, limits: limits, glucoseUnits: glucoseUnits))"
        }
        return text(segment.value, kind: kind, limits: limits, glucoseUnits: glucoseUnits)
    }

    /// Schedule start times are offsets from midnight in the profile's time zone.
    static func timeText(_ seconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}

/// A start time and its value side by side, stacked when they do not fit, as with the largest text sizes.
struct ProfileRowLayout<Time: View, Value: View>: View {
    @ViewBuilder let time: Time
    @ViewBuilder let value: Value

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                time
                Spacer()
                value
            }
            VStack(alignment: .leading, spacing: 2) {
                time
                value
            }
        }
    }
}

/// Edits one schedule of a profile: a list of start times with values, on the time grid and inside the bounds
/// of the published limits. Without limits the schedule is shown read-only.
struct ProfileValuesEditor: View {
    let kind: ProfileScheduleKind
    @Binding var segments: [EditableSegment]
    let units: String
    /// Nil makes the editor read-only.
    let limits: ProfileEditLimits?
    /// One target value per time, for Trio.
    var singleTarget = false

    private var isRange: Bool { kind.isRange && !singleTarget }

    @State private var expandedID: UUID?

    private var unitText: String { kind.unitText(glucoseUnits: units) }

    var body: some View {
        Section(header: Text(singleTarget && kind.isRange ? "Glucose Target" : kind.title), footer: footer) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                VStack(alignment: .leading, spacing: 4) {
                    row(index: index, segment: segment)
                    if let limits, expandedID == segment.id {
                        pickers(index: index, limits: limits)
                    }
                }
                .deleteDisabled(limits == nil || index == 0)
            }
            .onDelete { offsets in
                guard limits != nil else { return }
                let removable = offsets.filter { $0 > 0 }
                segments.remove(atOffsets: IndexSet(removable))
            }

            if let limits {
                Button {
                    let added = ProfileSegmentGrid.addSegment(to: segments, segmentSeconds: limits.segmentSeconds, maxSegments: limits.segmentLimit(for: kind))
                    let newSegment = added.first { segment in !segments.contains { $0.id == segment.id } }
                    segments = added
                    expandedID = newSegment?.id
                } label: {
                    Label("Add Time", systemImage: "plus.circle")
                }
                .disabled(ProfileSegmentGrid.newSegmentStart(segments, segmentSeconds: limits.segmentSeconds, maxSegments: limits.segmentLimit(for: kind)) == nil)
            }
        }
    }

    private func row(index _: Int, segment: EditableSegment) -> some View {
        let status = valueStatus(segment)
        return Button {
            guard limits != nil else { return }
            withAnimation { expandedID = expandedID == segment.id ? nil : segment.id }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                ProfileRowLayout {
                    Text(ProfileValueFormat.timeText(segment.seconds))
                        .foregroundColor(.primary)
                } value: {
                    Text("\(ProfileValueFormat.segmentText(segment, kind: kind, limits: limits, glucoseUnits: units, singleTarget: singleTarget)) \(unitText)")
                        .foregroundColor(color(for: status))
                }
                switch status {
                case .notAllowed:
                    Text("Outside what is allowed. Change this value before sending.")
                        .font(.caption)
                        .foregroundColor(.red)
                case .outsideRecommended:
                    Text("Unusual value. Double-check it.")
                        .font(.caption)
                        .foregroundColor(.orange)
                case .ok:
                    EmptyView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pickers(index: Int, limits: ProfileEditLimits) -> some View {
        HStack(spacing: 0) {
            if index > 0 {
                Picker("Start Time", selection: startBinding(index)) {
                    ForEach(ProfileSegmentGrid.allowedStarts(for: index, in: segments, segmentSeconds: limits.segmentSeconds), id: \.self) { seconds in
                        Text(ProfileValueFormat.timeText(seconds)).tag(seconds)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            if isRange {
                valuePicker(label: "Low", selection: valueBinding(index, high: false), options: options(limits, current: segments[index].value, upTo: segments[index].high), limits: limits)
                valuePicker(label: "High", selection: valueBinding(index, high: true), options: options(limits, current: segments[index].high, from: segments[index].value), limits: limits)
            } else {
                valuePicker(label: kind.title, selection: valueBinding(index, high: false), options: options(limits, current: segments[index].value), limits: limits)
            }
        }
        .frame(height: 150)
    }

    private func valuePicker(label: String, selection: Binding<Double>, options: [Double], limits: ProfileEditLimits) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.self) { value in
                Text(ProfileValueFormat.text(value, kind: kind, limits: limits, glucoseUnits: units))
                    .foregroundColor(color(for: limits.status(of: value, in: kind)))
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
    }

    /// The allowed values, with the current value kept as it is when it is not on the grid (it is then
    /// shown, and flagged when it is outside the bounds, but never replaced without the user choosing another value).
    private func options(_ limits: ProfileEditLimits, current: Double, from lower: Double? = nil, upTo upper: Double? = nil) -> [Double] {
        var values = kind.options(in: limits).filter { value in
            (lower.map { value >= $0 - ProfileEditLimits.tolerance } ?? true)
                && (upper.map { value <= $0 + ProfileEditLimits.tolerance } ?? true)
        }
        if let index = values.firstIndex(where: { abs($0 - current) < ProfileEditLimits.tolerance }) {
            values[index] = current
        } else {
            values.append(current)
            values.sort()
        }
        return values
    }

    private func startBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { segments.indices.contains(index) ? segments[index].seconds : 0 },
            set: { newValue in
                guard segments.indices.contains(index), index > 0 else { return }
                segments[index].seconds = newValue
            }
        )
    }

    private func valueBinding(_ index: Int, high: Bool) -> Binding<Double> {
        Binding(
            get: {
                guard segments.indices.contains(index) else { return 0 }
                return high ? segments[index].high : segments[index].value
            },
            set: { newValue in
                guard segments.indices.contains(index) else { return }
                if high {
                    segments[index].high = newValue
                } else {
                    segments[index].value = newValue
                    if singleTarget, kind.isRange { segments[index].high = newValue }
                }
            }
        )
    }

    private func valueStatus(_ segment: EditableSegment) -> ProfileValueStatus {
        guard let limits else { return .ok }
        let statuses = kind.isRange
            ? [limits.status(of: segment.value, in: kind), limits.status(of: segment.high, in: kind)]
            : [limits.status(of: segment.value, in: kind)]
        if statuses.contains(.notAllowed) || (kind.isRange && segment.value > segment.high + ProfileEditLimits.tolerance) {
            return .notAllowed
        }
        return statuses.contains(.outsideRecommended) ? .outsideRecommended : .ok
    }

    private func color(for status: ProfileValueStatus) -> Color {
        switch status {
        case .ok: return limits == nil ? .secondary : .primary
        case .outsideRecommended: return .orange
        case .notAllowed: return .red
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if kind == .basal {
                Text("Total: \(Localizer.formatToLocalizedString(TherapyProfile.basalTotal(segments.map { ProfileScheduleItem(seconds: $0.seconds, value: $0.value) }), maxFractionDigits: 2, minFractionDigits: 2)) U/day")
            }
            if let limits {
                Text(limits.boundsText(for: kind))
                Text("\(segments.count) of \(limits.segmentLimit(for: kind)) times. Tap a row to change it, swipe left to remove it.")
            }
        }
    }
}
