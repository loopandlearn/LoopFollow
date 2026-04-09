# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LoopFollow is an iOS app for caregivers/parents of Type 1 Diabetics (T1D) to monitor CGM glucose data, loop status, and AID system metrics. This fork (`LoopFollowLA`) is built on top of the upstream [loopandlearn/LoopFollow](https://github.com/loopandlearn/LoopFollow) and adds:

- **Live Activity** (Dynamic Island / Lock Screen) — **complete**, do not modify
- **Apple Watch complications + Watch app** — **active development focus**
- **APNS-based remote commands** — complete

The Live Activity work is considered stable. If it evolves upstream, the branch is rebased. All current development effort is on the Watch app (`LoopFollowWatch Watch App` target) and its complications.

## Build System

This is a CocoaPods project. Always open `LoopFollow.xcworkspace` (not `.xcodeproj`) in Xcode.

```bash
# Install/update pods after cloning or when Podfile changes
pod install

# Build from command line (simulator)
xcodebuild -workspace LoopFollow.xcworkspace -scheme LoopFollow -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -workspace LoopFollow.xcworkspace -scheme LoopFollow -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -workspace LoopFollow.xcworkspace -scheme LoopFollow -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:LoopFollowTests/AlarmConditions/BatteryConditionTests
```

Fastlane lanes (`build_LoopFollow`, `release`, `identifiers`, `certs`) are CI-only and require App Store Connect credentials.

## Xcode Targets

| Target | Purpose |
|---|---|
| `LoopFollow` | Main iOS app |
| `LoopFollowLAExtensionExtension` | Live Activity widget extension |
| `LoopFollowWatch Watch App` | watchOS complication app |

Bundle IDs are derived from `DEVELOPMENT_TEAM`: `com.$(TEAMID).LoopFollow`, etc. `Config.xcconfig` sets the marketing version; never edit version numbers directly (CI auto-bumps on merge to `dev`).

## Architecture

### Data Flow

1. **Data sources** → `MainViewController` pulls BG/treatment data from:
   - **Nightscout** (`Controllers/Nightscout/`) via REST API
   - **Dexcom Share** (`BackgroundRefresh/BT/`, uses `ShareClient` pod)
   - **BLE heartbeat** (`BackgroundRefresh/BT/BLEManager.swift`) for background refresh
2. `MainViewController` stores parsed data in its own arrays (`bgData`, `bolusData`, etc.) and calls `update*Graph()` methods.
3. **Reactive state bridge**: After processing, values are pushed into `Observable.shared` (in-memory) and `Storage.shared` (UserDefaults-backed). These feed SwiftUI views and the Live Activity pipeline.

### Key Singletons

- **`Storage`** (`Storage/Storage.swift`) — All persisted user settings as `StorageValue<T>` (UserDefaults) or `SecureStorageValue<T>` (Keychain). The single source of truth for configuration.
- **`Observable`** (`Storage/Observable.swift`) — In-memory reactive state (`ObservableValue<T>`) for transient display values (BG text, color, direction, current alarm, etc.).
- **`ProfileManager`** — Manages Nightscout basal profiles.
- **`AlarmManager`** — Evaluates alarm conditions and triggers sound/notification.

### Live Activity & Watch Complication Pipeline

`GlucoseSnapshot` (`LiveActivity/GlucoseSnapshot.swift`) is the **canonical, source-agnostic data model** shared by all Watch and Live Activity surfaces. It is unit-aware (mg/dL or mmol/L) and self-contained. Fields: `glucose`, `delta`, `trend`, `updatedAt`, `iob`, `cob`, `projected`, `unit`, `isNotLooping`.

```
MainViewController / BackgroundRefresh
        │
        ▼
GlucoseSnapshotBuilder.build(...)   ← assembles from Observable/Storage
        │
        ▼
GlucoseSnapshotStore.shared.save()  ← persists to App Group container (JSON, atomic)
        │
        ├──► LiveActivityManager.update()     ← Dynamic Island / Lock Screen  [COMPLETE]
        ├──► WatchConnectivityManager.send()  ← transferUserInfo to Watch
        │         └──► WatchSessionReceiver   ← saves snapshot + reloads complications (Watch-side)
        └──► WatchComplicationProvider        ← CLKComplicationDataSource (watchOS)
             └── ComplicationEntryBuilder     ← builds CLKComplicationTemplate
```

Thresholds for colour classification (green / orange / red) are read via `LAAppGroupSettings.thresholdsMgdl()` from the shared App Group UserDefaults — the same thresholds used by the Live Activity. The stale threshold is **15 minutes** (900 s) throughout.

### Watch Complications (active development)

Two corner complications to build in `ComplicationEntryBuilder` (`LoopFollow/WatchComplication/ComplicationEntryBuilder.swift`):

**Complication 1 — `graphicCorner`, Open Gauge Text**
- Centre: BG value, coloured green/orange/red via `LAAppGroupSettings` thresholds
- Bottom text: delta (e.g. `+3` or `-2`)
- Gauge: fills from 0 → 15 min based on `snapshot.age / 900`
- Stale (>15 min) or `isNotLooping == true`: replace BG with `⚠` (yellow warning symbol)

**Complication 2 — `graphicCorner`, Stacked Text**
- Top line: BG value (coloured)
- Bottom line: delta + minutes since update (e.g. `+3  4m`)
- Stale (>15 min): display `--`

Both complications open the Watch app on tap (default watchOS behaviour when linked to the Watch app). `WatchComplicationProvider` handles timeline lifecycle and delegates all template construction to `ComplicationEntryBuilder`.

### Watch App (active development)

Entry point: `LoopFollowWatch Watch App/LoopFollowWatchApp.swift` — activates `WatchSessionReceiver`.
Main view: `LoopFollowWatch Watch App/ContentView.swift` — currently a placeholder stub.

**Screen 1 — Main glucose view**
- Large BG value, coloured green/orange/red
- Right column: delta, projected BG, time since last update
- Button to open the phone app (shown only when `WCSession.default.isReachable`)

**Subsequent screens — scrollable data cards**
- Each screen shows up to 4 data points from `GlucoseSnapshot`
- User-configurable via Watch app settings; every field in `GlucoseSnapshot` is eligible (glucose, delta, projected, IOB, COB, trend, age); units displayed alongside each value
- Default: IOB, COB, projected BG, battery

Watch app settings persist in the Watch-side App Group UserDefaults (same suite as `LAAppGroupSettings`).

### Background Refresh

Three modes (set in `Storage.backgroundRefreshType`):
- **Silent tune** — plays an inaudible audio track to keep app alive
- **BLE heartbeat** — paired BLE device (e.g. Dexcom G7) wakes the app
- **APNS** — server push via `APNSClient` / `APNSJWTGenerator`

### Remote Commands

Remote bolus/carb/temp-target commands flow through `BackgroundRefresh/Remote/` using TOTP-authenticated APNS pushes. Settings live in `Storage` (APNS key, team ID, bundle ID, shared secret).

### Settings Architecture

Settings are split between:
- **SwiftUI views** in `Settings/` (new) — `GeneralSettingsView`, `AlarmSettingsView`, `AdvancedSettingsView`, etc.
- **Legacy UIKit** `SettingsViewController` — being migrated to SwiftUI

### Tests

Tests use the Swift Testing framework (`import Testing`). Test files are in `Tests/AlarmConditions/`.

## Branch & PR Conventions

- **All PRs target `dev`**, never `main`. PRs to `main` will be redirected.
- Never modify version numbers — CI auto-bumps after merge.
- Branch from `dev` and name it `feature_name` or `fix_name`.
