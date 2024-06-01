//
//  ShareClientExtension.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/13/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import ShareClient

public struct ShareGlucoseData: Decodable {
    var sgv: Int
    var date: TimeInterval
    var direction: String?

    enum CodingKeys: String, CodingKey {
        case sgv  // Sensor Blood Glucose
        case mbg  // Manual Blood Glucose
        case glucose  // Other type of entry
        case date
        case direction
    }

    // Decoder initializer for handling JSON data
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let glucoseValue = try? container.decode(Double.self, forKey: .sgv) {
            sgv = Int(glucoseValue.rounded())
        } else if let mbgValue = try? container.decode(Double.self, forKey: .mbg) {
            sgv = Int(mbgValue.rounded())
        } else if let mbgValue = try? container.decode(Double.self, forKey: .glucose) {
            sgv = Int(mbgValue.rounded())
        } else {
            throw DecodingError.dataCorruptedError(forKey: .sgv, in: container, debugDescription: "Expected to decode Double for sgv, mbg or glucose.")
        }
    
        // Decode the date and optional direction
        date = try container.decode(TimeInterval.self, forKey: .date)
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
    }

    public init(sgv: Int, date: TimeInterval, direction: String?) {
        self.sgv = sgv
        self.date = date
        self.direction = direction
    }
}

private var TrendTable: [String] = [
   "NONE",             // 0
   "DoubleUp",         // 1
   "SingleUp",         // 2
   "FortyFiveUp",      // 3
   "Flat",             // 4
   "FortyFiveDown",    // 5
   "SingleDown",       // 6
   "DoubleDown",       // 7
   "NOT COMPUTABLE",   // 8
   "RATE OUT OF RANGE" // 9
]

// TODO: probably better to make this an inherited class rather than an extension
extension ShareClient {

    public func fetchData(_ entries: Int, callback: @escaping (ShareError?, [ShareGlucoseData]?) -> Void) {
        
        self.fetchLast(entries) { (error, result) -> () in
            guard error == nil || result != nil else {
                return callback(error, nil)
            }
            
            // parse data to conanical form
            var shareData = [ShareGlucoseData]()
            for i in 0..<result!.count {
                
                var trend = Int(result![i].trend)
                if(trend < 0 || trend > TrendTable.count-1) {
                    trend = 0
                }
            
                let newShareData = ShareGlucoseData(
                    sgv: Int(result![i].glucose),
                    date: result![i].timestamp.timeIntervalSince1970,
                    direction: TrendTable[trend]
                )
                shareData.append(newShareData)
            }
            callback(nil,shareData)
         }
    }
}
