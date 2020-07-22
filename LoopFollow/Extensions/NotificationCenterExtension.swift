//
//  NotificationCenterExtension.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/21/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

extension Notification.Name {

   static let needDexcomAuthentication = Notification.Name("needDexcomAuthentication")
   static let needNightscoutAuthentication = Notification.Name("needNightscoutAuthentication")
   static let didCompleteDexcomAuthentication = Notification.Name("didCompleteDexcomAuthentication")
   static let didCompleteNightscoutAuthentication = Notification.Name("didCompleteNightscoutAuthentication")

}
