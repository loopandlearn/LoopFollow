// LoopFollow
// ContactSettingsViewModel.swift

import Combine
import Foundation

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
        contactEnabled = Storage.shared.contactEnabled.value
        contactTrend = Storage.shared.contactTrend.value
        contactDelta = Storage.shared.contactDelta.value
        contactBackgroundColor = Storage.shared.contactBackgroundColor.value
        contactTextColor = Storage.shared.contactTextColor.value

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
