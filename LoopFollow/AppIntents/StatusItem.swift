// LoopFollow
// StatusItem.swift

import AppIntents

/// The values a user can ask Siri for by name.
enum StatusItem: String, AppEnum {
    case glucose, delta, iob, cob, basal, predictedGlucose
    case pumpReservoir, pumpBattery, phoneBattery
    case sensorAge, cannulaAge, insulinAge
    case override, tempTarget, profile, lastLoop
    case carbsToday, totalDailyDose, recommendedBolus, alarms

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Status Item")

    static var caseDisplayRepresentations: [StatusItem: DisplayRepresentation] = [
        .glucose: DisplayRepresentation(title: "glucose", synonyms: ["blood sugar", "BG", "blood glucose"]),
        .delta: DisplayRepresentation(title: "delta", synonyms: ["glucose change"]),
        .iob: DisplayRepresentation(title: "IOB", synonyms: ["insulin on board", "active insulin"]),
        .cob: DisplayRepresentation(title: "COB", synonyms: ["carbs on board", "active carbs"]),
        .basal: DisplayRepresentation(title: "basal rate", synonyms: ["basal"]),
        .predictedGlucose: DisplayRepresentation(title: "predicted glucose", synonyms: ["eventual glucose", "projected glucose"]),
        .pumpReservoir: DisplayRepresentation(title: "pump reservoir", synonyms: ["reservoir", "pump insulin"]),
        .pumpBattery: DisplayRepresentation(title: "pump battery"),
        .phoneBattery: DisplayRepresentation(title: "phone battery", synonyms: ["looping phone battery", "uploader battery"]),
        .sensorAge: DisplayRepresentation(title: "sensor age", synonyms: ["SAGE"]),
        .cannulaAge: DisplayRepresentation(title: "cannula age", synonyms: ["CAGE", "pod age"]),
        .insulinAge: DisplayRepresentation(title: "insulin age", synonyms: ["IAGE"]),
        .override: DisplayRepresentation(title: "override", synonyms: ["active override"]),
        .tempTarget: DisplayRepresentation(title: "temp target", synonyms: ["temporary target"]),
        .profile: DisplayRepresentation(title: "profile", synonyms: ["active profile"]),
        .lastLoop: DisplayRepresentation(title: "last loop", synonyms: ["loop status"]),
        .carbsToday: DisplayRepresentation(title: "carbs today"),
        .totalDailyDose: DisplayRepresentation(title: "total daily dose", synonyms: ["TDD"]),
        .recommendedBolus: DisplayRepresentation(title: "recommended bolus"),
        .alarms: DisplayRepresentation(title: "alarm status", synonyms: ["alarms", "snooze status"]),
    ]

    var field: StatusField {
        switch self {
        case .glucose: return .glucose
        case .delta: return .delta
        case .iob: return .iob
        case .cob: return .cob
        case .basal: return .basal
        case .predictedGlucose: return .predictedGlucose
        case .pumpReservoir: return .pumpReservoir
        case .pumpBattery: return .pumpBattery
        case .phoneBattery: return .phoneBattery
        case .sensorAge: return .sensorAge
        case .cannulaAge: return .cannulaAge
        case .insulinAge: return .insulinAge
        case .override: return .override
        case .tempTarget: return .tempTarget
        case .profile: return .profile
        case .lastLoop: return .lastLoop
        case .carbsToday: return .carbsToday
        case .totalDailyDose: return .totalDailyDose
        case .recommendedBolus: return .recommendedBolus
        case .alarms: return .alarms
        }
    }
}
