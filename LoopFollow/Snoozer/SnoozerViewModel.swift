// LoopFollow
// SnoozerViewModel.swift
// Created by Jonas Björkert.

import Combine
import Foundation

final class SnoozerViewModel: ObservableObject {
    @Published var activeAlarm: Alarm?
    @Published var snoozeUnits: Int = 5
    @Published var timeUnitLabel: String = "minutes"

    // Global snooze properties
    @Published var globalSnoozeUnits: Int = 60 // Default to 1 hour
    @Published var isGlobalSnoozeActive: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        Observable.shared.currentAlarm.$value
            .map { id -> Alarm? in
                guard let id = id else { return nil }
                return Storage.shared.alarms.value.first { $0.id == id }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alarm in
                self?.activeAlarm = alarm
                if let a = alarm {
                    self?.snoozeUnits = a.snoozeDuration
                    self?.timeUnitLabel = a.type.snoozeTimeUnit.label
                }
            }
            .store(in: &cancellables)
        if let alarm = activeAlarm {
            snoozeUnits = alarm.snoozeDuration
        }

        // Observe alarm configuration changes
        Storage.shared.alarmConfiguration.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateGlobalSnoozeState()
            }
            .store(in: &cancellables)

        // Initialize global snooze state
        updateGlobalSnoozeState()
    }

    func snoozeTapped() {
        AlarmManager.shared.performSnooze(snoozeUnits)
    }

    // MARK: - Global Snooze Methods

    func updateGlobalSnoozeState() {
        let config = Storage.shared.alarmConfiguration.value
        isGlobalSnoozeActive = config.snoozeUntil?.compare(Date()) == .orderedDescending
    }

    func toggleGlobalSnooze() {
        var config = Storage.shared.alarmConfiguration.value

        if isGlobalSnoozeActive {
            // Turn off global snooze
            config.snoozeUntil = nil
        } else {
            // Turn on global snooze
            config.snoozeUntil = Date().addingTimeInterval(TimeInterval(globalSnoozeUnits * 60))
        }

        Storage.shared.alarmConfiguration.value = config
        updateGlobalSnoozeState()

        // Stop any current alarm when global snooze is activated
        if isGlobalSnoozeActive {
            AlarmManager.shared.stopAlarm()
        }
    }

    func setGlobalSnoozeDuration(_ minutes: Int) {
        globalSnoozeUnits = minutes

        // If global snooze is currently active, update the duration
        if isGlobalSnoozeActive {
            var config = Storage.shared.alarmConfiguration.value
            config.snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
            Storage.shared.alarmConfiguration.value = config
        }
    }

    func globalSnoozeDurationChanged() {
        setGlobalSnoozeDuration(globalSnoozeUnits)
    }
}
