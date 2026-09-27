// LoopFollow
// PredictionDisplayType.swift

enum PredictionDisplayType: String, CaseIterable, Codable {
    case cone
    case lines

    var displayName: String {
        switch self {
        case .cone: return String(localized: "Cone", comment: "Prediction display style")
        case .lines: return String(localized: "Lines", comment: "Prediction display style")
        }
    }
}
