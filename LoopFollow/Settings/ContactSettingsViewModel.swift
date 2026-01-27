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
            Storage.shared.contactTrend.value = contactTrend
            if contactTrend != .include {
                contactTrendTarget = .BG
            }
            if contactTrend != .separate {
                if contactDeltaTarget == .Trend { contactDeltaTarget = .BG }
                if contactIOBTarget == .Trend { contactIOBTarget = .BG }
            }
            triggerRefresh()
        }
    }

    @Published var contactDelta: ContactIncludeOption {
        didSet {
            Storage.shared.contactDelta.value = contactDelta
            if contactDelta != .include {
                contactDeltaTarget = .BG
            }
            if contactDelta != .separate {
                if contactTrendTarget == .Delta { contactTrendTarget = .BG }
                if contactIOBTarget == .Delta { contactIOBTarget = .BG }
            }
            triggerRefresh()
        }
    }

    @Published var contactIOB: ContactIncludeOption {
        didSet {
            Storage.shared.contactIOB.value = contactIOB
            if contactIOB != .include {
                contactIOBTarget = .BG
            }
            if contactIOB != .separate {
                if contactTrendTarget == .IOB { contactTrendTarget = .BG }
                if contactDeltaTarget == .IOB { contactDeltaTarget = .BG }
            }
            triggerRefresh()
        }
    }

    @Published var contactTrendTarget: ContactType {
        didSet {
            Storage.shared.contactTrendTarget.value = contactTrendTarget
            triggerRefresh()
        }
    }

    @Published var contactDeltaTarget: ContactType {
        didSet {
            Storage.shared.contactDeltaTarget.value = contactDeltaTarget
            triggerRefresh()
        }
    }

    @Published var contactIOBTarget: ContactType {
        didSet {
            Storage.shared.contactIOBTarget.value = contactIOBTarget
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
        contactIOB = Storage.shared.contactIOB.value
        contactTrendTarget = Storage.shared.contactTrendTarget.value
        contactDeltaTarget = Storage.shared.contactDeltaTarget.value
        contactIOBTarget = Storage.shared.contactIOBTarget.value
        contactBackgroundColor = Storage.shared.contactBackgroundColor.value
        contactTextColor = Storage.shared.contactTextColor.value

        Storage.shared.contactEnabled.$value
            .assign(to: &$contactEnabled)

        Storage.shared.contactTrend.$value
            .assign(to: &$contactTrend)

        Storage.shared.contactDelta.$value
            .assign(to: &$contactDelta)

        Storage.shared.contactIOB.$value
            .assign(to: &$contactIOB)

        Storage.shared.contactTrendTarget.$value
            .assign(to: &$contactTrendTarget)

        Storage.shared.contactDeltaTarget.$value
            .assign(to: &$contactDeltaTarget)

        Storage.shared.contactIOBTarget.$value
            .assign(to: &$contactIOBTarget)

        Storage.shared.contactBackgroundColor.$value
            .assign(to: &$contactBackgroundColor)

        Storage.shared.contactTextColor.$value
            .assign(to: &$contactTextColor)
    }

    func availableTargets(for field: ContactType) -> [ContactType] {
        var targets: [ContactType] = [.BG]
        if field != .Trend, contactTrend == .separate {
            targets.append(.Trend)
        }
        if field != .Delta, contactDelta == .separate {
            targets.append(.Delta)
        }
        if field != .IOB, contactIOB == .separate {
            targets.append(.IOB)
        }
        return targets
    }

    private func triggerRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }
}
