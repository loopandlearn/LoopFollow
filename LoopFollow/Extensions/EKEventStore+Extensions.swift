// LoopFollow
// EKEventStore+Extensions.swift

import EventKit
import Foundation

extension EKEventStore {
    func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
        requestFullAccessToEvents { granted, error in
            completion(granted, error)
        }
    }
}
