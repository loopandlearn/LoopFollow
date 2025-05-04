//
//  SnoozerViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-04.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine

final class SnoozerViewModel: ObservableObject {
    @Published var activeAlarm: Alarm?
    @Published var snoozeMins: Int = 5
    @Published var timeUnitLabel: String = "minutes"

    private var bag = Set<AnyCancellable>()

    init() {
        Observable.shared.currentAlarm.$value
            .compactMap { $0 }                      // drop nils
            .map { id in
                Storage.shared.alarms.value.first { $0.id == id }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alarm in
                self?.activeAlarm = alarm           // may be nil
                if let a = alarm {
                    self?.snoozeMins = a.snoozeDuration
                    self?.timeUnitLabel = a.type.timeUnit.label
                }
            }
            .store(in: &bag)
    }

    func snoozeTapped() {
        guard let alarm = activeAlarm else { return }
        AlarmManager.shared.performSnooze(
            snoozeMins * Int(alarm.type.timeUnit.seconds) / 60
        )
    }
}
