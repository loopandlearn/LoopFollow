// LoopFollow
// LAAppGroupSettings.swift

import Foundation

// MARK: - Slot option enum

/// One displayable metric that can occupy a slot in the Live Activity 2×2 grid.
///
/// - `.none` is the empty/blank state — leaves the slot visually empty.
/// - Optional cases (isOptional == true) may display "—" for Dexcom-only users
///   whose setup does not provide that metric.
/// - All values are read from GlucoseSnapshot at render time inside the widget
///   extension; no additional App Group reads are required per slot.
enum LiveActivitySlotOption: String, CaseIterable, Codable {
    // Core glucose
    case none
    case delta
    case projectedBG
    case minMax
    // Loop metrics
    case iob
    case cob
    case recBolus
    case autosens
    case tdd
    // Pump / device
    case basal
    case pump
    case pumpBattery
    case battery
    case target
    case isf
    case carbRatio
    // Ages
    case sage
    case cage
    case iage
    // Other
    case carbsToday
    case override
    case profile

    /// Human-readable label shown in the slot picker in Settings.
    var displayName: String {
        switch self {
        case .none: "Empty"
        case .delta: "Delta"
        case .projectedBG: "Projected BG"
        case .minMax: "Min/Max"
        case .iob: "IOB"
        case .cob: "COB"
        case .recBolus: "Rec. Bolus"
        case .autosens: "Autosens"
        case .tdd: "TDD"
        case .basal: "Basal"
        case .pump: "Pump"
        case .pumpBattery: "Pump Battery"
        case .battery: "Battery"
        case .target: "Target"
        case .isf: "ISF"
        case .carbRatio: "CR"
        case .sage: "SAGE"
        case .cage: "CAGE"
        case .iage: "IAGE"
        case .carbsToday: "Carbs today"
        case .override: "Override"
        case .profile: "Profile"
        }
    }

    /// Short label used inside the MetricBlock on the Live Activity card.
    var gridLabel: String {
        switch self {
        case .none: ""
        case .delta: "Delta"
        case .projectedBG: "Proj"
        case .minMax: "Min/Max"
        case .iob: "IOB"
        case .cob: "COB"
        case .recBolus: "Rec."
        case .autosens: "Sens"
        case .tdd: "TDD"
        case .basal: "Basal"
        case .pump: "Pump"
        case .pumpBattery: "Pump%"
        case .battery: "Bat."
        case .target: "Target"
        case .isf: "ISF"
        case .carbRatio: "CR"
        case .sage: "SAGE"
        case .cage: "CAGE"
        case .iage: "IAGE"
        case .carbsToday: "Carbs"
        case .override: "Ovrd"
        case .profile: "Prof"
        }
    }

    /// True when the value is a glucose measurement and should be followed by
    /// the user's preferred unit label (mg/dL or mmol/L) in compact displays.
    var isGlucoseUnit: Bool {
        switch self {
        case .projectedBG, .delta, .minMax, .target, .isf: return true
        default: return false
        }
    }

    /// True when the underlying value may be nil (e.g. Dexcom-only users who have
    /// no Loop data). The widget renders "—" in those cases.
    var isOptional: Bool {
        switch self {
        case .none, .delta: false
        default: true
        }
    }
}

// MARK: - Default slot assignments

enum LiveActivitySlotDefaults {
    /// Top-left slot
    static let slot1: LiveActivitySlotOption = .iob
    /// Bottom-left slot
    static let slot2: LiveActivitySlotOption = .cob
    /// Top-right slot
    static let slot3: LiveActivitySlotOption = .projectedBG
    /// Bottom-right slot — intentionally empty until the user configures it
    static let slot4: LiveActivitySlotOption = .none
    /// Small widget (CarPlay / Watch Smart Stack) right slot
    static let smallWidgetSlot: LiveActivitySlotOption = .projectedBG

    static var all: [LiveActivitySlotOption] {
        [slot1, slot2, slot3, slot4]
    }
}

// MARK: - App Group settings

/// Minimal App Group settings needed by the Live Activity UI.
///
/// We keep this separate from Storage.shared to avoid target-coupling and
/// ensure the widget extension reads the same values as the app.
enum LAAppGroupSettings {
    private enum Keys {
        static let lowLineMgdl = "la.lowLine.mgdl"
        static let highLineMgdl = "la.highLine.mgdl"
        static let slots = "la.slots"
        static let smallWidgetSlot = "la.smallWidgetSlot"
        static let displayName = "la.displayName"
        static let showDisplayName = "la.showDisplayName"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupID.current())
    }

    // MARK: - Thresholds (Write)

    static func setThresholds(lowMgdl: Double, highMgdl: Double) {
        defaults?.set(lowMgdl, forKey: Keys.lowLineMgdl)
        defaults?.set(highMgdl, forKey: Keys.highLineMgdl)
    }

    // MARK: - Thresholds (Read)

    static func thresholdsMgdl(fallbackLow: Double = 70, fallbackHigh: Double = 180) -> (low: Double, high: Double) {
        let low = defaults?.object(forKey: Keys.lowLineMgdl) as? Double ?? fallbackLow
        let high = defaults?.object(forKey: Keys.highLineMgdl) as? Double ?? fallbackHigh
        return (low, high)
    }

    // MARK: - Slot configuration (Write)

    /// Persists a 4-slot configuration to the App Group container.
    /// - Parameter slots: Array of exactly 4 `LiveActivitySlotOption` values;
    ///   extra elements are ignored, missing elements are filled with `.none`.
    static func setSlots(_ slots: [LiveActivitySlotOption]) {
        let raw = slots.prefix(4).map(\.rawValue)
        defaults?.set(raw, forKey: Keys.slots)
    }

    // MARK: - Slot configuration (Read)

    /// Returns the current 4-slot configuration, falling back to defaults
    /// if no configuration has been saved yet.
    static func slots() -> [LiveActivitySlotOption] {
        guard let raw = defaults?.stringArray(forKey: Keys.slots), raw.count == 4 else {
            return LiveActivitySlotDefaults.all
        }
        return raw.map { LiveActivitySlotOption(rawValue: $0) ?? .none }
    }

    // MARK: - Small widget slot (Write)

    static func setSmallWidgetSlot(_ slot: LiveActivitySlotOption) {
        defaults?.set(slot.rawValue, forKey: Keys.smallWidgetSlot)
    }

    // MARK: - Small widget slot (Read)

    static func smallWidgetSlot() -> LiveActivitySlotOption {
        guard let raw = defaults?.string(forKey: Keys.smallWidgetSlot) else {
            return LiveActivitySlotDefaults.smallWidgetSlot
        }
        return LiveActivitySlotOption(rawValue: raw) ?? LiveActivitySlotDefaults.smallWidgetSlot
    }

    // MARK: - Display Name

    static func setDisplayName(_ name: String, show: Bool) {
        defaults?.set(name, forKey: Keys.displayName)
        defaults?.set(show, forKey: Keys.showDisplayName)
    }

    static func displayName() -> String {
        defaults?.string(forKey: Keys.displayName) ?? "LoopFollow"
    }

    static func showDisplayName() -> Bool {
        defaults?.bool(forKey: Keys.showDisplayName) ?? false
    }
}
