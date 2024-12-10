//
//  ContactSettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-12-10.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine

class ContactSettingsViewModel: ObservableObject {
    @Published var contactEnabled: Bool {
        didSet {
            storage.contactEnabled.value = contactEnabled
        }
    }

    @Published var contactTrend: Bool {
        didSet {
            if contactTrend {
                contactDelta = false
            }
            storage.contactTrend.value = contactTrend
        }
    }

    @Published var contactDelta: Bool {
        didSet {
            if contactDelta {
                contactTrend = false
            }
            storage.contactDelta.value = contactDelta
        }
    }

    private let storage = ObservableUserDefaults.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.contactEnabled = storage.contactEnabled.value
        self.contactTrend = storage.contactTrend.value
        self.contactDelta = storage.contactDelta.value

        storage.contactEnabled.$value
            .assign(to: &$contactEnabled)

        storage.contactTrend.$value
            .assign(to: &$contactTrend)

        storage.contactDelta.$value
            .assign(to: &$contactDelta)
    }
}
