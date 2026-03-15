// LoopFollow
// LiveActivitySlotConfig.swift

// MARK: - Information Display Settings audit
//
// LoopFollow exposes 20 items in Information Display Settings (InfoType.swift).
// The table below maps each item to its availability as a Live Activity grid slot.
//
// AVAILABLE NOW — value present in GlucoseSnapshot:
//   Display name   | InfoType case  | Snapshot field       | Optional (nil for Dexcom-only)
//   ─────────────────────────────────────────────────────────────────────────────────
//   IOB            | .iob           | snapshot.iob         | YES
//   COB            | .cob           | snapshot.cob         | YES
//   Projected BG   | (none)         | snapshot.projected   | YES
//   Delta          | (none)         | snapshot.delta       | NO  (always available)
//
//   Note: "Updated" (InfoType.updated) is intentionally excluded — it is displayed
//   in the card footer and is not a configurable slot.
//
// NOT YET AVAILABLE — requires adding fields to GlucoseSnapshot, GlucoseSnapshotBuilder,
// and the APNs payload before they can be offered as slot options:
//   Display name   | InfoType case     | Source in app
//   ─────────────────────────────────────────────────────────────────────────────────
//   Basal          | .basal            | DeviceStatus basal rate
//   Override       | .override         | DeviceStatus override name
//   Battery        | .battery          | DeviceStatus CGM/device battery %
//   Pump           | .pump             | DeviceStatus pump name / status
//   Pump Battery   | .pumpBattery      | DeviceStatus pump battery %
//   SAGE           | .sage             | DeviceStatus sensor age (hours)
//   CAGE           | .cage             | DeviceStatus cannula age (hours)
//   Rec. Bolus     | .recBolus         | DeviceStatus recommended bolus
//   Min/Max        | .minMax           | Computed from recent BG history
//   Carbs today    | .carbsToday       | Computed from COB history
//   Autosens       | .autosens         | DeviceStatusOpenAPS autosens ratio
//   Profile        | .profile          | DeviceStatus profile name
//   Target         | .target           | DeviceStatus BG target
//   ISF            | .isf              | DeviceStatus insulin sensitivity factor
//   CR             | .carbRatio        | DeviceStatus carb ratio
//   TDD            | .tdd              | DeviceStatus total daily dose
//   IAGE           | .iage             | DeviceStatus insulin/pod age (hours)
//
// The LiveActivitySlotOption enum, LiveActivitySlotDefaults struct, and
// LAAppGroupSettings.setSlots() / slots() storage are defined in
// LAAppGroupSettings.swift (shared between app and extension targets).
