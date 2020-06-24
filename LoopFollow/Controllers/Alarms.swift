//
//  Alarms.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import AVFoundation

extension MainViewController {
    
    
    func checkAlarms(bgs: [DataStructs.sgvData]) {
           print("ALARMS --- Checking")
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
                       if Float(currentBG) < UserDefaultsRepository.alertTemporaryBG.value {
                           UserDefaultsRepository.alertTemporaryActive.value = false
                           AlarmSound.whichAlarm = "Temporary Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                           return
                       }
                   } else{
                       if Float(currentBG) > UserDefaultsRepository.alertTemporaryBG.value {
                         tabBarController?.selectedIndex = 2
                           AlarmSound.whichAlarm = "Temporary Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                           return
                      }
                   }
               }
               
               // Check Urgent Low
               if UserDefaultsRepository.alertUrgentLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
               Float(currentBG) <= UserDefaultsRepository.alertUrgentLowBG.value {
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
               Float(currentBG) <= UserDefaultsRepository.alertLowBG.value && !UserDefaultsRepository.alertLowIsSnoozed.value {
                   AlarmSound.whichAlarm = "Low Alert"
                   triggerAlarm(sound: UserDefaultsRepository.alertLowSound.value, snooozedBGReadingTime: currentBGTime)
                   return
               }
               
               // Check Urgent High
               if UserDefaultsRepository.alertUrgentHighActive.value && !UserDefaultsRepository.alertUrgentHighIsSnoozed.value &&
               Float(currentBG) >= UserDefaultsRepository.alertUrgentHighBG.value {
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
                   Float(currentBG) >= UserDefaultsRepository.alertHighBG.value &&
                   Float(persistentBG) >= UserDefaultsRepository.alertHighBG.value &&
                   !UserDefaultsRepository.alertHighIsSnoozed.value {
                       AlarmSound.whichAlarm = "High Alert"
                       triggerAlarm(sound: UserDefaultsRepository.alertHighSound.value, snooozedBGReadingTime: currentBGTime)
                       return
               }
               
               
               
               // Check Fast Drop
               if UserDefaultsRepository.alertFastDropActive.value && !UserDefaultsRepository.alertFastDropIsSnoozed.value {
                   // make sure limit is off or BG is below value
                   if (!UserDefaultsRepository.alertFastDropUseLimit.value) || (UserDefaultsRepository.alertFastDropUseLimit.value && Float(currentBG) < UserDefaultsRepository.alertFastDropBelowBG.value) {
                       let compare = 0 - UserDefaultsRepository.alertFastDropDelta.value
                       
                       //check last 2/3/4 readings
                       if (UserDefaultsRepository.alertFastDropReadings.value == 2 && Float(deltas[0]) <= compare)
                       || (UserDefaultsRepository.alertFastDropReadings.value == 3 && Float(deltas[0]) <= compare && Float(deltas[1]) <= compare)
                       || (UserDefaultsRepository.alertFastDropReadings.value == 4 && Float(deltas[0]) <= compare && Float(deltas[1]) <= compare && Float(deltas[2]) <= compare) {
                           AlarmSound.whichAlarm = "Fast Drop Alert"
                           triggerAlarm(sound: UserDefaultsRepository.alertFastDropSound.value, snooozedBGReadingTime: currentBGTime)
                           return
                       }
                   }
               }
               
               // Check Fast Rise
               if UserDefaultsRepository.alertFastRiseActive.value && !UserDefaultsRepository.alertFastRiseIsSnoozed.value {
                   // make sure limit is off or BG is above value
                   if (!UserDefaultsRepository.alertFastRiseUseLimit.value) || (UserDefaultsRepository.alertFastRiseUseLimit.value && Float(currentBG) > UserDefaultsRepository.alertFastRiseAboveBG.value) {
                       let compare = UserDefaultsRepository.alertFastDropDelta.value
                       
                       //check last 2/3/4 readings
                       if (UserDefaultsRepository.alertFastRiseReadings.value == 2 && Float(deltas[0]) >= compare)
                       || (UserDefaultsRepository.alertFastRiseReadings.value == 3 && Float(deltas[0]) >= compare && Float(deltas[1]) >= compare)
                       || (UserDefaultsRepository.alertFastRiseReadings.value == 4 && Float(deltas[0]) >= compare && Float(deltas[1]) >= compare && Float(deltas[2]) >= compare) {
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
            && (Double(dateTimeUtils.getNowTimeIntervalUTC() - UserDefaultsRepository.alertLastLoopTime.value) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
               && UserDefaultsRepository.alertLastLoopTime.value > 0 {
               
               var trigger = true
               if (UserDefaultsRepository.alertNotLoopingUseLimits.value
                   && (
                       (Float(currentBG) <= UserDefaultsRepository.alertNotLoopingUpperLimit.value
                       && Float(currentBG) >= UserDefaultsRepository.alertNotLoopingLowerLimit.value) ||
                       // Ignore Limits if BG reading is older than non looping time
                       (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
                   ) ||
                   !UserDefaultsRepository.alertNotLoopingUseLimits.value) {
                       AlarmSound.whichAlarm = "Not Looping Alert"
                       triggerAlarm(sound: UserDefaultsRepository.alertNotLoopingSound.value, snooozedBGReadingTime: nil)
                       return
               }
           }
        
        // check for missed bolus - Only checks within 1 hour of carb entry
        // Only continue if alert is active, not snooozed, we have carb data, and bg is over the ignore limit
        if UserDefaultsRepository.alertMissedBolusActive.value
        && !UserDefaultsRepository.alertMissedBolusIsSnoozed.value
        && carbData.count > 0
        && Float(currentBG) > UserDefaultsRepository.alertMissedBolusLowGramsBG.value {
            
            // Grab the latest carb entry
            let lastCarb = carbData[carbData.count - 1].value
            let lastCarbTime = carbData[carbData.count - 1].date
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            
            //Make sure carb entry is newer than 1 hour, has reached the time length, and is over the ignore limit
            if lastCarbTime > (now - (60 * 60))
            && lastCarbTime < (now - Double((UserDefaultsRepository.alertMissedBolus.value * 60)))
            && lastCarb > Double(UserDefaultsRepository.alertMissedBolusLowGrams.value) {
                
                // There is a current carb but no boluses data at all
                if bolusData.count < 1 {
                    AlarmSound.whichAlarm = "Missed Bolus Alert"
                    triggerAlarm(sound: UserDefaultsRepository.alertMissedBolusSound.value, snooozedBGReadingTime: nil)
                    return
                }
                
                // Get the latest bolus over the small bolus exclusion
                // Start with 0.0 bolus assuming there isn't one to cause a trigger and only add one if found
                var lastBolus = 0.0
                var lastBolusTime = 0.0
                var i = 1
                // check the boluses in reverse order setting it only if the time is after the carb time minus prebolus time.
                // This will make the loop stop at the most recent bolus that is over the minimum value or continue through all boluses
                while lastBolus < UserDefaultsRepository.alertMissedBolusIgnoreBolus.value {
                    // Set the bolus if it's after the carb time minus prebolus time
                    if (bolusData[bolusData.count - i].date >= lastCarbTime - Double(UserDefaultsRepository.alertMissedBolusPrebolus.value * 60)) {
                        lastBolus = bolusData[bolusData.count - i].value
                        lastBolusTime = bolusData[bolusData.count - i].date
                    }
                    i += 1
                }
                
                // This will trigger is no boluses were set above
                if (lastBolus == 0.0) {
                    AlarmSound.whichAlarm = "Missed Bolus Alert"
                    triggerAlarm(sound: UserDefaultsRepository.alertMissedBolusSound.value, snooozedBGReadingTime: nil)
                    return
                }
                    
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
        snoozer.updateDisplayWhenTriggered(bgVal: bgUnits.toDisplayUnits(String(bgData[bgData.count - 1].sgv)), directionVal: latestDirectionString ?? "", deltaVal: bgUnits.toDisplayUnits(latestDeltaString) ?? "", minAgoVal: latestMinAgoString ?? "", alertLabelVal: AlarmSound.whichAlarm)
        //snoozeTabItem.isEnabled = true;
        snoozer.SnoozeButton.isHidden = false
        snoozer.AlertLabel.isHidden = false
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
    
    func speakBG(sgv: Int) {
           var speechSynthesizer = AVSpeechSynthesizer()
           var speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: "Current BG is " + bgUnits.toDisplayUnits(String(sgv)))
           speechUtterance.rate = AVSpeechUtteranceMaximumSpeechRate / 2
           speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
           speechSynthesizer.speak(speechUtterance)
       }
    
}
