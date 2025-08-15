// LoopFollow
// Metric.swift

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
