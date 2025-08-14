// LoopFollow
// BinaryFloatingPoint+localized.swift

import Foundation

extension BinaryFloatingPoint {
    func localized(maxFractionDigits: Int) -> String {
        let style = FloatingPointFormatStyle<Self>()
            .precision(.fractionLength(0 ... maxFractionDigits))
        return style.format(self)
    }
}
