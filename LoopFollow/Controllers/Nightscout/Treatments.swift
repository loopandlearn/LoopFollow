//
//  Treatments.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Treatments Web Call
    // Downloads Basal, Bolus, Carbs, BG Check, Notes, Overrides
    func WebLoadNSTreatments() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: Treatments") }
        if !UserDefaultsRepository.downloadTreatments.value { return }
        
        let startTimeString = dateTimeUtils.getDateTimeString(addingDays: -1 * UserDefaultsRepository.downloadDays.value)
        let currentTimeString = dateTimeUtils.getDateTimeString(addingHours: 6)
        let parameters: [String: String] = [
            "find[created_at][$gte]": startTimeString,
            "find[created_at][$lte]": currentTimeString
        ]
        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: parameters) { (result: Result<Any, Error>) in
            switch result {
            case .success(let data):
                if let entries = data as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.updateTreatments(entries: entries)
                    }
                } else {
                    print("Error: Unexpected data structure")
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Process and split out treatments to individual tasks
    func updateTreatments(entries: [[String:AnyObject]]) {
        
        var tempBasal: [[String:AnyObject]] = []
        var bolus: [[String:AnyObject]] = []
        var carbs: [[String:AnyObject]] = []
        var temporaryOverride: [[String:AnyObject]] = []
        var note: [[String:AnyObject]] = []
        var bgCheck: [[String:AnyObject]] = []
        var suspendPump: [[String:AnyObject]] = []
        var resumePump: [[String:AnyObject]] = []
        var pumpSiteChange: [cageData] = []
        var cgmSensorStart: [sageData] = []
        
        for i in 0..<entries.count {
            let entry = entries[i] as [String : AnyObject]?
            switch entry?["eventType"] as! String {
            case "Temp Basal":
                tempBasal.append(entry!)
            case "Correction Bolus":
                bolus.append(entry!)
            case "Bolus":
                bolus.append(entry!)
            case "SMB":
                bolus.append(entry!)
            case "Meal Bolus":
                carbs.append(entry!)
                bolus.append(entry!)
            case "Carb Correction":
                carbs.append(entry!)
            case "Temporary Override":
                temporaryOverride.append(entry!)
            case "Temporary Target":
                temporaryOverride.append(entry!)
            case "Note":
                note.append(entry!)
                print("Note: \(String(describing: entry))")
            case "BG Check":
                bgCheck.append(entry!)
            case "Suspend Pump":
                suspendPump.append(entry!)
            case "Resume Pump":
                resumePump.append(entry!)
            case "Pump Site Change", "Site Change":
                if let createdAt = entry?["created_at"] as? String {
                    let newEntry = cageData(created_at: createdAt)
                    pumpSiteChange.append(newEntry)
                }
            case "Sensor Start":
                if let createdAt = entry?["created_at"] as? String {
                    let newEntry = sageData(created_at: createdAt)
                    cgmSensorStart.append(newEntry)
                }
            default:
                print("No Match: \(String(describing: entry))")
            }
        }
        
        if tempBasal.count > 0 {
            processNSBasals(entries: tempBasal)
        } else {
            if basalData.count < 0 {
                clearOldTempBasal()
            }
        }
        if bolus.count > 0 {
            processNSBolus(entries: bolus)
        } else {
            if bolusData.count > 0 {
                clearOldBolus()
            }
        }
        updateTodaysCarbsFromEntries(entries: carbs)
        if carbs.count > 0 {
            processNSCarbs(entries: carbs)
        } else {
            if carbData.count > 0 {
                clearOldCarb()
            }
        }
        if bgCheck.count > 0 {
            processNSBGCheck(entries: bgCheck)
        } else {
            if bgCheckData.count > 0 {
                clearOldBGCheck()
            }
        }
        if temporaryOverride.count > 0 {
            processNSOverrides(entries: temporaryOverride)
        } else {
            if overrideGraphData.count > 0 {
                clearOldOverride()
            }
        }
        if suspendPump.count > 0 {
            processSuspendPump(entries: suspendPump)
        } else {
            if suspendGraphData.count > 0 {
                clearOldSuspend()
            }
        }
        if resumePump.count > 0 {
            processResumePump(entries: resumePump)
        } else {
            if resumeGraphData.count > 0 {
                clearOldResume()
            }
        }
        processSage(entries: cgmSensorStart)
        if cgmSensorStart.count > 0 {
            processSensorStart(entries: cgmSensorStart)
        } else {
            if sensorStartGraphData.count > 0 {
                clearOldSensor()
            }
        }
        if note.count > 0 {
            processNotes(entries: note)
        } else {
            if noteGraphData.count > 0 {
                clearOldNotes()
            }
        }
        processCage(entries: pumpSiteChange)
    }
}
