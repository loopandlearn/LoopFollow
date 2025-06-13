// LoopFollow
// ShareClientExtension.swift
// Created by Jose Paredes on 2020-07-14.

import Foundation
import ShareClient

public struct ShareGlucoseData: Decodable {
    var sgv: Int
    var date: TimeInterval
    var direction: String?

    enum CodingKeys: String, CodingKey {
        case sgv // Sensor Blood Glucose
        case mbg // Manual Blood Glucose
        case glucose // Other type of entry
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
    "NONE", // 0
    "DoubleUp", // 1
    "SingleUp", // 2
    "FortyFiveUp", // 3
    "Flat", // 4
    "FortyFiveDown", // 5
    "SingleDown", // 6
    "DoubleDown", // 7
    "NOT COMPUTABLE", // 8
    "RATE OUT OF RANGE", // 9
]

// TODO: probably better to make this an inherited class rather than an extension
public extension ShareClient {
    func fetchData(_ entries: Int, callback: @escaping (ShareError?, [ShareGlucoseData]?) -> Void) {
        fetchLast(entries) { error, result in
            guard error == nil, let result = result else {
                return callback(error ?? .fetchError, nil)
            }

            // parse data to conanical form
            var shareData = [ShareGlucoseData]()
            for item in result {
                var trend = Int(item.trend)
                if trend < 0 || trend >= TrendTable.count {
                    trend = 0
                }

                let newShareData = ShareGlucoseData(
                    sgv: Int(item.glucose),
                    date: item.timestamp.timeIntervalSince1970,
                    direction: TrendTable[trend]
                )
                shareData.append(newShareData)
            }
            callback(nil, shareData)
        }
    }
}
