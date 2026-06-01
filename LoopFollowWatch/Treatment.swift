// LoopFollow
// Treatment.swift

import Foundation

struct Treatment: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: TreatmentType
    let value: Double // insulin units or carb grams

    enum TreatmentType {
        case bolus, smb, carbs
    }
}

struct TempTargetEntry: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let targetTop: Double
    let targetBottom: Double
    let reason: String
}

struct OverrideEntry: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let percentage: Double?
    let name: String
}
