// LoopFollow
// DexcomSettingsViewModel.swift

import Combine
import Foundation

class DexcomSettingsViewModel: ObservableObject {
    /// Whether this is a fresh setup (credentials were empty when view appeared)
    private(set) var isFreshSetup: Bool = false

    @Published var userName: String = Storage.shared.shareUserName.value {
        willSet {
            if newValue != userName {
                Storage.shared.shareUserName.value = newValue
            }
        }
    }

    @Published var password: String = Storage.shared.sharePassword.value {
        willSet {
            if newValue != password {
                Storage.shared.sharePassword.value = newValue
            }
        }
    }

    @Published var server: String = Storage.shared.shareServer.value {
        willSet {
            if newValue != server {
                Storage.shared.shareServer.value = newValue
            }
        }
    }

    /// Whether credentials are filled in
    var hasCredentials: Bool {
        !userName.isEmpty && !password.isEmpty
    }

    init() {
        isFreshSetup = Storage.shared.shareUserName.value.isEmpty
    }
}
