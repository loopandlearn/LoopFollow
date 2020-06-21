//
//  SecondViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/1/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import UserNotifications


class SnoozeViewController: UIViewController {

    var snoozeTabItem: UITabBarItem = UITabBarItem()
    var mainTabItem: UITabBarItem = UITabBarItem()
    
    @IBOutlet weak var SnoozeButton: UIButton!

    @IBOutlet weak var BGLabel: UILabel!
    @IBOutlet weak var DirectionLabel: UILabel!
    @IBOutlet weak var DeltaLabel: UILabel!
    @IBOutlet weak var MinAgoLabel: UILabel!
    @IBOutlet weak var AlertLabel: UILabel!
    
    @IBAction func SnoozeButton(_ sender: UIButton) {
        AlarmSound.stop()
        
        guard let mainVC = self.tabBarController!.viewControllers?[0] as? MainViewController else { return }
        mainVC.startCheckAlarmTimer(time: mainVC.checkAlarmInterval)
        
        let tabBarControllerItems = self.tabBarController?.tabBar.items
        if let arrayOfTabBarItems = tabBarControllerItems as! AnyObject as? NSArray{
            snoozeTabItem = arrayOfTabBarItems[2] as! UITabBarItem
            
        }
        
        
        setSnoozeTime()
        tabBarController?.selectedIndex = 0
        
        snoozeTabItem.isEnabled = false;
        
    }
    
    func updateDisplayWhenTriggered(bgVal: String, directionVal: String, deltaVal: String, minAgoVal: String, alertLabelVal: String){
        loadViewIfNeeded()
        BGLabel.text = bgVal
        DirectionLabel.text = directionVal
        DeltaLabel.text = deltaVal
        MinAgoLabel.text = minAgoVal
        AlertLabel.text = alertLabelVal
        sendNotification(self, bgVal: bgVal, directionVal: directionVal, deltaVal: deltaVal, minAgoVal: minAgoVal, alertLabelVal: alertLabelVal)
    }
    
    func sendNotification(_ sender: Any, bgVal: String, directionVal: String, deltaVal: String, minAgoVal: String, alertLabelVal: String) {
        // 1
        let content = UNMutableNotificationContent()
        content.title = alertLabelVal
        content.subtitle += bgVal + " "
        content.subtitle += directionVal + " "
        content.subtitle += deltaVal
        
        // show this notification 0 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // choose a random identifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // add our notification request
        UNUserNotificationCenter.current().add(request)
        
    }
    
    func setSnoozeTime()
    {
        if AlarmSound.whichAlarm == "Temporary Alert" {
            UserDefaultsRepository.alertTemporaryActive.value = false
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertTemporaryActive", value: false)
        } else if AlarmSound.whichAlarm == "Urgent Low Alert" {
            UserDefaultsRepository.alertUrgentLowIsSnoozed.value = true
            UserDefaultsRepository.alertUrgentLowSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertUrgentLowSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertUrgentLowIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertUrgentLowSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertUrgentLowSnooze.value * 60)))
        } else if AlarmSound.whichAlarm == "Low Alert" {
            UserDefaultsRepository.alertLowIsSnoozed.value = true
            UserDefaultsRepository.alertLowSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertLowSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertLowIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertLowSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertLowSnooze.value * 60)))
        } else if AlarmSound.whichAlarm == "High Alert" {
            UserDefaultsRepository.alertHighIsSnoozed.value = true
            UserDefaultsRepository.alertHighSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertHighSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertHighIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertHighSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertHighSnooze.value * 60)))
        } else if AlarmSound.whichAlarm == "Urgent High Alert" {
            UserDefaultsRepository.alertUrgentHighIsSnoozed.value = true
            UserDefaultsRepository.alertUrgentHighSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertUrgentHighSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertUrgentHighIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertUrgentHighSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertUrgentHighSnooze.value * 60)))
        } else if AlarmSound.whichAlarm == "Fast Drop Alert" {
            UserDefaultsRepository.alertFastDropIsSnoozed.value = true
            UserDefaultsRepository.alertFastDropSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertFastDropSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertFastDropIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertFastDropSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertFastDropSnooze.value * 60)))
        } else if AlarmSound.whichAlarm == "Fast Rise Alert" {
            UserDefaultsRepository.alertFastRiseIsSnoozed.value = true
            UserDefaultsRepository.alertFastRiseSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertFastRiseSnooze.value * 60))
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertFastRiseIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertFastRiseSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertFastRiseSnooze.value * 60)))
        }  else if AlarmSound.whichAlarm == "Missed Reading Alert" {
           UserDefaultsRepository.alertMissedReadingIsSnoozed.value = true
           UserDefaultsRepository.alertMissedReadingSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertMissedReadingSnooze.value * 60))
           guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
           alarms.reloadIsSnoozed(key: "alertMissedReadingIsSnoozed", value: true)
           alarms.reloadSnoozeTime(key: "alertMissedReadingSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertMissedReadingSnooze.value * 60)))
       }  else if AlarmSound.whichAlarm == "Sensor Change Alert" {
                UserDefaultsRepository.alertSAGEIsSnoozed.value = true
                UserDefaultsRepository.alertSAGESnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertSAGESnooze.value * 60 * 60))
                guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
                alarms.reloadIsSnoozed(key: "alertSAGEIsSnoozed", value: true)
                alarms.reloadSnoozeTime(key: "alertSAGESnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertSAGESnooze.value * 60 * 60)))
        } else if AlarmSound.whichAlarm == "Pump Change Alert" {
                       UserDefaultsRepository.alertCAGEIsSnoozed.value = true
                       UserDefaultsRepository.alertCAGESnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertCAGESnooze.value * 60 * 60))
                       guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
                       alarms.reloadIsSnoozed(key: "alertCAGEIsSnoozed", value: true)
                       alarms.reloadSnoozeTime(key: "alertCAGESnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertCAGESnooze.value * 60 * 60)))
       } else if AlarmSound.whichAlarm == "Not Looping Alert" {
                       UserDefaultsRepository.alertNotLoopingIsSnoozed.value = true
                       UserDefaultsRepository.alertNotLoopingSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertNotLoopingSnooze.value * 60))
                       guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
                       alarms.reloadIsSnoozed(key: "alertNotLoopingIsSnoozed", value: true)
                       alarms.reloadSnoozeTime(key: "alertNotLoopingSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertNotLoopingSnooze.value * 60)))
       }
        else if AlarmSound.whichAlarm == "Missed Bolus Alert" {
                        UserDefaultsRepository.alertMissedBolusIsSnoozed.value = true
                        UserDefaultsRepository.alertMissedBolusSnoozedTime.value = Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertMissedBolusSnooze.value * 60))
                        guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
                        alarms.reloadIsSnoozed(key: "alertMissedBolusIsSnoozed", value: true)
                        alarms.reloadSnoozeTime(key: "alertMissedBolusSnoozedTime", setNil: false, value: Date().addingTimeInterval(TimeInterval(UserDefaultsRepository.alertMissedBolusSnooze.value * 60)))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        SnoozeButton.layer.cornerRadius = 5
        SnoozeButton.contentEdgeInsets = UIEdgeInsets(top: 10,left: 10,bottom: 10,right: 10)
        
    }


}
