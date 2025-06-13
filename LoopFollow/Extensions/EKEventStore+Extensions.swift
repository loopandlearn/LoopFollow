// LoopFollow
// EKEventStore+Extensions.swift
// Created by Jonas Björkert on 2023-07-27.

import EventKit
import Foundation

#if swift(>=5.9)
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
#else
    extension EKEventStore {
        func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
            requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }
#endif
