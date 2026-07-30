// LoopFollow
// EndoReportConfig.swift

import UIKit

struct EndoReportConfig {
    let patientName: String
    let dateOfBirth: String
    let diagnosisDate: String
    let providerName: String
    let insulinType: String
    let aidSystem: String
    let pumpDevice: String
    let cgmDevice: String
    let carbRatio: String
    let isf: String
    let basalRate: String
    let targetGlucose: String
    let units: String
    let accentColorHex: String
    let notes: String
    let includeGlucoseSummary: Bool
    let includeInsulin: Bool
    let includeNutrition: Bool
    let includeTherapySettings: Bool
    let includeDevices: Bool
    let includeAGP: Bool
    let includeDailyBreakdown: Bool
    let includeFatProtein: Bool
    let startDate: Date
    let endDate: Date

    var accentColor: UIColor {
        UIColor(hex: accentColorHex) ?? UIColor(red: 0.137, green: 0.624, blue: 0.675, alpha: 1)
    }

    var isMMOL: Bool { units == "mmol/L" }
    func convert(_ mgdl: Double) -> Double { isMMOL ? mgdl * 0.0555 : mgdl }
    func fmtBG(_ mgdl: Double) -> String {
        isMMOL ? String(format: "%.1f", mgdl * 0.0555) : String(format: "%.0f", mgdl)
    }
}
