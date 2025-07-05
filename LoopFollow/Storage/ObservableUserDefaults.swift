// LoopFollow
// ObservableUserDefaults.swift
// Created by Jonas Björkert.

import Combine
import Foundation

/*
 Legacy storage, we are moving away from this
 */

class ObservableUserDefaults {
    static let shared = ObservableUserDefaults()

    var old_url = ObservableUserDefaultsValue<String>(key: "url", default: "")
    var old_device = ObservableUserDefaultsValue<String>(key: "device", default: "")
    var old_nsWriteAuth = ObservableUserDefaultsValue<Bool>(key: "nsWriteAuth", default: false)
    var old_nsAdminAuth = ObservableUserDefaultsValue<Bool>(key: "nsAdminAuth", default: false)

    private init() {}
}
