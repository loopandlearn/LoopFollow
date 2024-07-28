//
//  ObservableUserDefaults.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-24.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine

class ObservableUserDefaults {
    static let shared = ObservableUserDefaults()

    var url = ObservableUserDefaultsValue<String>(key: "url", default: "")
    var device = ObservableUserDefaultsValue<String>(key: "device", default: "")
    var nsWriteAuth = ObservableUserDefaultsValue<Bool>(key: "nsWriteAuth", default: false)

    private init() {}
}
