//
//  AuthenticationDelegateExtension.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/20/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {

   // authentication delegate implementation
   func nightscoutDidConnect() -> Bool {
      return true
   }
   func dexcomDidConnect() -> Bool {
      return true
   }
}
