//
//  AppStateController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/17/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

// App Sate used used to changes to the app view controllers (Settings, for example)
// Recommended way of utilizing is when viewVillAppear(..) is called,
// look in the app state to see if further action must be t

// Setup App States to comminicate between views

// Graph Setup Flags
enum ChartSettingsChangeEnum: Int {
  case chartScaleXChanged = 1
  case showDotsChanged = 2
  case showLinesChanged = 4
  case offsetCarbsBolusChanged = 8
  case hoursToLoadChanged = 16
  case predictionToLoadChanged = 32
  case minBasalScaleChanged = 64
  case minBGScaleChanged = 128
  case overrideDisplayLocationChanged = 256
  case lowLineChanged = 512
  case highLineChanged = 1024
  case smallGraphHeight = 2048
}

// General Settings Flags
enum GeneralSettingsChangeEnum: Int { 
   case colorBGTextChange = 1
   case speakBGChange = 2
   case backgroundRefreshFrequencyChange = 4
   case backgroundRefreshChange = 8
   case appBadgeChange = 16
   case dimScreenWhenIdleChange = 32
   case forceDarkModeChang = 64
   case persistentNotificationChange = 128
   case persistentNotificationLastBGTimeChange = 256
   case screenlockSwitchStateChange = 512
    case showStatsChange = 1024
    case showSmallGraphChange = 2048
    case useIFCCChange = 4096
}

class AppStateController {
   
   // add app states & methods here

   // General Settings States
   var generalSettingsChanged : Bool = false
   var generalSettingsChanges : Int = 0

   // Chart Settings State
   var chartSettingsChanged : Bool = false // settings change has ocurred
   var chartSettingsChanges: Int = 0      // what settings have changed
   
   // Info Data Settings State; no need for flags
   var infoDataSettingsChanged: Bool = false
}
