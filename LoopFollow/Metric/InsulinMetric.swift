// LoopFollow
// InsulinMetric.swift
// Created by Jonas Björkert on 2024-07-18.

import Foundation

class InsulinMetric: Metric {
    init?(from dictionary: [String: AnyObject], key: String) {
        guard let value = dictionary[key] as? Double else {
            return nil
        }
        super.init(value: value, maxFractionDigits: 2, minFractionDigits: 0)
    }

    init?(from object: AnyObject?, key: String) {
        guard let dictionary = object as? [String: AnyObject], let value = dictionary[key] as? Double else {
            return nil
        }
        super.init(value: value, maxFractionDigits: 2, minFractionDigits: 0)
    }
}
