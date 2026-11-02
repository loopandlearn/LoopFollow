// LoopFollow
// HistoryCurvePlacement.swift

/// Where the device status history curves (IOB, COB, sensitivity ratio) are drawn.
enum HistoryCurvePlacement: String, CaseIterable, Codable {
    /// Each curve in its own graph under the main graph, with its own axis.
    case separate
    /// All curves in the bottom band of the main graph, each scaled to its own range.
    case mainGraph

    var displayName: String {
        switch self {
        case .separate: return "Separate Graphs"
        case .mainGraph: return "In Main Graph"
        }
    }
}
