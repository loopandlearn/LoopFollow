// LoopFollow
// Globals.swift

import Foundation

enum globalVariables {
    static var debugLog = ""

    // Graph Settings
    static let dotBG: Float = 3
    static let dotCarb: Float = 5
    static let dotBolus: Float = 5
    static let dotOther: Float = 5

    // Glucose display range (mg/dL)
    // Values at or below the min are shown as "LOW" on the main display;
    // values at or above the max are shown as "HIGH". Also used to clamp
    // prediction values on the graph.
    static let minDisplayGlucose: Int = 39
    static let maxDisplayGlucose: Int = 400
}
