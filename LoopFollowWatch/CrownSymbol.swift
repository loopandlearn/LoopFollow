// LoopFollow
// CrownSymbol.swift

import WatchKit

enum CrownSymbol {
    /// The crown symbol turning the way that raises a value, for the wrist the watch is worn on.
    static var increase: String {
        WKInterfaceDevice.current().wristLocation == .left ? "digitalcrown.arrow.clockwise" : "digitalcrown.arrow.counterclockwise"
    }
}
