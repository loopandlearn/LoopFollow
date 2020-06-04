//
//  UserDefaults.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/4/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

class UserDefaultsRepository {
    
    static let url = UserDefaultsValue<String>(key: "url", default: "")
    
    
    // Graph Settings
    static let showDots = UserDefaultsValue<Bool>(key: "showDots", default: true)
    static let showLines = UserDefaultsValue<Bool>(key: "showLines", default: true)
    
}
