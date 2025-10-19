// LoopFollow
// InsulinFormatter.swift

import Foundation
import HealthKit

final class InsulinFormatter {
    static let shared = InsulinFormatter()
    private let precision = InsulinPrecisionManager.shared
    private init() {}

    func string(_ q: HKQuantity) -> String {
        string(q.doubleValue(for: .internationalUnit()))
    }

    func string(_ units: Double) -> String {
        let fd = precision.fractionDigits
        let nf = NumberFormatter()
        nf.minimumFractionDigits = fd
        nf.maximumFractionDigits = fd
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: units)) ?? String(format: "%.\(fd)f", units)
    }
}
