// LoopFollow
// InsulinPrecisionManager.swift

import Combine
import Foundation
import HealthKit

final class InsulinPrecisionManager: ObservableObject {
    static let shared = InsulinPrecisionManager()

    @Published private(set) var fractionDigits: Int = 3
    private var cancellables = Set<AnyCancellable>()

    private init() {
        fractionDigits = Self.computeDigits(from: Storage.shared.bolusIncrement.value)

        Storage.shared.bolusIncrement.$value
            .map(Self.computeDigits(from:))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$fractionDigits)
    }

    private static func computeDigits(from q: HKQuantity) -> Int {
        let step = max(0.001, q.doubleValue(for: .internationalUnit()))
        if step >= 1 { return 0 }
        var v = step
        var d = 0
        while d < 6 && abs(round(v) - v) > 1e-10 {
            v *= 10; d += 1
        }
        return min(max(d, 0), 5)
    }
}
