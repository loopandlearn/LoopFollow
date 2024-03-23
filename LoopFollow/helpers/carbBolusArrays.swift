//
//  carbBolusArrays.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/17/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


extension MainViewController {
    
    func findNearestBGbyTime(needle: TimeInterval, haystack: [ShareGlucoseData], startingIndex: Int) -> (sgv: Double, foundIndex: Int) {
        
        // If we can't find a match or things fail, put it at 100 BG
        if startingIndex > haystack.count { return (100.00, 0) }
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. Put the dot at 100
            if i == haystack.count - 1 { return (100.00, 0) }
            
            if needle >= haystack[i].date && needle < haystack[i + 1].date {
                return (Double(haystack[i].sgv), i)
            }
        }
        
        return (100.00, 0)
    }
    
    
    func findNearestBolusbyTime(timeWithin: Int, needle: TimeInterval, haystack: [bolusGraphStruct], startingIndex: Int) -> (offset: Bool, foundIndex: Int) {
        
        // If we can't find a match or things fail, put it at 100 BG
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. return 0
            let timeDiff = needle - haystack[i].date
            if timeDiff <= Double(timeWithin) && timeDiff >= Double(-timeWithin) { return (true, i)}
            
            if i == haystack.count - 1 { return (false, 0) }
            if timeDiff < Double(-timeWithin) { return (false, 0)}
            
        }
        
        return (false, 0 )
    }
    
    func findNearestSmbbyTime(timeWithin: Int, needle: TimeInterval, haystack: [smbGraphStruct], startingIndex: Int) -> (offset: Bool, foundIndex: Int) {
        
        // If we can't find a match or things fail, put it at 100 BG
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. return 0
            let timeDiff = needle - haystack[i].date
            if timeDiff <= Double(timeWithin) && timeDiff >= Double(-timeWithin) { return (true, i)}
            
            if i == haystack.count - 1 { return (false, 0) }
            if timeDiff < Double(-timeWithin) { return (false, 0)}
            
        }
        
        return (false, 0 )
    }
    
    func findNextCarbTime(timeWithin: Int, needle: TimeInterval, haystack: [carbGraphStruct], startingIndex: Int) -> Bool {
        
        if startingIndex > haystack.count - 2 { return false }
        if haystack[startingIndex + 1].date -  needle < Double(timeWithin) {
            return true
        }

        return false
    }
    
    func findNextBolusTime(timeWithin: Int, needle: TimeInterval, haystack: [bolusGraphStruct], startingIndex: Int) -> Bool {
        
        var last = false
        var next = true
        if startingIndex > haystack.count - 2 { return false }
        if startingIndex == 0 { return false }
        
        // Nothing to right that requires shift
        if haystack[startingIndex + 1].date -  needle > Double(timeWithin) {
            return false
        } else {
            // Nothing to left preventing shift
            if needle - haystack[startingIndex - 1].date > Double(timeWithin) {
                return true
            }
        }
        
        return false
    }
    
    func findNextSmbTime(timeWithin: Int, needle: TimeInterval, haystack: [smbGraphStruct], startingIndex: Int) -> Bool {
        
        var last = false
        var next = true
        if startingIndex > haystack.count - 2 { return false }
        if startingIndex == 0 { return false }
        
        // Nothing to right that requires shift
        if haystack[startingIndex + 1].date -  needle > Double(timeWithin) {
            return false
        } else {
            // Nothing to left preventing shift
            if needle - haystack[startingIndex - 1].date > Double(timeWithin) {
                return true
            }
        }
        
        return false
    }
    
}
