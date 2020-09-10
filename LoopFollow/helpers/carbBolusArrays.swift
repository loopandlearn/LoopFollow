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
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. Put the dot at 100
            if i == haystack.count - 1 { return (100.00, 0) }
            
            if needle >= haystack[i].date && needle < haystack[i + 1].date {
                return (Double(haystack[i].sgv), i)
            }
        }
        
        return (100.00, 0)
    }
    
    
    func findNearestBolusbyTime(needle: TimeInterval, haystack: [bolusGraphStruct], startingIndex: Int) -> (offset: Bool, foundIndex: Int) {
        
        // If we can't find a match or things fail, put it at 100 BG
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. return 0
            let timeDiff = needle - haystack[i].date
            if timeDiff <= 300 && timeDiff >= -300 { return (true, i)}
            
            if i == haystack.count - 1 { return (false, 0) }
            if timeDiff < -300 { return (false, 0)}
            
        }
        
        return (false, 0 )
    }
    
}
