# LoopFollow Live Activity — Architecture & Design Decisions

**Author:** Philippe Achkar (supported by Claude) 
**Date:** 2026-03-07  

---

## What Is the Live Activity?

The Live Activity displays real-time glucose data on the iPhone lock screen and in the Dynamic Island. It shows:

- Current glucose value (mg/dL or mmol/L)
- Trend arrow and delta
- IOB, COB, and projected glucose (when available)
- Threshold-driven background color (red (low) / green (in-range) / orange (high)) with user-set thresholds
- A "Not Looping" overlay when Loop has not reported in 15+ minutes

It updates every 5 minutes, driven by LoopFollow's existing refresh engine. No separate data pipeline exists — the Live Activity is a rendering surface only.

---

## Core Principles

### 1. Single Source of Truth

The Live Activity never fetches data directly from Nightscout or Dexcom. It reads exclusively from LoopFollow's internal storage layer (`Storage.shared`, `Observable.shared`). All glucose values, thresholds, IOB, COB, and loop status flow through the same path as the rest of the app.

This means:
- No duplicated business logic
- No risk of the Live Activity showing different data than the app
- The architecture is reusable for Apple Watch and CarPlay in future phases

### 2. Source-Agnostic Design

LoopFollow supports both Nightscout and Dexcom. IOB, COB, or predicted glucose are modeled as optional (`Double?`) in `GlucoseSnapshot` and the UI renders a dash (—) when they are absent. The Live Activity never assumes these values exist.

### 3. No Hardcoded Identifiers

The App Group ID is derived dynamically at runtime: group.<bundleIdentifier>. No team-specific bundle IDs or App Group IDs are hardcoded anywhere. This ensures the project is safe to fork, clone, and submit as a pull request by any contributor.

---

## Update Architecture — Why APNs Self-Push?

This is the most important architectural decision in Phase 1. Understanding it will help you maintain and extend this feature correctly.

### What We Tried First — Direct ``activity.update()``

The obvious approach to updating a Live Activity is to call ``activity.update()`` directly from the app. This works reliably when the app is in the foreground. 

The problem appears when the app is in the background. LoopFollow uses a background audio session (`.playback` category, silent WAV file) to stay alive in the background and continue fetching glucose data. We discovered that _liveactivitiesd_ (the iOS system daemon responsible for rendering Live Activities) refuses to process ``activity.update()`` calls from processes that hold an active background audio session. The update call either hangs indefinitely or is silently dropped. The Live Activity freezes on the lock screen while the app continues running normally.

We attempted several workarounds; none of these approaches were reliable or production-safe:
- Call ``activity.update()`` while audio is playing | Updates hang or are dropped
- Pause the audio player before updating | Insufficient — iOS checks the process-level audio assertion, not just the player state
- Call `AVAudioSession.setActive(false)` before updating | Intermittently worked, but introduced a race condition and broke the audio session unpredictably
- Add a fixed 3-second wait after deactivation | Fragile, caused background task timeout warnings, and still failed intermittently

### The Solution — APNs Self-Push

Our solution is for LoopFollow to send an APNs (Apple Push Notification service) push notification to itself.

Here is how it works:

1. When a Live Activity is started, ActivityKit provides a **push token** — a unique identifier for that specific Live Activity instance.
2. LoopFollow captures this token via `activity.pushTokenUpdates`.
3. After each BG refresh, LoopFollow generates a signed JWT using its APNs authentication key and posts an HTTP/2 request directly to Apple's APNs servers.
4. Apple's APNs infrastructure delivers the push to `liveactivitiesd` on the device.
5. `liveactivitiesd` updates the Live Activity directly — the app process is **never involved in the rendering path**.

Because `liveactivitiesd` receives the update via APNs rather than via an inter-process call from LoopFollow, it does not care that LoopFollow holds a background audio session. The update is processed reliably every time.

### Why This Is Safe and Appropriate

