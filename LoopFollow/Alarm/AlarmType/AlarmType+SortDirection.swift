//
//  AlarmType+SortDirection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-16.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

// MARK: – Sorting helpers

extension AlarmType {
    /// Asc ⇢ “smaller number = more urgent”,  Desc ⇢ “bigger number = more urgent”
    enum SortDirection { case ascending, descending }

    /// Convenience tuple type
    typealias SortSpec = (direction: SortDirection, key: (Alarm) -> Double?)

    /// The single place that says “sort _this_ type on _that_ field, in _this_ direction”.
    var sortSpec: SortSpec? {
        switch self {
        case .low:
            return (direction: .ascending,
                    key: { $0.belowBG ?? Double.nan })

        case .high:
            return (direction: .descending,
                    key: { $0.aboveBG ?? -Double.infinity })

        case .fastDrop, .fastRise:
            return (direction: .descending,
                    key: { guard let d = $0.delta else { return nil }
                        return abs(d)
                    })

        case .missedReading, .notLooping, .missedBolus, .buildExpire:
            return (direction: .ascending,
                    key: { $0.threshold })

        case .iob, .cob:
            return (direction: .descending,
                    key: { $0.threshold })

        case .sensorChange:
            return (direction: .ascending,
                    key: { $0.threshold })

        default:
            return nil
        }
    }
}
