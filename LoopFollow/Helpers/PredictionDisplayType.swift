// LoopFollow
// PredictionDisplayType.swift

enum PredictionDisplayType: String, CaseIterable, Codable {
    case cone
    case lines

    var displayName: String {
        switch self {
        case .cone: return "Cone"
        case .lines: return "Lines"
        }
    }
}
