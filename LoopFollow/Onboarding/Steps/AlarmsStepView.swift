// LoopFollow
// AlarmsStepView.swift

import HealthKit
import SwiftUI

/// The alarms phase: one recommended alarm per page, each with a toggle and a few
/// of its most useful settings. The number of pages depends on the data source
/// (Dexcom-only followers don't see loop/pump alarms), which the phase reports via
/// `phaseProgress` so the overall progress bar stays accurate.
struct AlarmsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    /// Page index into `offeredIndices`.
    @State private var index = 0

    /// Indices into `viewModel.seedAlarms` that are offered for this data source.
    private var offeredIndices: [Int] {
        viewModel.seedAlarms.indices.filter { viewModel.isOffered(viewModel.seedAlarms[$0]) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let seedIndex = offeredIndices[safe: index] {
                alarmPage(seedIndex: seedIndex)
            }

            OnboardingNavFooter(
                continueEnabled: true,
                showBack: true,
                onBack: goBack,
                onContinue: goForward
            )
        }
        .onAppear(perform: reportProgress)
        .onChange(of: index) { _ in reportProgress() }
    }

    private func reportProgress() {
        viewModel.phaseProgress = .init(page: index, count: offeredIndices.count)
    }

    private func goForward() {
        if index < offeredIndices.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
        } else {
            viewModel.advance()
        }
    }

    private func goBack() {
        if index > 0 {
            withAnimation(.easeInOut(duration: 0.25)) { index -= 1 }
        } else {
            viewModel.goBack()
        }
    }

    // MARK: - Page

    private func alarmPage(seedIndex: Int) -> some View {
        let seed = $viewModel.seedAlarms[seedIndex]
        let display = viewModel.seedAlarms[seedIndex]
        return Form {
            Section {
                EmptyView()
            } header: {
                VStack(spacing: 8) {
                    Image(systemName: display.icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(display.title)
                        .font(.title2.weight(.bold))
                    Text(display.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .textCase(nil)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Toggle("Enable this alarm", isOn: seed.isEnabled)

                if seed.wrappedValue.isEnabled {
                    controls(for: seed)
                }
            } footer: {
                if seed.wrappedValue.isEnabled, let text = explanation(for: seed.wrappedValue) {
                    Text(text)
                }
            }
        }
    }

    // MARK: - Per-alarm controls

    @ViewBuilder
    private func controls(for seed: Binding<OnboardingViewModel.SeedAlarm>) -> some View {
        switch seed.wrappedValue.type {
        case .low:
            bgPicker(seed, title: "Alert below", range: 40 ... 150, keyPath: \.belowBG)
            intStepper(seed, label: "Warn early by", range: 0 ... 30, step: 5, unit: "min", keyPath: \.predictiveMinutes)
        case .high:
            bgPicker(seed, title: "Alert above", range: 120 ... 350, keyPath: \.aboveBG)
            intStepper(seed, label: "Only after high for", range: 0 ... 60, step: 5, unit: "min", keyPath: \.persistentMinutes)
        case .fastDrop:
            bgPicker(seed, title: "Drop per reading", range: 3 ... 54, keyPath: \.delta)
            intStepper(seed, label: "Readings in a row", range: 1 ... 3, step: 1, unit: "", keyPath: \.monitoringWindow)
        case .missedReading:
            doubleStepper(seed, label: "No reading for", range: 11 ... 121, step: 5, unit: "min", keyPath: \.threshold)
        case .notLooping:
            doubleStepper(seed, label: "No loop for", range: 16 ... 61, step: 5, unit: "min", keyPath: \.threshold)
        case .battery:
            doubleStepper(seed, label: "At or below", range: 0 ... 100, step: 5, unit: "%", keyPath: \.threshold)
        case .iob:
            doubleStepper(seed, label: "Alert above", range: 0 ... 30, step: 1, unit: "U", keyPath: \.threshold)
        case .cob:
            doubleStepper(seed, label: "Alert above", range: 0 ... 200, step: 5, unit: "g", keyPath: \.threshold)
        case .sensorChange:
            doubleStepper(seed, label: "Remind after", range: 1 ... 15, step: 1, unit: "days", keyPath: \.threshold)
            activePicker(seed)
        case .pumpChange:
            doubleStepper(seed, label: "Remind after", range: 1 ... 7, step: 1, unit: "days", keyPath: \.threshold)
            activePicker(seed)
        case .pump:
            doubleStepper(seed, label: "Alert below", range: 0 ... 100, step: 5, unit: "U", keyPath: \.threshold)
        default:
            EmptyView()
        }
    }

    private func bgPicker(
        _ seed: Binding<OnboardingViewModel.SeedAlarm>,
        title: String,
        range: ClosedRange<Double>,
        keyPath: WritableKeyPath<Alarm, Double?>
    ) -> some View {
        BGPicker(title: title, range: range, value: doubleBinding(seed, keyPath: keyPath))
    }

    private func doubleStepper(
        _ seed: Binding<OnboardingViewModel.SeedAlarm>,
        label: String,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        keyPath: WritableKeyPath<Alarm, Double?>
    ) -> some View {
        let value = doubleBinding(seed, keyPath: keyPath)
        return Stepper(value: value, in: range, step: step) {
            labelRow(label, value: "\(formatted(value.wrappedValue)) \(unit)")
        }
    }

    private func intStepper(
        _ seed: Binding<OnboardingViewModel.SeedAlarm>,
        label: String,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        keyPath: WritableKeyPath<Alarm, Int?>
    ) -> some View {
        let value = intBinding(seed, keyPath: keyPath)
        let text = unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)"
        return Stepper(value: value, in: range, step: step) {
            labelRow(label, value: text)
        }
    }

    /// Plain-language summary of what a recommended alarm will do, shown as the
    /// section footer. Fast drop earns one because its per-reading-times-window
    /// behaviour isn't obvious from the two controls alone.
    private func explanation(for seed: OnboardingViewModel.SeedAlarm) -> String? {
        switch seed.type {
        case .fastDrop:
            let alarm = seed.alarm
            let fallback = Alarm(type: .fastDrop)
            let delta = alarm.delta ?? fallback.delta ?? 0
            let window = alarm.monitoringWindow ?? fallback.monitoringWindow ?? 0
            guard delta > 0, window > 0 else { return nil }

            let unit = Localizer.getPreferredUnit().localizedShortUnitString
            let perReading = Localizer.formatQuantity(delta)

            if window == 1 {
                return "Warns when glucose falls by at least \(perReading) \(unit) between two readings."
            }
            let total = Localizer.formatQuantity(delta * Double(window))
            let minutes = window * 5
            return "Warns when glucose falls by at least \(perReading) \(unit) on each of \(window) readings in a row — about \(total) \(unit) over roughly \(minutes) minutes."
        default:
            return nil
        }
    }

    /// Day/night picker for reminder alarms (sensor/pump change), so they don't
    /// fire overnight by default. Reuses the same menu picker as the full editor.
    private func activePicker(_ seed: Binding<OnboardingViewModel.SeedAlarm>) -> some View {
        let binding = Binding<ActiveOption>(
            get: { seed.wrappedValue.alarm.activeOption },
            set: { seed.wrappedValue.alarm.activeOption = $0 }
        )
        return AlarmEnumMenuPicker(title: "Active during", selection: binding)
    }

    private func labelRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func doubleBinding(
        _ seed: Binding<OnboardingViewModel.SeedAlarm>,
        keyPath: WritableKeyPath<Alarm, Double?>
    ) -> Binding<Double> {
        Binding(
            get: { seed.wrappedValue.alarm[keyPath: keyPath] ?? typeDefault(seed, keyPath) },
            set: { seed.wrappedValue.alarm[keyPath: keyPath] = $0 }
        )
    }

    private func intBinding(
        _ seed: Binding<OnboardingViewModel.SeedAlarm>,
        keyPath: WritableKeyPath<Alarm, Int?>
    ) -> Binding<Int> {
        Binding(
            get: { seed.wrappedValue.alarm[keyPath: keyPath] ?? typeDefault(seed, keyPath) },
            set: { seed.wrappedValue.alarm[keyPath: keyPath] = $0 }
        )
    }

    /// Fallback value for a control, read from a fresh `Alarm(type:)` so the
    /// onboarding controls share the one source of truth for per-type defaults
    /// and can't drift from them. Only a safety net — seeded alarms already carry
    /// these values, so the fallback is rarely exercised.
    private func typeDefault(_ seed: Binding<OnboardingViewModel.SeedAlarm>, _ keyPath: KeyPath<Alarm, Double?>) -> Double {
        Alarm(type: seed.wrappedValue.type)[keyPath: keyPath] ?? 0
    }

    private func typeDefault(_ seed: Binding<OnboardingViewModel.SeedAlarm>, _ keyPath: KeyPath<Alarm, Int?>) -> Int {
        Alarm(type: seed.wrappedValue.type)[keyPath: keyPath] ?? 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
