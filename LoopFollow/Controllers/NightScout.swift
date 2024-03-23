//
//  NightScout.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

extension MainViewController {
    //NS Cage Struct
    struct cageData: Codable {
        var created_at: String
    }

    struct sageData: Codable {
        var created_at: String
    }

    
    //NS Basal Profile Struct
    struct basalProfileStruct: Codable {
        var value: Double
        var time: String
        var timeAsSeconds: Double
    }
    
    struct NSProfile: Decodable {
        struct Store: Decodable {
            struct BasalEntry: Decodable {
                let value: Double
                let time: String
                let timeAsSeconds: Double
            }
            
            let basal: [BasalEntry]
        }
        
        let store: [String: Store]
        let defaultProfile: String
    }
    
    //NS Basal Data  Struct
    struct basalGraphStruct: Codable {
        var basalRate: Double
        var date: TimeInterval
    }
    
    //NS Bolus Data  Struct
    struct bolusGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
    }
    
    //NS Bolus Data  Struct
    struct carbGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
        var absorptionTime: Int
    }
    
    func isStaleData() -> Bool {
        if bgData.count > 0 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let lastReadingTime = bgData.last!.date
            let secondsAgo = now - lastReadingTime
            if secondsAgo >= 20*60 {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
        
    func clearOldTempBasal()
    {
        basalData.removeAll()
        updateBasalGraph()
    }
    
    func clearOldBolus()
    {
        bolusData.removeAll()
        updateBolusGraph()
    }
    
    func clearOldCarb()
    {
        carbData.removeAll()
        updateCarbGraph()
    }
    
    func clearOldBGCheck()
    {
        bgCheckData.removeAll()
        updateBGCheckGraph()
    }
    
    func clearOldOverride()
    {
        overrideGraphData.removeAll()
        updateOverrideGraph()
    }
    
    func clearOldSuspend()
    {
        suspendGraphData.removeAll()
        updateSuspendGraph()
    }
    
    func clearOldResume()
    {
        resumeGraphData.removeAll()
        updateResumeGraph()
    }
    
    func clearOldSensor()
    {
        sensorStartGraphData.removeAll()
        updateSensorStart()
    }
    
    func clearOldNotes()
    {
        noteGraphData.removeAll()
        updateNotes()
    }
}
