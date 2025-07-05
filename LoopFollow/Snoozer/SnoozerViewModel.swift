// LoopFollow
// SnoozerViewModel.swift
// Created by Jonas Björkert.

import Combine
import Foundation

final class SnoozerViewModel: ObservableObject {
    @Published var activeAlarm: Alarm?
    @Published var snoozeUnits: Int = 5
    @Published var timeUnitLabel: String = "minutes"

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
    }

    func snoozeTapped() {
        AlarmManager.shared.performSnooze(snoozeUnits)
    }
}
