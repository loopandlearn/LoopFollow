# LoopFollow Live Activity — Project Context for Claude Code

## Who you're working with

This codebase is being developed by **Philippe** (GitHub: `MtlPhil`), contributing to
`loopandlearn/LoopFollow` — an open-source iOS app that lets parents and caregivers of T1D
Loop users monitor glucose and loop status in real time.

- **Upstream repo:** `https://github.com/loopandlearn/LoopFollow`
- **Philippe's fork:** `https://github.com/achkars-org/LoopFollow`
- **Local clone:** `/Users/philippe/Documents/GitHub/LoopFollowLA/`
- **Active upstream branch:** `live-activity` (PR #537, draft, targeting `dev`)
- **Philippe's original PR:** `#534` (closed, superseded by #537)
- **Maintainer:** `bjorkert` (Jonas Björkert)

---

## What this feature is

A **Live Activity** for LoopFollow that displays real-time glucose data on the iOS lock screen
and in the Dynamic Island. The feature uses **APNs self-push** — the app sends a push
notification to itself — to drive reliable background updates without interfering with the
background audio session LoopFollow uses to stay alive.

### What the Live Activity shows
- Current glucose value + trend arrow
- Delta (change since last reading)
- IOB, COB, projected BG (optional — omitted gracefully for Dexcom-only users)
- Time since last reading
- "Not Looping" red banner when Loop hasn't reported in 15+ minutes
- Threshold-driven background color (green / orange / red)
- Dynamic Island: compact, expanded, and minimal presentations

---

## Architecture overview (current state in PR #537)

### Data flow
```
BGData / DeviceStatusLoop / DeviceStatusOpenAPS
    → write canonical values to Storage.shared
        → GlucoseSnapshotBuilder reads Storage
            → builds GlucoseSnapshot
                → LiveActivityManager pushes via APNSClient
                    → LoopFollowLAExtension renders the UI
```

### Key files

| File | Purpose |
|------|---------|
| `LiveActivity/LiveActivityManager.swift` | Orchestrates start/stop/refresh of the Live Activity; called from `MainViewController` |
| `LiveActivity/APNSClient.swift` | Sends the APNs self-push; uses `JWTManager.shared` for JWT; reads credentials from `Storage.shared` |
| `Helpers/JWTManager.swift` | **bjorkert addition** — replaces `APNSJWTGenerator`; uses CryptoKit (P256/ES256); multi-slot in-memory cache keyed by `keyId:teamId`, 55-min TTL |
| `LiveActivity/GlucoseSnapshot.swift` | The value-type snapshot passed to the extension; timestamp stored as Unix epoch seconds (UTC) — **timezone bug was fixed here** |
| `LiveActivity/GlucoseSnapshotBuilder.swift` | Reads from Storage, constructs GlucoseSnapshot |
| `LiveActivity/GlucoseSnapshotStore.swift` | In-memory store; debounces rapid successive refreshes |
| `LiveActivity/GlucoseLiveActivityAttributes.swift` | ActivityKit attributes struct |
| `LiveActivity/AppGroupID.swift` | Derives App Group ID dynamically from bundle identifier — no hardcoded team IDs |
| `LiveActivity/LAAppGroupSettings.swift` | Persists LA-specific settings to the shared App Group container |
| `LiveActivity/LAFormat.swift` | **bjorkert addition** — display formatting for LA values; uses `NumberFormatter` with `Locale.current` so decimal separators match device locale (e.g. "5,6" in Swedish) |
| `LiveActivity/PreferredGlucoseUnit.swift` | Reads preferred unit; delegates to `Localizer.getPreferredUnit()` — no longer duplicates unit detection logic |
| `GlucoseConversion.swift` | **Replaces `GlucoseUnitConversion.swift`** — unified constant `18.01559`; `mgDlToMmolL` is a computed reciprocal. Note: the old file used `18.0182` — do not use that constant anywhere |
| `LiveActivity/StorageCurrentGlucoseStateProvider.swift` | Protocol adapter between Storage and LiveActivityManager |
| `LoopFollowLAExtension/LoopFollowLiveActivity.swift` | SwiftUI widget views for lock screen + Dynamic Island |
| `LoopFollowLAExtension/LoopFollowLABundle.swift` | Extension bundle entry point |
| `Settings/APNSettingsView.swift` | **bjorkert addition** — dedicated settings screen for LoopFollow's own APNs key ID and key |
| `Storage/Storage.swift` | Added: `lastBgReadingTimeSeconds`, `lastDeltaMgdl`, `lastTrendCode`, `lastIOB`, `lastCOB`, `projectedBgMgdl` |
| `Storage/Observable.swift` | Added: `isNotLooping` |
| `Storage/Storage+Migrate.swift` | Added: `migrateStep5` — migrates legacy APNs credential keys to new split format |

---

## The core design decisions Philippe made (and why)

### 1. APNs self-push for background updates
LoopFollow uses a background audio session to stay alive in the background. Initially, the
temptation was to use `ActivityKit` updates directly from the app. The self-push approach was
chosen because it is more reliable and doesn't create timing conflicts with the audio session.
The app sends a push to itself using its own APNs key; the system delivers it with high
priority, waking the extension.

### 2. Dynamic App Group ID (no hardcoded team IDs)
`AppGroupID.swift` derives the App Group ID from the bundle identifier at runtime. This makes
the feature work across all fork/build configurations without embedding any team-specific
identifiers in code.

### 3. Single source of truth in Storage
All glucose and loop state is written to `Storage.shared` (and `Observable`) by the existing
data-fetching controllers (BGData, DeviceStatusLoop, DeviceStatusOpenAPS). The Live Activity
layer is purely a consumer — it never fetches its own data. This keeps the architecture clean
and source-agnostic.

### 4. GlucoseSnapshot stores glucose in mg/dL only — conversion at display time only
The snapshot is a simple struct with no dependencies, designed to be safe to pass across the
app/extension boundary. All glucose values in `GlucoseSnapshot` are stored as **mg/dL**.
Conversion to mmol/L happens exclusively at display time inside `LAFormat`. This eliminates
the previous round-trip (mg/dL → mmol/L at snapshot creation, then mmol/L → mg/dL for
threshold comparison) that bjorkert identified and removed.

**Rule for all future code:** anything writing a glucose value into a `GlucoseSnapshot` must
supply mg/dL. Anything reading a glucose value from a snapshot for display must convert via
`GlucoseConversion.mgDlToMmolL` if the user's preferred unit is mmol/L.

### 5. Unix epoch timestamps (UTC) in GlucoseSnapshot
**Critical bug that was discovered and fixed:** ActivityKit operates in UTC epoch seconds,
but the original code was constructing timestamps using local time offsets, causing DST
errors of ±1 hour. The fix ensures all timestamps in `GlucoseSnapshot` are stored as
`TimeInterval` (seconds since Unix epoch, UTC) and converted to display strings only in the
extension, using the device's local calendar. This fix is in the codebase.

### 6. Debounce on rapid refreshes
A coalescing `DispatchWorkItem` pattern is used in `GlucoseSnapshotStore` to debounce
rapid successive calls to refresh (e.g., when multiple Storage values update in quick
succession during a data fetch). Only one APNs push is sent per update cycle.

### 7. APNs key injected via xcconfig/Info.plist (Philippe's original approach)
In Philippe's original PR #534, the APNs key was injected at build time via
`xcconfig` / `Info.plist`, sourced from a GitHub Actions secret. This meant credentials were
baked into the build and never committed.

---

## What bjorkert changed (and why it differs from Philippe's approach)

### Change 1: SwiftJWT → CryptoKit (`JWTManager.swift`)
**Philippe used:** `SwiftJWT` + `swift-crypto` SPM packages for JWT signing.  
**bjorkert replaced with:** Apple's built-in `CryptoKit` (P256/ES256) via a new
`JWTManager.swift`.  
**Rationale:** Eliminates two third-party dependencies. `JWTManager` adds a multi-slot
in-memory cache (keyed by `keyId:teamId`, 55-min TTL) instead of persisting JWT tokens to
UserDefaults.  
**Impact:** `APNSJWTGenerator.swift` is deleted. All JWT logic lives in `JWTManager.shared`.

### Change 2: Split APNs credentials (lf vs remote)
**Philippe's approach:** One set of APNs credentials shared between Live Activity and remote
commands.  
**bjorkert's approach:** Two distinct credential sets:
- `lfApnsKey` / `lfKeyId` — for LoopFollow's own Live Activity self-push
- `remoteApnsKey` / `remoteKeyId` — for remote commands to Loop/Trio

**Rationale:** Users who don't use remote commands shouldn't need to configure remote
credentials to get Live Activity working. Users who use both (different team IDs for Loop
vs LoopFollow) previously saw confusing "Return Notification Settings" UI that's now removed.  
**Migration:** `migrateStep5` in `Storage+Migrate.swift` handles migrating the legacy keys.

### Change 3: Runtime credential entry via APNSettingsView
**Philippe's approach:** APNs key injected at build time via xcconfig / CI secret.  
**bjorkert's approach:** User enters APNs Key ID and Key at runtime via a new
`APNSettingsView` (under Settings menu).  
**Rationale:** Removes the `Inject APNs Key Content` CI step entirely. No credentials are
baked into the build or present in `Info.plist`. Browser Build users don't need to manage
GitHub secrets for APNs. Credentials stored in `Storage.shared` at runtime.  
**Impact:** `APNSKeyContent`, `APNSKeyID`, `APNSTeamID` removed from `Info.plist`. The CI
workflow no longer has an APNs key injection step.

### Change 4: APNSClient reads from Storage instead of Info.plist
Follows directly from Change 3. `APNSClient` now calls `Storage.shared` for credentials
and uses `JWTManager.shared` instead of `APNSJWTGenerator`. Sandbox vs production APNs
host selection is based on `BuildDetails.isTestFlightBuild()`.

### Change 5: Remote command settings UI simplification
The old "Return Notification Settings" section (which appeared when team IDs differed) is
removed. Remote credential fields only appear when team IDs differ. The new `APNSettingsView`
is always the place to enter LoopFollow's own credentials.

### Change 6: CI / build updates
- `runs-on` updated from `macos-15` to `macos-26`
- Xcode version updated to `Xcode_26.2`
- APNs key injection step removed from `build_LoopFollow.yml`

### Change 8: Consolidation pass (post-PR-#534 cleanup)
This batch of changes was made by bjorkert after integrating Philippe's code, to reduce
duplication and fix several bugs found during review.

**mg/dL-only snapshot storage:**  
All glucose values in `GlucoseSnapshot` are now stored in mg/dL. The previous code converted
to mmol/L at snapshot creation time, then converted back to mg/dL for threshold comparison —
a pointless round-trip. Conversion now happens only in `LAFormat` at display time.

**Unified conversion constant:**  
`GlucoseUnitConversion.swift` (used `18.0182`) is deleted.  
`GlucoseConversion.swift` (uses `18.01559`) is the single source. Do not use `18.0182` anywhere.

**Deduplicated unit detection:**  
`PreferredGlucoseUnit.hkUnit()` now delegates to `Localizer.getPreferredUnit()` instead of
reimplementing the same logic.

**New trend cases (↗ / ↘):**  
`GlucoseSnapshot` trend now includes `upSlight` / `downSlight` cases (FortyFiveUp/Down),
rendering as `↗` / `↘` instead of collapsing to `↑` / `↓`. All trend switch statements
must handle these cases.

**Locale bug fixed in `LAFormat`:**  
`LAFormat` now uses `NumberFormatter` with `Locale.current` so decimal separators match
the device locale. Do not format glucose floats with string interpolation directly —
always go through `LAFormat`.

**`LAThresholdSync.swift` deleted:**  
Was never called. Removed as dead code. Do not re-introduce it.

**APNs payload fix — `isNotLooping`:**  
The APNs push payload was missing the `isNotLooping` field, so push-based updates never
showed the "Not Looping" overlay. Now fixed — the field is included in every push.


bjorkert ran swiftformat across all Live Activity files: standardized file headers,
alphabetized imports, added trailing commas, cleaned whitespace. No logic changes.

---

## What was preserved from Philippe's PR intact

- All `LiveActivity/` Swift files except those explicitly deleted:
  - **Deleted:** `APNSJWTGenerator.swift` (replaced by `JWTManager.swift`)
  - **Deleted:** `GlucoseUnitConversion.swift` (replaced by `GlucoseConversion.swift`)
  - **Deleted:** `LAThresholdSync.swift` (dead code)
- The `LoopFollowLAExtension/` files (both `LoopFollowLiveActivity.swift` and
  `LoopFollowLABundle.swift`)
- The data flow architecture (Storage → SnapshotBuilder → LiveActivityManager → APNSClient)
- The DST/timezone fix in `GlucoseSnapshot.swift`
- The debounce pattern in `GlucoseSnapshotStore.swift`
- The `AppGroupID` dynamic derivation approach
- The "Not Looping" detection via `Observable.isNotLooping`
- The Storage fields added for Live Activity data
- The `docs/LiveActivity.md` architecture + APNs setup guide
- The Fastfile changes for the extension App ID and provisioning profile

---

## Current task: Live Activity auto-renewal (8-hour limit workaround)

### Background
Apple enforces an **8-hour maximum lifetime** on Live Activities in the Dynamic Island
(12 hours on the Lock Screen, but the DA kills at 8). For a continuous glucose monitor
follower app used overnight or during long days, this is a hard UX problem: the LA simply
disappears mid-use without warning.

bjorkert has asked Philippe to implement a workaround.

### Apple's constraints (confirmed)
- 8 hours from `Activity.request()` call — not from last update
- System terminates the LA hard at that point; no callback before termination
- The app **can** call `Activity.end()` + `Activity.request()` from the background via
  the existing audio session LoopFollow already holds
- `Activity.end(dismissalPolicy: .immediate)` removes the card from the Lock Screen
  immediately — critical to avoid two cards appearing simultaneously during renewal
- There is no built-in Apple API to query an LA's remaining lifetime

### Design decision: piggyback on the existing refresh heartbeat
**Rejected approach:** A standalone `Timer` or `DispatchQueue.asyncAfter` set for 7.5 hrs.
This is fragile — timers don't survive suspension, and adding a separate scheduling
mechanism is complexity for no benefit when a natural heartbeat already exists.

**Chosen approach:** Check LA age on every call to `refreshFromCurrentState(reason:)`.
Since this is called on every glucose update (~every 5 minutes via LoopFollow's existing
BGData polling cycle), the worst-case gap before renewal is one polling interval. The
check is cheap (one subtraction). If age ≥ threshold, end the current LA and immediately
re-request before doing the normal refresh.

### Files to change
| File | Change |
|------|--------|
| `Storage/Storage.swift` | Add `laStartTime: TimeInterval` stored property (UserDefaults-backed, default 0) |
| `LiveActivity/LiveActivityManager.swift` | Record `laStartTime` on every successful `Activity.request()`; check age in `refreshFromCurrentState(reason:)`; add `renewIfNeeded()` helper |

No other files need to change. The renewal is fully encapsulated in `LiveActivityManager`.

### Key constants
```swift
static let renewalThreshold: TimeInterval = 7.5 * 3600  // 27,000 s — renew at 7.5 hrs
static let storageKey = "laStartTime"                    // key in Storage/UserDefaults
```

### Behaviour spec
1. On every `refreshFromCurrentState(reason:)` call, before building the snapshot:
   - Compute `age = now - Storage.shared.laStartTime`
   - If `age >= renewalThreshold` AND a live activity is currently active:
     - End it with `.immediate` dismissal (clears the Lock Screen card instantly)
     - Re-request a new LA with the current snapshot content
     - Record new `laStartTime = now`
     - Return (the re-request itself sends the first APNs update)
2. On every successful `Activity.request()` (including normal `startFromCurrentState()`):
   - Set `Storage.shared.laStartTime = Date().timeIntervalSince1970`
3. On `stopLiveActivity()` (user-initiated stop or app termination):
   - Reset `Storage.shared.laStartTime = 0`
4. On app launch / `startFromCurrentState()` with an already-running LA (resume path):
   - Do NOT reset `laStartTime` — the existing value is the correct age anchor
   - This handles the case where the app is killed and relaunched mid-session

### Edge cases to handle
- **User dismisses the LA manually:** ActivityKit transitions to `.dismissed`. The existing
  `activityStateUpdates` observer in `LiveActivityManager` already handles this. `laStartTime`
  will be stale but harmless — next call to `startFromCurrentState()` will overwrite it.
- **App is not running at the 8-hr mark:** The system kills the LA. When the app next
  becomes active and calls `startFromCurrentState()`, it will detect no active LA and
  request a fresh one, resetting `laStartTime`. No special handling needed.
- **Multiple rapid calls to `refreshFromCurrentState` during renewal:** The existing
  debounce in `GlucoseSnapshotStore` guards this. The renewal path returns early after
  re-requesting, so the debounce never even fires.
- **laStartTime = 0 (never set / first launch):** Age will be enormous (current epoch),
  but the guard `currentActivity != nil` prevents a spurious renewal when there's no
  active LA. Safe.

### Full implementation (ready to apply)

#### `Storage/Storage.swift` addition
Add alongside the other LA-related stored properties:

```swift
// Live Activity renewal
var laStartTime: TimeInterval {
    get { return UserDefaults.standard.double(forKey: "laStartTime") }
    set { UserDefaults.standard.set(newValue, forKey: "laStartTime") }
}
```

#### `LiveActivity/LiveActivityManager.swift` changes

Add the constant and the helper near the top of the class:

```swift
// MARK: - Constants
private static let renewalThreshold: TimeInterval = 7.5 * 3600

// MARK: - Renewal

/// Ends the current Live Activity immediately and re-requests a fresh one,
/// working around Apple's 8-hour maximum LA lifetime.
/// Returns true if renewal was performed (caller should return early).
@discardableResult
private func renewIfNeeded(snapshot: GlucoseSnapshot) async -> Bool {
    guard let activity = currentActivity else { return false }

    let age = Date().timeIntervalSince1970 - Storage.shared.laStartTime
    guard age >= LiveActivityManager.renewalThreshold else { return false }

    os_log(.info, log: log, "Live Activity age %.0f s >= threshold, renewing", age)

    // End with .immediate so the stale card clears before the new one appears
    await activity.end(nil, dismissalPolicy: .immediate)
    currentActivity = nil

    // Re-request using the snapshot we already built
    await startWithSnapshot(snapshot)
    return true
}
```

Modify `startFromCurrentState()` to record the start time after a successful request:

```swift
func startFromCurrentState() async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    guard currentActivity == nil else { return }

    let snapshot = GlucoseSnapshotBuilder.build()
    await startWithSnapshot(snapshot)
}

/// Internal helper — requests a new LA and records the start time.
private func startWithSnapshot(_ snapshot: GlucoseSnapshot) async {
    let attributes = GlucoseLiveActivityAttributes()
    let content = ActivityContent(state: snapshot, staleDate: nil)
    do {
        currentActivity = try Activity<GlucoseLiveActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: .token
        )
        // Record when this LA was started for renewal tracking
        Storage.shared.laStartTime = Date().timeIntervalSince1970
        os_log(.info, log: log, "Live Activity started, laStartTime recorded")

        // Observe push token and state updates (existing logic)
        observePushTokenUpdates()
        observeActivityStateUpdates()
    } catch {
        os_log(.error, log: log, "Failed to start Live Activity: %@", error.localizedDescription)
    }
}
```

Modify `refreshFromCurrentState(reason:)` to call `renewIfNeeded` before the normal path:

```swift
func refreshFromCurrentState(reason: String) async {
    guard currentActivity != nil else {
        // No active LA — nothing to refresh
        return
    }

    let snapshot = GlucoseSnapshotBuilder.build()

    // Check if the LA is approaching Apple's 8-hour limit and renew if so.
    // renewIfNeeded returns true if it performed a renewal; we return early
    // because startWithSnapshot already sent the first update for the new LA.
    if await renewIfNeeded(snapshot: snapshot) { return }

    // Normal refresh path — send APNs self-push with updated snapshot
    await GlucoseSnapshotStore.shared.update(snapshot: snapshot)
}
```

Modify `stopLiveActivity()` to reset the start time:

```swift
func stopLiveActivity() async {
    guard let activity = currentActivity else { return }
    await activity.end(nil, dismissalPolicy: .immediate)
    currentActivity = nil
    Storage.shared.laStartTime = 0
    os_log(.info, log: log, "Live Activity stopped, laStartTime reset")
}
```

### Testing checklist
- [ ] Manually set `renewalThreshold` to 60 seconds during testing to verify the
      renewal cycle works without waiting 7.5 hours
- [ ] Confirm the old Lock Screen card disappears before the new one appears
      (`.immediate` dismissal working correctly)
- [ ] Confirm `laStartTime` is reset to 0 on manual stop
- [ ] Confirm `laStartTime` is NOT reset when the app is relaunched with an existing
      active LA (resume path)
- [ ] Confirm no duplicate LAs appear during renewal
- [ ] Restore `renewalThreshold` to `7.5 * 3600` before committing

---

## Known issues / things still in progress

- PR #537 is currently marked **Draft** as of March 12, 2026
- bjorkert's last commit (`524b3bb`) was March 11, 2026
- The PR is targeting `dev` and has 6 commits total (5 from Philippe, 1 from bjorkert)
- **Active task:** LA auto-renewal (8-hour limit workaround) — see section above

---

## APNs self-push mechanics (important context)

The self-push flow:
1. `LiveActivityManager.refreshFromCurrentState(reason:)` is called (from MainViewController
   or on a not-looping state change)
2. It calls `GlucoseSnapshotBuilder` → `GlucoseSnapshotStore`
3. The store debounces and triggers `APNSClient.sendUpdate(snapshot:)`
4. `APNSClient` fetches credentials from `Storage.shared`, calls `JWTManager.shared` for a
   signed JWT (cached for 55 min), then POSTs to the APNs HTTP/2 endpoint
5. The system delivers the push to `LoopFollowLAExtension`, which updates the Live Activity UI

**APNs environments:**
- Sandbox (development/TestFlight): `api.sandbox.push.apple.com`
- Production: `api.push.apple.com`
- Selection is automatic via `BuildDetails.isTestFlightBuild()`

**Token expiry handling:** APNs self-push token expiry (HTTP 410 / 400 BadDeviceToken)
is handled in `APNSClient` with appropriate error logging. The token is the Live Activity
push token obtained from `ActivityKit`, not a device token.

---

## Repo / branch conventions

- `main` — released versions only (version ends in `.0`)
- `dev` — integration branch; PR #537 targets this
- `live-activity` — bjorkert's working branch for the feature (upstream)
- Philippe's fork branches: `dev`, `live-activity-pr` (original work)
- Version format: `M.N.P` — P increments on each `dev` merge, N increments on release

---

## Build configuration notes

- App Group ID is derived dynamically — do not hardcode team IDs anywhere
- APNs credentials are now entered by the user at runtime in APNSettingsView
- No APNs secrets in xcconfig, Info.plist, or CI environment variables (as of bjorkert's
  latest commit)
- The extension target is `LoopFollowLAExtension` with its own entitlements file
  (`LoopFollowLAExtensionExtension.entitlements`)
- `Package.resolved` has been updated to remove SwiftJWT and swift-crypto dependencies
