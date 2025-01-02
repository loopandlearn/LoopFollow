//
//  ContactSettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-12-10.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine

extension Bundle {
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LoopFollow"
    }
}

class ContactSettingsViewModel: ObservableObject {
    var contactName: String {
        "\(Bundle.main.displayName) - BG"
    }

    @Published var contactEnabled: Bool {
        didSet {
            storage.contactEnabled.value = contactEnabled
            triggerRefresh()
        }
    }

    @Published var contactTrend: Bool {
        didSet {
            if contactTrend {
                contactDelta = false
            }
            storage.contactTrend.value = contactTrend
            triggerRefresh()
        }
    }

    @Published var contactDelta: Bool {
        didSet {
            if contactDelta {
                contactTrend = false
            }
            storage.contactDelta.value = contactDelta
            triggerRefresh()
        }
    }

    @Published var contactBackgroundColor: String {
        didSet {
            storage.contactBackgroundColor.value = contactBackgroundColor
            triggerRefresh()
        }
    }
    
    @Published var contactTextColor: String {
        didSet {
            storage.contactTextColor.value = contactTextColor
            triggerRefresh()
        }
    }

    private let storage = ObservableUserDefaults.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.contactEnabled = storage.contactEnabled.value
        self.contactTrend = storage.contactTrend.value
        self.contactDelta = storage.contactDelta.value
        self.contactBackgroundColor = storage.contactBackgroundColor.value
        self.contactTextColor = storage.contactTextColor.value

        storage.contactEnabled.$value
            .assign(to: &$contactEnabled)

        storage.contactTrend.$value
            .assign(to: &$contactTrend)

        storage.contactDelta.$value
            .assign(to: &$contactDelta)

        storage.contactBackgroundColor.$value
            .assign(to: &$contactBackgroundColor)
        
        storage.contactTextColor.$value
            .assign(to: &$contactTextColor)
    }

    private func triggerRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }
}
