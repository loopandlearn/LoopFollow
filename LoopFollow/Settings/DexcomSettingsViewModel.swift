// LoopFollow
// DexcomSettingsViewModel.swift
// Created by Jonas Björkert on 2025-01-18.

import Combine
import Foundation

class DexcomSettingsViewModel: ObservableObject {
    @Published var userName: String = UserDefaultsRepository.shareUserName.value {
        willSet {
            if newValue != userName {
                UserDefaultsRepository.shareUserName.value = newValue
            }
        }
    }

    @Published var password: String = UserDefaultsRepository.sharePassword.value {
        willSet {
            if newValue != password {
                UserDefaultsRepository.sharePassword.value = newValue
            }
        }
    }

    @Published var server: String = UserDefaultsRepository.shareServer.value {
        willSet {
            if newValue != server {
                UserDefaultsRepository.shareServer.value = newValue
            }
        }
    }

    init() {}
}
