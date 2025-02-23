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
            Storage.shared.contactEnabled.value = contactEnabled
            triggerRefresh()
        }
    }

    @Published var contactTrend: ContactIncludeOption {
        didSet {
            if contactTrend == .include && contactDelta == .include {
                contactDelta = .off
            }
            Storage.shared.contactTrend.value = contactTrend
            triggerRefresh()
        }
    }

    @Published var contactDelta: ContactIncludeOption {
        didSet {
            if contactDelta == .include && contactTrend == .include {
                contactTrend = .off
            }
            Storage.shared.contactDelta.value = contactDelta
            triggerRefresh()
        }
    }

    @Published var contactBackgroundColor: String {
        didSet {
            Storage.shared.contactBackgroundColor.value = contactBackgroundColor
            triggerRefresh()
        }
    }
    
    @Published var contactTextColor: String {
        didSet {
            Storage.shared.contactTextColor.value = contactTextColor
            triggerRefresh()
        }
    }

    private let storage = ObservableUserDefaults.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.contactEnabled = Storage.shared.contactEnabled.value
        self.contactTrend = Storage.shared.contactTrend.value
        self.contactDelta = Storage.shared.contactDelta.value
        self.contactBackgroundColor = Storage.shared.contactBackgroundColor.value
        self.contactTextColor = Storage.shared.contactTextColor.value

        Storage.shared.contactEnabled.$value
            .assign(to: &$contactEnabled)

        Storage.shared.contactTrend.$value
            .assign(to: &$contactTrend)

        Storage.shared.contactDelta.$value
            .assign(to: &$contactDelta)

        Storage.shared.contactBackgroundColor.$value
            .assign(to: &$contactBackgroundColor)
        
        Storage.shared.contactTextColor.$value
            .assign(to: &$contactTextColor)
    }

    private func triggerRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }
}