- This is an officially supported ActivityKit feature. Apple documents push-token-based Live Activity updates as the **recommended** update mechanism.
- The push is sent from the app itself, to itself. No external server or provider infrastructure is required.
- The APNs authentication key is injected at build time via xcconfig and Info.plist. It is never stored in the repository.
- The JWT is generated on-device using CryptoKit (`P256.Signing`) and cached for 55 minutes (APNs tokens are valid for 60 minutes).

---

## File Map

### Main App Target

| File | Responsibility |
|---|---|
| `LiveActivityManager.swift` | Orchestration — start, update, end, bind, observe lifecycle |
| `GlucoseSnapshotBuilder.swift` | Pure data transformation — builds `GlucoseSnapshot` from storage |
| `StorageCurrentGlucoseStateProvider.swift` | Thin abstraction over `Storage.shared` and `Observable.shared` |
| `GlucoseSnapshotStore.swift` | App Group persistence — saves/loads latest snapshot |
| `PreferredGlucoseUnit.swift` | Reads user unit preference, converts mg/dL ↔ mmol/L |
| `APNSClient.swift` | Sends APNs self-push with Live Activity content state |
| `APNSJWTGenerator.swift` | Generates ES256-signed JWT for APNs authentication |

### Shared (App + Extension)

| File | Responsibility |
|---|---|
| `GlucoseLiveActivityAttributes.swift` | ActivityKit attributes and content state definition |
| `GlucoseSnapshot.swift` | Canonical cross-platform glucose data struct |
| `GlucoseConversion.swift` | Single source of truth for mg/dL ↔ mmol/L conversion |
| `LAAppGroupSettings.swift` | App Group UserDefaults access |
| `AppGroupID.swift` | Derives App Group ID dynamically from bundle identifier |

### Extension Target

| File | Responsibility |
|---|---|
| `LoopFollowLiveActivity.swift` | SwiftUI rendering — lock screen card and Dynamic Island |
| `LoopFollowLABundle.swift` | WidgetBundle entry point |

---

## Update Flow

```
LoopFollow BG refresh completes
    → Storage.shared updated (glucose, delta, trend, IOB, COB, projected)
    → Observable.shared updated (isNotLooping)
    → BGData calls LiveActivityManager.refreshFromCurrentState(reason: "bg")
        → GlucoseSnapshotBuilder.build() reads from StorageCurrentGlucoseStateProvider
        → GlucoseSnapshot constructed (unit-converted, threshold-classified)
        → GlucoseSnapshotStore persists snapshot to App Group
        → activity.update(content) called (direct update for foreground reliability)
        → APNSClient.sendLiveActivityUpdate() sends self-push via APNs
            → liveactivitiesd receives push
            → Lock screen re-renders
```

---

## APNs Setup — Required for Contributors

To build and run the Live Activity locally or via CI, you need an APNs authentication key. The key content is injected at build time via `LoopFollowConfigOverride.xcconfig` and is **never stored in the repository**.

### What you need

- An Apple Developer account
- An APNs Auth Key (`.p8` file) with the **Apple Push Notifications service (APNs)** capability enabled
- The 10-character Key ID associated with that key

### Local Build Setup

1. Generate or download your `.p8` key from [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Keys.
2. Open the key file in a text editor. Copy the base64 content between the header and footer lines — **exclude** `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`. Join all lines into a single unbroken string with no spaces or line breaks.
3. Create or edit `LoopFollowConfigOverride.xcconfig` in the project root (this file is gitignored):

```
APNS_KEY_ID = <YOUR_10_CHARACTER_KEY_ID>
APNS_KEY_CONTENT = <YOUR_SINGLE_LINE_BASE64_KEY_CONTENT>
```

4. Build and run. The key is read at runtime from `Info.plist` which resolves `$(APNS_KEY_CONTENT)` from the xcconfig.

### CI / GitHub Actions Setup

Add two repository secrets under **Settings → Secrets and variables → Actions**:

| Secret Name | Value |
|---|---|
| `APNS_KEY_ID` | Your 10-character key ID |
| `APNS_KEY` | Full contents of your `.p8` file including PEM headers |

The build workflow strips the PEM headers automatically and injects the content into `LoopFollowConfigOverride.xcconfig` before building.
