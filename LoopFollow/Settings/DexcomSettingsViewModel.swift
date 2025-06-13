// LoopFollow
// DexcomSettingsViewModel.swift
// Created by Jonas Björkert on 2025-01-18.

import Combine
import Foundation

class DexcomSettingsViewModel: ObservableObject {
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

    init() {}
}
