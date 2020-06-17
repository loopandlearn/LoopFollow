//
//  Alarms.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


extension MainViewController {
    
    
    func checkAlarms(bgs: [sgvData]) {
           
           // Don't check or fire alarms within 1 minute of prior alarm
           if checkAlarmTimer.isValid {  return }
           
           let date = Date()
           let now = date.timeIntervalSince1970
           let currentBG = bgs[bgs.count - 1].sgv
           let lastBG = bgs[bgs.count - 2].sgv
           guard let deltas: [Int] = [
               bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv,
               bgs[bgs.count - 2].sgv - bgs[bgs.count - 3].sgv,
               bgs[bgs.count - 3].sgv - bgs[bgs.count - 4].sgv
               ] else {}
           let currentBGTime = bgs[bgs.count - 1].date
           var alarmTriggered = false
           
           clearOldSnoozes()
           
           // Exit if all is snoozed
           // still send persistent notification with all snoozed
           if UserDefaultsRepository.alertSnoozeAllIsSnoozed.value {
               persistentNotification(bgTime: currentBGTime)
               return
           }
           
           
           // BG Based Alarms
           // Check to make sure it is a current reading and has not already triggered alarm from this reading
           if now - currentBGTime <= (5*60) && currentBGTime > UserDefaultsRepository.snoozedBGReadingTime.value as! TimeInterval {
               
               // trigger temporary alert first
               if UserDefaultsRepository.alertTemporaryActive.value {
                   if UserDefaultsRepository.alertTemporaryBelow.value {
                       if currentBG < UserDefaultsRepository.alertTemporaryBG.value {
                           UserDefaultsRepository.alertTemporaryActive.value = false
                           AlarmSound.whichAlarm = "Temporary Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                           return
                       }
                   } else{
                       if currentBG > UserDefaultsRepository.alertTemporaryBG.value {
                         tabBarController?.selectedIndex = 2
                           AlarmSound.whichAlarm = "Temporary Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                           return
                      }
                   }
               }
               
               // Check Urgent Low
               if UserDefaultsRepository.alertUrgentLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
               currentBG <= UserDefaultsRepository.alertUrgentLowBG.value {
                   // Separating this makes it so the low or drop alerts won't trigger if they already snoozed the urgent low
                   if !UserDefaultsRepository.alertUrgentLowIsSnoozed.value {
                       AlarmSound.whichAlarm = "Urgent Low Alert"
                       triggerAlarm(sound: UserDefaultsRepository.alertUrgentLowSound.value, snooozedBGReadingTime: currentBGTime)
                       return
                   } else {
                       return
                   }
               }
               
               // Check Low
               if UserDefaultsRepository.alertLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
               currentBG <= UserDefaultsRepository.alertLowBG.value && !UserDefaultsRepository.alertLowIsSnoozed.value {
                   AlarmSound.whichAlarm = "Low Alert"
                   triggerAlarm(sound: UserDefaultsRepository.alertLowSound.value, snooozedBGReadingTime: currentBGTime)
                   return
               }
               
               // Check Urgent High
               if UserDefaultsRepository.alertUrgentHighActive.value && !UserDefaultsRepository.alertUrgentHighIsSnoozed.value &&
               currentBG >= UserDefaultsRepository.alertUrgentHighBG.value {
                   // Separating this makes it so the high or rise alerts won't trigger if they already snoozed the urgent high
                   if !UserDefaultsRepository.alertUrgentHighIsSnoozed.value {
                           AlarmSound.whichAlarm = "Urgent High Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertUrgentHighSound.value, snooozedBGReadingTime: currentBGTime)
                           return
                   } else {
                       return
                   }
                   
               }
               
               // Check High
               let persistentReadings = Int(UserDefaultsRepository.alertHighPersistent.value / 5)
               let persistentBG = bgData[bgData.count - 1 - persistentReadings].sgv
               if UserDefaultsRepository.alertHighActive.value &&
                   !UserDefaultsRepository.alertHighIsSnoozed.value &&
                   currentBG >= UserDefaultsRepository.alertHighBG.value &&
                   persistentBG >= UserDefaultsRepository.alertHighBG.value &&
                   !UserDefaultsRepository.alertHighIsSnoozed.value {
                       AlarmSound.whichAlarm = "High Alert"
                       triggerAlarm(sound: UserDefaultsRepository.alertHighSound.value, snooozedBGReadingTime: currentBGTime)
                       return
               }
               
               
               
               // Check Fast Drop
               if UserDefaultsRepository.alertFastDropActive.value && !UserDefaultsRepository.alertFastDropIsSnoozed.value {
                   // make sure limit is off or BG is below value
                   if (!UserDefaultsRepository.alertFastDropUseLimit.value) || (UserDefaultsRepository.alertFastDropUseLimit.value && currentBG < UserDefaultsRepository.alertFastDropBelowBG.value) {
                       let compare = 0 - UserDefaultsRepository.alertFastDropDelta.value
                       
                       //check last 2/3/4 readings
                       if (UserDefaultsRepository.alertFastDropReadings.value == 2 && deltas[0] <= compare)
                       || (UserDefaultsRepository.alertFastDropReadings.value == 3 && deltas[0] <= compare && deltas[1] <= compare)
                       || (UserDefaultsRepository.alertFastDropReadings.value == 4 && deltas[0] <= compare && deltas[1] <= compare && deltas[2] <= compare) {
                           AlarmSound.whichAlarm = "Fast Drop Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertFastDropSound.value, snooozedBGReadingTime: currentBGTime)
                           return
                       }
                   }
               }
               
               // Check Fast Rise
               if UserDefaultsRepository.alertFastRiseActive.value && !UserDefaultsRepository.alertFastRiseIsSnoozed.value {
                   // make sure limit is off or BG is above value
                   if (!UserDefaultsRepository.alertFastRiseUseLimit.value) || (UserDefaultsRepository.alertFastRiseUseLimit.value && currentBG > UserDefaultsRepository.alertFastRiseAboveBG.value) {
                       let compare = UserDefaultsRepository.alertFastDropDelta.value
                       
                       //check last 2/3/4 readings
                       if (UserDefaultsRepository.alertFastRiseReadings.value == 2 && deltas[0] >= compare)
                       || (UserDefaultsRepository.alertFastRiseReadings.value == 3 && deltas[0] >= compare && deltas[1] >= compare)
                       || (UserDefaultsRepository.alertFastRiseReadings.value == 4 && deltas[0] >= compare && deltas[1] >= compare && deltas[2] >= compare) {
                           AlarmSound.whichAlarm = "Fast Rise Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertFastRiseSound.value, snooozedBGReadingTime: currentBGTime)
                           return
                       }
                   }
               }
               

               
           }
           
           // These only get checked and fire if a BG reading doesn't fire
           if UserDefaultsRepository.alertNotLoopingActive.value
               && !UserDefaultsRepository.alertNotLoopingIsSnoozed.value
               && (Double(now - UserDefaultsRepository.alertLastLoopTime.value) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
               && UserDefaultsRepository.alertLastLoopTime.value > 0 {
               
               var trigger = true
               if (UserDefaultsRepository.alertNotLoopingUseLimits.value
                   && (
                       (currentBG <= UserDefaultsRepository.alertNotLoopingUpperLimit.value
                       && currentBG >= UserDefaultsRepository.alertNotLoopingLowerLimit.value) ||
                       // Ignore Limits if BG reading is older than non looping time
                       (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
                   ) ||
                   !UserDefaultsRepository.alertNotLoopingUseLimits.value) {
                       AlarmSound.whichAlarm = "Not Looping Alert"
                       triggerAlarm(sound: UserDefaultsRepository.alertNotLoopingSound.value, snooozedBGReadingTime: nil)
                       return
               }
           }
           
           //check for missed reading alert
           if UserDefaultsRepository.alertMissedReadingActive.value && !UserDefaultsRepository.alertMissedReadingIsSnoozed.value && (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertMissedReading.value * 60)) {
               AlarmSound.whichAlarm = "Missed Reading Alert"
                   triggerAlarm(sound: UserDefaultsRepository.alertMissedReadingSound.value, snooozedBGReadingTime: nil)
                   return
           }
           
           // Check Sage
           if UserDefaultsRepository.alertSAGEActive.value && !UserDefaultsRepository.alertSAGEIsSnoozed.value {
               let insertTime = Double(UserDefaultsRepository.alertSageInsertTime.value)
               let alertDistance = Double(UserDefaultsRepository.alertSAGE.value * 60 * 60)
               let delta = now - insertTime
               let tenDays = 10 * 24 * 60 * 60
               if Double(tenDays) - Double(delta) <= alertDistance {
                   AlarmSound.whichAlarm = "Sensor Change Alert"
                   triggerAlarm(sound: UserDefaultsRepository.alertSAGESound.value, snooozedBGReadingTime: nil)
                   return
               }
           }
           
           // Check Cage
           if UserDefaultsRepository.alertCAGEActive.value && !UserDefaultsRepository.alertCAGEIsSnoozed.value {
               let insertTime = Double(UserDefaultsRepository.alertCageInsertTime.value)
               let alertDistance = Double(UserDefaultsRepository.alertCAGE.value * 60 * 60)
               let delta = now - insertTime
               let tenDays = 3 * 24 * 60 * 60
               if Double(tenDays) - Double(delta) <= alertDistance {
                   AlarmSound.whichAlarm = "Pump Change Alert"
                   triggerAlarm(sound: UserDefaultsRepository.alertCAGESound.value, snooozedBGReadingTime: nil)
                   return
               }
           }
           
           // still send persistent notification if no alarms trigger and persistent notification is on
           persistentNotification(bgTime: currentBGTime)
           
       }
       
    
    func triggerAlarm(sound: String, snooozedBGReadingTime: TimeInterval?)
    {
        guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
        snoozer.updateDisplayWhenTriggered(bgVal: BGText.text ?? "", directionVal: DirectionText.text ?? "", deltaVal: DeltaText.text ?? "", minAgoVal: MinAgoText.text ?? "", alertLabelVal: AlarmSound.whichAlarm)
        snoozeTabItem.isEnabled = true;
        tabBarController?.selectedIndex = 2
        if snooozedBGReadingTime != nil {
            UserDefaultsRepository.snoozedBGReadingTime.value = snooozedBGReadingTime
        }
        AlarmSound.setSoundFile(str: sound)
        AlarmSound.play()
    }
    
    func clearOldSnoozes(){
          let date = Date()
          let now = date.timeIntervalSince1970
          var needsReload: Bool = false
          guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
          
          if date > UserDefaultsRepository.alertSnoozeAllTime.value ?? date {
              UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
              UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertSnoozeAllTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertSnoozeAllIsSnoozed", value: false)
            
          }
          
          if date > UserDefaultsRepository.alertUrgentLowSnoozedTime.value ?? date {
              UserDefaultsRepository.alertUrgentLowSnoozedTime.setNil(key: "alertUrgentLowSnoozedTime")
              UserDefaultsRepository.alertUrgentLowIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertUrgentLowSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertUrgentLowIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertLowSnoozedTime.value ?? date {
              UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
              UserDefaultsRepository.alertLowIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertLowSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertLowIsSnoozed", value: false)
         
          }
          if date > UserDefaultsRepository.alertHighSnoozedTime.value ?? date {
              UserDefaultsRepository.alertHighSnoozedTime.setNil(key: "alertHighSnoozedTime")
              UserDefaultsRepository.alertHighIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertHighSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertHighIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertUrgentHighSnoozedTime.value ?? date {
              UserDefaultsRepository.alertUrgentHighSnoozedTime.setNil(key: "alertUrgentHighSnoozedTime")
              UserDefaultsRepository.alertUrgentHighIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertUrgentHighSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertUrgentHighIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertFastDropSnoozedTime.value ?? date {
              UserDefaultsRepository.alertFastDropSnoozedTime.setNil(key: "alertFastDropSnoozedTime")
              UserDefaultsRepository.alertFastDropIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertFastDropSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertFastDropIsSnoozed", value: false)
             
          }
          if date > UserDefaultsRepository.alertFastRiseSnoozedTime.value ?? date {
              UserDefaultsRepository.alertFastRiseSnoozedTime.setNil(key: "alertFastRiseSnoozedTime")
              UserDefaultsRepository.alertFastRiseIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertFastRiseSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertFastRiseIsSnoozed", value: false)
             
          }
          if date > UserDefaultsRepository.alertMissedReadingSnoozedTime.value ?? date {
              UserDefaultsRepository.alertMissedReadingSnoozedTime.setNil(key: "alertMissedReadingSnoozedTime")
              UserDefaultsRepository.alertMissedReadingIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertMissedReadingSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertMissedReadingIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertNotLoopingSnoozedTime.value ?? date {
              UserDefaultsRepository.alertNotLoopingSnoozedTime.setNil(key: "alertNotLoopingSnoozedTime")
              UserDefaultsRepository.alertNotLoopingIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertNotLoopingSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertNotLoopingIsSnoozed", value: false)
           
              
          }
          if date > UserDefaultsRepository.alertMissedBolusSnoozedTime.value ?? date {
              UserDefaultsRepository.alertMissedBolusSnoozedTime.setNil(key: "alertMissedBolusSnoozedTime")
              UserDefaultsRepository.alertMissedBolusIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertMissedBolusSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertMissedBolusIsSnoozed", value: false)

          }
          if date > UserDefaultsRepository.alertSAGESnoozedTime.value ?? date {
              UserDefaultsRepository.alertSAGESnoozedTime.setNil(key: "alertSAGESnoozedTime")
              UserDefaultsRepository.alertSAGEIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertSAGESnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertSAGEIsSnoozed", value: false)
    
          }
          if date > UserDefaultsRepository.alertCAGESnoozedTime.value ?? date {
              UserDefaultsRepository.alertCAGESnoozedTime.setNil(key: "alertCAGESnoozedTime")
              UserDefaultsRepository.alertCAGEIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertCAGESnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertCAGEIsSnoozed", value: false)

          }

          
      }
    
}
