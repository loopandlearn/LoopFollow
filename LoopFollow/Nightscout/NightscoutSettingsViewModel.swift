//
//  NightscoutSettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-18.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine

protocol NightscoutSettingsViewModelDelegate: AnyObject {
    func nightscoutSettingsDidFinish()
}

class NightscoutSettingsViewModel: ObservableObject {
    weak var delegate: NightscoutSettingsViewModelDelegate?

    private var initialURL: String
    private var initialToken: String

    @Published var nightscoutURL: String = ObservableUserDefaults.shared.url.value {
        willSet {
            if newValue != nightscoutURL {
                ObservableUserDefaults.shared.url.value = newValue
                triggerCheckStatus()
            }
        }
    }
    @Published var nightscoutToken: String = UserDefaultsRepository.token.value {
        willSet {
            if newValue != nightscoutToken {
                UserDefaultsRepository.token.value = newValue
                triggerCheckStatus()
            }
        }
    }
    @Published var nightscoutStatus: String = "Checking..."

    private var cancellables = Set<AnyCancellable>()
    private var checkStatusSubject = PassthroughSubject<Void, Never>()
    private var checkStatusWorkItem: DispatchWorkItem?

    init() {
        self.initialURL = ObservableUserDefaults.shared.url.value
        self.initialToken = UserDefaultsRepository.token.value

        setupDebounce()
        checkNightscoutStatus()
    }

    private func setupDebounce() {
        checkStatusSubject
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.checkNightscoutStatus()
            }
            .store(in: &cancellables)
    }

    private func triggerCheckStatus() {
        checkStatusWorkItem?.cancel()

        nightscoutStatus = "Checking..."

        checkStatusWorkItem = DispatchWorkItem {
            self.checkStatusSubject.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkStatusWorkItem!)
    }

    func processURL(_ value: String) {
        var useTokenUrl = false

        if let urlComponents = URLComponents(string: value), let queryItems = urlComponents.queryItems {
            if let tokenItem = queryItems.first(where: { $0.name.lowercased() == "token" }) {
                let tokenPattern = "^[^-\\s]+-[0-9a-fA-F]{16}$"
                if let token = tokenItem.value, let _ = token.range(of: tokenPattern, options: .regularExpression) {
                    var baseComponents = urlComponents
                    baseComponents.queryItems = nil
                    if let baseURL = baseComponents.string {
                        nightscoutToken = token
                        nightscoutURL = baseURL
                        useTokenUrl = true
                    }
                }
            }
        }

        if !useTokenUrl {
            let filtered = value.replacingOccurrences(of: "[^A-Za-z0-9:/._-]", with: "", options: .regularExpression).lowercased()
            var cleanURL = filtered
            while cleanURL.count > 8 && cleanURL.last == "/" {
                cleanURL = String(cleanURL.dropLast())
            }
            nightscoutURL = cleanURL
        }
    }

    func checkNightscoutStatus() {
        NightscoutUtils.verifyURLAndToken { error, jwtToken, nsWriteAuth, nsAdminAuth in
            DispatchQueue.main.async {
                ObservableUserDefaults.shared.nsWriteAuth.value = nsWriteAuth
                ObservableUserDefaults.shared.nsAdminAuth.value = nsAdminAuth

                self.updateStatusLabel(error: error)
            }
        }
    }

    func updateStatusLabel(error: NightscoutUtils.NightscoutError?) {
        if let error = error {
            switch error {
            case .invalidURL:
                nightscoutStatus = "Invalid URL"
            case .networkError:
                nightscoutStatus = "Network Error"
            case .invalidToken:
                nightscoutStatus = "Invalid Token"
            case .tokenRequired:
                nightscoutStatus = "Token Required"
            case .siteNotFound:
                nightscoutStatus = "Site Not Found"
            case .unknown:
                nightscoutStatus = "Unknown Error"
            case .emptyAddress:
                nightscoutStatus = "Address Empty"
            }
        } else {
            let authStatus: String
            if ObservableUserDefaults.shared.nsAdminAuth.value {
                authStatus = "Admin"
            } else {
                authStatus = "Read" + (ObservableUserDefaults.shared.nsWriteAuth.value ? " & Write" : "")
            }

            nightscoutStatus = "OK (\(authStatus))"

            if (nightscoutURL != initialURL || nightscoutToken != initialToken) {
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
            }
        }
    }

    func dismiss() {
        delegate?.nightscoutSettingsDidFinish()
    }
}
