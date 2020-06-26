//
//  carbBolusArrays.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/17/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


extension MainViewController {
    
    func findNearestBGbyTime(needle: TimeInterval, haystack: [DataStructs.sgvData], startingIndex: Int) -> (sgv: Double, foundIndex: Int) {
        
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
    
}
