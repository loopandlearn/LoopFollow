//
//  ObservableUserDefaults.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-24.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Combine
import Foundation

/*
 Legacy storage, we are moving away from this
 */

class ObservableUserDefaults {
    static let shared = ObservableUserDefaults()

    var url = ObservableUserDefaultsValue<String>(key: "url", default: "")
    var device = ObservableUserDefaultsValue<String>(key: "device", default: "")
    var nsWriteAuth = ObservableUserDefaultsValue<Bool>(key: "nsWriteAuth", default: false)
    var nsAdminAuth = ObservableUserDefaultsValue<Bool>(key: "nsAdminAuth", default: false)

    private init() {}
}
