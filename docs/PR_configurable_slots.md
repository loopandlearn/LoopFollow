# Configurable Live Activity Grid Slots + Full InfoType Snapshot Coverage

## Summary

- Replace the hardcoded 2×2 grid on the Live Activity lock screen with four fully configurable slots, each independently selectable from all 20+ available metrics via a new Settings picker UI
- Extend `GlucoseSnapshot` with 19 new fields covering all InfoType items (basal, pump, autosens, TDD, ISF, CR, target, ages, carbs today, profile name, min/max BG, override)
- Wire up all downstream data sources (controllers + Storage) so every new field is populated on each data refresh cycle
- Redesign the lock screen layout: glucose + trend arrow left-aligned, delta below the BG value, configurable grid on the right, "Last Update: HH:MM" footer centered at the bottom

---

## Changes

### Lock screen layout redesign (`LoopFollowLAExtension/LoopFollowLiveActivity.swift`)

The previous layout had glucose + a fixed four-slot grid side by side with no clear hierarchy. The new layout:

- **Left column:** Large glucose value + trend arrow (`.system(size: 46)`), with `Delta: ±X` below in a smaller semibold font
- **Right column:** Configurable 2×2 grid — slot content driven by `LAAppGroupSettings.slots()`, read from the shared App Group container
- **Footer:** `Last Update: HH:MM` centered below both columns

A new `SlotView` struct handles dispatch for all 22 slot cases. Fifteen new `LAFormat` static methods were added to format each metric consistently (locale-aware number formatting, unit suffix, graceful `—` for nil/unavailable values).

### Configurable slot picker UI (`LoopFollow/LiveActivitySettingsView.swift`)

A new **Grid slots** section appears in the Live Activity settings screen with four pickers labelled Top left, Top right, Bottom left, Bottom right. Selecting a metric for one slot automatically clears that metric from any other slot (uniqueness enforced). Changes take effect immediately — `LiveActivityManager.shared.refreshFromCurrentState(reason: "slot config changed")` is called on every picker change.

### Slot type definitions (`LoopFollow/LiveActivity/LAAppGroupSettings.swift`)

- New `LiveActivitySlotOption` enum (22 cases: `none`, `delta`, `projectedBG`, `minMax`, `iob`, `cob`, `recBolus`, `autosens`, `tdd`, `basal`, `pump`, `pumpBattery`, `battery`, `target`, `isf`, `carbRatio`, `sage`, `cage`, `iage`, `carbsToday`, `override`, `profile`)
- `displayName` (used in Settings picker) and `gridLabel` (used inside the MetricBlock on the LA card) computed properties
- `isOptional` flag — `true` for metrics that may be absent for Dexcom-only users; the widget renders `—` in those cases
- `LiveActivitySlotDefaults` struct with out-of-the-box defaults: IOB / COB / Projected BG / Empty
- `LAAppGroupSettings.setSlots()` / `slots()` — persist and read the 4-slot configuration via the shared App Group `UserDefaults` container, so the extension always sees the current user selection

All of this is placed in `LAAppGroupSettings.swift` because that file is already compiled into both the app target and the extension target. No new Xcode project file membership was required.

### Extended GlucoseSnapshot (`LoopFollow/LiveActivity/GlucoseSnapshot.swift`)

Added 19 new stored properties. All are optional or have safe defaults so decoding an older snapshot (e.g. from a push that arrived before the app updated) never crashes:

| Property | Type | Source |
|---|---|---|
| `override` | `String?` | `Observable.shared.override` |
| `recBolus` | `Double?` | `Observable.shared.recBolus` |
| `battery` | `Double?` | `Observable.shared.battery` |
| `pumpBattery` | `Double?` | `Observable.shared.pumpBattery` |
| `basalRate` | `String` | `Storage.shared.lastBasal` |
| `pumpReservoirU` | `Double?` | `Storage.shared.lastPumpReservoirU` |
| `autosens` | `Double?` | `Storage.shared.lastAutosens` |
| `tdd` | `Double?` | `Storage.shared.lastTdd` |
| `targetLowMgdl` | `Double?` | `Storage.shared.lastTargetLowMgdl` |
| `targetHighMgdl` | `Double?` | `Storage.shared.lastTargetHighMgdl` |
| `isfMgdlPerU` | `Double?` | `Storage.shared.lastIsfMgdlPerU` |
| `carbRatio` | `Double?` | `Storage.shared.lastCarbRatio` |
| `carbsToday` | `Double?` | `Storage.shared.lastCarbsToday` |
| `profileName` | `String?` | `Storage.shared.lastProfileName` |
| `sageInsertTime` | `TimeInterval` | `Storage.shared.sageInsertTime` |
| `cageInsertTime` | `TimeInterval` | `Storage.shared.cageInsertTime` |
| `iageInsertTime` | `TimeInterval` | `Storage.shared.iageInsertTime` |
| `minBgMgdl` | `Double?` | `Storage.shared.lastMinBgMgdl` |
| `maxBgMgdl` | `Double?` | `Storage.shared.lastMaxBgMgdl` |

All glucose-valued fields are stored in **mg/dL**; conversion to mmol/L happens at display time in `LAFormat`, consistent with the existing snapshot design.

Age-based fields (SAGE, CAGE, IAGE) are stored as Unix epoch `TimeInterval` (0 = not set). `LAFormat.age(insertTime:)` computes the human-readable age string at render time using `DateComponentsFormatter` with `.positional` style and `[.day, .hour]` units.

### GlucoseSnapshotBuilder (`LoopFollow/LiveActivity/GlucoseSnapshotBuilder.swift`)

Extended `build(from:)` to populate all 19 new fields from `Observable.shared` and `Storage.shared`.

### Storage additions (`LoopFollow/Storage/Storage.swift`)

13 new `StorageValue`-backed fields in a dedicated "Live Activity extended InfoType data" section:

```
lastBasal, lastPumpReservoirU, lastAutosens, lastTdd,
lastTargetLowMgdl, lastTargetHighMgdl, lastIsfMgdlPerU,
lastCarbRatio, lastCarbsToday, lastProfileName,
iageInsertTime, lastMinBgMgdl, lastMaxBgMgdl
```

### Controller writes

Each data-fetching controller now writes one additional `Storage.shared` value alongside its existing `infoManager.updateInfoData` call. No existing logic was changed — these are purely additive writes:

| Controller | Field written |
|---|---|
| `Basals.swift` | `lastBasal` |
| `DeviceStatus.swift` | `lastPumpReservoirU` |
| `DeviceStatusLoop.swift` | `lastIsfMgdlPerU`, `lastCarbRatio`, `lastTargetLowMgdl`, `lastTargetHighMgdl`, `lastMinBgMgdl`, `lastMaxBgMgdl` |
| `DeviceStatusOpenAPS.swift` | `lastAutosens`, `lastTdd`, `lastIsfMgdlPerU`, `lastCarbRatio`, `lastTargetLowMgdl`, `lastTargetHighMgdl`, `lastMinBgMgdl`, `lastMaxBgMgdl` |
| `Carbs.swift` | `lastCarbsToday` |
| `Profile.swift` | `lastProfileName` |
| `IAge.swift` | `iageInsertTime` |

---