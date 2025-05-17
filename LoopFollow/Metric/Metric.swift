// LoopFollow
// Metric.swift
// Created by Jonas Björkert on 2024-07-18.

import Foundation

class Metric {
    var value: Double
    var maxFractionDigits: Int
    var minFractionDigits: Int

    init(value: Double, maxFractionDigits: Int, minFractionDigits: Int) {
        self.value = value
        self.maxFractionDigits = maxFractionDigits
        self.minFractionDigits = minFractionDigits
    }

    func formattedValue() -> String {
        return Localizer.formatToLocalizedString(value, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
    }
}
