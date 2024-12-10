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
    @Published var contactEnabled: Bool

    private var storage = ObservableUserDefaults.shared
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFromStorage = false // Prevent recursive updates

    init() {
        self.contactEnabled = storage.contactEnabled.value

        // Observe changes in UserDefaults
        storage.contactEnabled.$value
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.isUpdatingFromStorage = true
                self.contactEnabled = newValue
                self.isUpdatingFromStorage = false
            }
            .store(in: &cancellables)

        // Update UserDefaults when local property changes
        $contactEnabled
            .sink { [weak self] newValue in
                guard let self = self else { return }
                // Prevent updating UserDefaults during storage sync
                guard !self.isUpdatingFromStorage else { return }
                self.storage.contactEnabled.value = newValue
            }
            .store(in: &cancellables)
    }
}
