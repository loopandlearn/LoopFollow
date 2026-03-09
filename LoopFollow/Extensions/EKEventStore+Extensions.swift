// LoopFollow
// EKEventStore+Extensions.swift

import EventKit
import Foundation

extension EKEventStore {
    func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17, *) {
            requestFullAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }
}
