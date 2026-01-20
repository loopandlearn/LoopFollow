# Settings UI Modernization Plan

This document tracks the UI modernization work for LoopFollow's settings pages.

## Current State Assessment

### Architecture Overview
- **Framework**: 100% SwiftUI (modern foundation)
- **Pattern**: MVVM with reactive bindings via `Storage.shared`
- **Navigation**: `NavigationStack` with enum-based routing (iOS 16+)
- **File Count**: ~13 settings views, 8 view models

### User-Reported Issues

#### A. Blue Tick Closes All Pages at Once
**Symptom:** A blue checkmark/tick appears at the top right of multiple settings pages. Tapping it closes ALL settings pages back to the main menu instead of just the current page.

**Root Cause:** Child views (like `InfoDisplaySettingsView`) wrap content in their own `NavigationView`. This creates a **nested navigation context** that's separate from the parent `NavigationStack`. When combined with `.environment(\.editMode, .constant(.active))`, iOS shows a "Done" button that dismisses the entire nested NavigationView stack.

**Fix:** Remove `NavigationView` wrappers from all child views - they're pushed via `NavigationStack` and shouldn't have their own navigation container.

#### B. Alarm Settings Duplication
**Symptom:** Alarm-related options appear in BOTH the Settings tab AND the Alarms tab.

**Current structure:**
- **Alarms Tab** (`AlarmsContainerView`): Shows `AlarmListView` with a gear icon → `AlarmSettingsView`
- **Settings Tab** (`SettingsMenuView`): Has BOTH "Alarms" → `AlarmListView` AND "Alarm Settings" → `AlarmSettingsView`

**This is redundant.** Users can access the same views from two different places.

**Recommendation:** Remove "Alarms" and "Alarm Settings" from the Settings menu since there's a dedicated Alarms tab. Keep only alarm-related items in Settings if the user has disabled the Alarms tab.

#### C. macOS Wastes Space / Half-Empty View
**Symptom:** On macOS (Catalyst/Mac Designed for iPad), the settings views don't expand to fill the window, leaving large empty areas.

**Root Cause:** SwiftUI `Form` has a default maximum width on macOS for readability. The current implementation doesn't override this.

**Fix options:**
1. Use `.formStyle(.grouped)` for better macOS appearance
2. Add platform-specific frame modifiers:
   ```swift
   #if os(macOS)
   .frame(maxWidth: .infinity)
   #endif
   ```
3. Consider `NavigationSplitView` for macOS to show sidebar + detail

---

### Technical Issues

#### 1. Nested Navigation Problem (Critical)
Child views wrap content in `NavigationView` when pushed from `NavigationStack`, causing double navigation bars and broken back navigation.

**Affected files:**
- `GeneralSettingsView.swift` (line 31)
- `GraphSettingsView.swift` (line 28)
- `AlarmSettingsView.swift` (line 48)
- `CalendarSettingsView.swift`
- `ContactSettingsView.swift`
- `InfoDisplaySettingsView.swift` (line 10) - **also has editMode causing Done button**
- `DexcomSettingsView.swift`
- `NightscoutSettingsView.swift`
- `AdvancedSettingsView.swift`
- `BackgroundRefreshSettingsView.swift`

**Correct pattern:** Views pushed via `NavigationStack` should NOT have their own `NavigationView` wrapper.

#### 2. Inconsistent Section Header Syntax
Mixed usage of old and new Section API:
```swift
// Old (inconsistent)
Section(header: Text("Alarm Settings")) { ... }

// Modern (preferred)
Section("Alarm Settings") { ... }
```

#### 3. Repeated Boilerplate Code
Every settings view repeats:
```swift
.preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
.navigationBarTitle("...", displayMode: .inline)
```

This should be centralized.

#### 4. Inconsistent Binding Patterns
Three different patterns coexist:
1. Direct `@ObservedObject` to `Storage.shared.property` (GeneralSettingsView)
2. ViewModel with `@Published` properties (RemoteSettingsView)
3. Inline Binding creation in view (AlarmSettingsView)

#### 5. Deprecated API Usage
- `.foregroundColor()` used instead of `.foregroundStyle()`
- `.pickerStyle(SegmentedPickerStyle())` instead of `.pickerStyle(.segmented)`
- `.toggleStyle(SwitchToggleStyle())` instead of `.toggleStyle(.switch)`

#### 6. Visual Inconsistencies
- **Main menu**: Nice icons with `Glyph` component
- **Sub-views**: No icons, plain text rows
- **Form vs List**: Main menu uses `List`, sub-views use `Form` (visual mismatch)

#### 7. Missing Help Text & Context
Many settings lack explanatory text:
- "Use IFCC A1C" - what does this mean?
- "Snoozer emoji" - unclear purpose
- "Min BG Scale" - needs explanation

#### 8. Accessibility & UX Issues
- No grouping of related toggles
- Long scrolling lists without visual hierarchy
- Inconsistent spacing and padding

---

## Improvement Plan

### Phase 1: Fix Critical Navigation Bug (Blue Tick Issue)
**Priority: Critical** - Directly addresses user-reported issue A

Remove `NavigationView` wrappers from all child settings views. They're pushed via `NavigationStack` and should not have their own navigation container. This will eliminate the rogue "Done" button that closes all pages.

**Files modified:** ✅ COMPLETED
- [x] `GeneralSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `GraphSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `AlarmSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `CalendarSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `ContactSettingsView.swift` - Removed `NavigationView`, updated to `.pickerStyle(.segmented)`, `.toggleStyle(.switch)`
- [x] `DexcomSettingsView.swift` - Removed `NavigationView`, updated to `.pickerStyle(.segmented)`
- [x] `NightscoutSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `AdvancedSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `InfoDisplaySettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `BackgroundRefreshSettingsView.swift` - Removed `NavigationView`, updated to modern navigation modifiers
- [x] `ImportExportSettingsView.swift` - Removed main `NavigationView` (kept NavigationView in sheets which is correct)

### Phase 1b: Remove Duplicate Alarm Entries from Settings ✅ COMPLETED
**Priority: High** - Directly addresses user-reported issue B

**Decision:** Remove "Alarms" and "Alarm Settings" from Settings menu entirely. The dedicated Alarms tab (with gear icon for settings) is sufficient.

**Files modified:**
- [x] `SettingsMenuView.swift` - Removed the Alarms section
- [x] `Sheet` enum - Removed `.alarmsList` and `.alarmSettings` cases

### Phase 1c: Implement NavigationSplitView for macOS ✅ COMPLETED
**Priority: High** - Directly addresses user-reported issue C

**Decision:** Use `NavigationSplitView` on macOS/Catalyst to provide a proper sidebar + detail layout that utilizes the full window width.

**Implementation:**
- Added `#if targetEnvironment(macCatalyst)` conditional compilation
- Created `iOSBody` and `macOSBody` computed properties
- Extracted settings list to `settingsMenuList` ViewBuilder for code reuse
- Created `settingsRow()` helper function for platform-aware row navigation
- Added `@State private var selectedSetting: Sheet?` for macOS selection tracking
- Used custom placeholder view instead of `ContentUnavailableView` (requires iOS 17+)

**Benefits:**
- Sidebar always visible on macOS
- Detail pane fills remaining width
- Native macOS settings app feel
- No code duplication (menu list extracted to shared property)

**Files modified:**
- [x] `SettingsMenuView.swift` - Complete platform-conditional navigation implementation

### Phase 2: Create Shared View Modifiers
**Priority: High**

Create a `SettingsViewStyle` modifier to standardize:
```swift
extension View {
    func settingsStyle(title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }
}
```

### Phase 3: Standardize Section Syntax
**Priority: Medium**

Convert all sections to modern syntax:
```swift
// Before
Section(header: Text("Header"), footer: Text("Footer")) { }

// After
Section {
    // content
} header: {
    Text("Header")
} footer: {
    Text("Footer")
}

// Or for simple headers:
Section("Header") { }
```

### Phase 4: Modernize Deprecated APIs
**Priority: Medium**

- Replace `.foregroundColor()` with `.foregroundStyle()`
- Replace `.pickerStyle(SegmentedPickerStyle())` with `.pickerStyle(.segmented)`
- Replace deprecated `onChange(of:perform:)` with `onChange(of:initial:_:)`

### Phase 5: Enhance Visual Hierarchy
**Priority: Medium**

Add subtle icons to sub-view sections using SF Symbols:
```swift
Section {
    // content
} header: {
    Label("Display", systemImage: "display")
}
```

### Phase 6: Add Help Text
**Priority: Low**

Add explanatory footers to complex settings:
```swift
Section {
    Toggle("Use IFCC A1C", isOn: $useIFCC.value)
} footer: {
    Text("IFCC displays A1C in mmol/mol instead of percentage.")
}
```

### Phase 7: Consolidate Binding Patterns
**Priority: Low**

Standardize on ViewModel pattern for complex views, direct Storage binding for simple views.

---

## File-by-File Changes

### SettingsMenuView.swift
- [x] Already uses modern `NavigationStack`
- [ ] Consider adding section icons
- [ ] Review spacing consistency

### GeneralSettingsView.swift
- [ ] Remove `NavigationView` wrapper
- [ ] Group "Speak BG" settings into collapsible section
- [ ] Add help text for unclear settings
- [ ] Apply `.settingsStyle()` modifier

### GraphSettingsView.swift
- [ ] Remove `NavigationView` wrapper
- [ ] Add help text for scale settings
- [ ] Apply `.settingsStyle()` modifier

### AlarmSettingsView.swift
- [ ] Remove `NavigationView` wrapper
- [ ] Simplify binding code (extract to helper or ViewModel)
- [ ] Apply `.settingsStyle()` modifier

### RemoteSettingsView.swift
- [x] No nested NavigationView (correct)
- [ ] Apply `.settingsStyle()` modifier
- [ ] Update deprecated API calls

---

## Testing Checklist

### Critical (User-Reported Issues)
- [ ] **Blue tick gone**: No "Done" button appears on sub-pages
- [ ] **Back navigation works**: Back button navigates one level, not all the way out
- [ ] **Swipe back works**: iOS edge swipe gesture returns to previous page
- [ ] **No alarm duplication**: Alarms aren't accessible from both tabs AND settings (or conditional)
- [ ] **macOS fills space**: On macOS, Forms expand to use available width

### General
- [ ] Navigation works correctly (back button, swipe gestures)
- [ ] Dark mode toggle affects all views
- [ ] Settings persist correctly
- [ ] No visual glitches or double navigation bars
- [ ] Accessibility labels work with VoiceOver
- [ ] All settings pages reachable and functional

---

## Progress Log

### Session 1 - Initial Review & User Discussion
**Date:** 2025-01-20

Completed initial codebase analysis. Key findings:
1. Architecture is modern SwiftUI but has accumulated inconsistencies
2. Critical bug: Nested NavigationView causes double nav bars
3. Code is functional but lacks visual polish and consistency
4. Good component reuse exists (NavigationRow, Glyph, etc.)

**User-reported issues identified:**
1. **Blue tick at top right** - Caused by nested `NavigationView` + `editMode`. The "Done" button from the inner NavigationView dismisses all settings at once.
2. **Alarm duplication** - AlarmListView and AlarmSettingsView accessible from both Alarms tab AND Settings menu.
3. **macOS empty space** - SwiftUI Form has default max-width on macOS; needs platform-specific styling.

**Root cause confirmed:** All three issues stem from architectural decisions that work on iPhone but break on edge cases (deep navigation, macOS).

### Session 1 - Implementation Complete
**Date:** 2025-01-20

**Phase 1 Complete:** Removed `NavigationView` from all 11 child settings views:
- GeneralSettingsView, GraphSettingsView, AlarmSettingsView, CalendarSettingsView
- ContactSettingsView, DexcomSettingsView, NightscoutSettingsView, AdvancedSettingsView
- InfoDisplaySettingsView, BackgroundRefreshSettingsView, ImportExportSettingsView

Also modernized some deprecated API calls along the way:
- `.pickerStyle(SegmentedPickerStyle())` → `.pickerStyle(.segmented)`
- `.toggleStyle(SwitchToggleStyle())` → `.toggleStyle(.switch)`
- `.navigationBarTitle(_:displayMode:)` → `.navigationTitle()` + `.navigationBarTitleDisplayMode()`
- Removed `.preferredColorScheme()` from child views (handled by parent)

**Phase 1b Complete:** Removed Alarms section from Settings menu:
- Removed "Alarms" and "Alarm Settings" navigation rows
- Removed `.alarmsList` and `.alarmSettings` from `Sheet` enum
- Users access alarms via dedicated Alarms tab only

**Phase 1c Complete:** Implemented `NavigationSplitView` for macOS/Catalyst:
- Platform-conditional body using `#if targetEnvironment(macCatalyst)`
- iOS: Uses existing `NavigationStack` with push navigation
- macOS: Uses `NavigationSplitView` with persistent sidebar
- Extracted `settingsMenuList` ViewBuilder for code reuse
- Created `settingsRow()` helper for platform-aware navigation

**Build Status:** ✅ BUILD SUCCEEDED

**Files Changed (13 total):**
1. `SettingsMenuView.swift` - Major refactor for platform-conditional navigation
2. `GeneralSettingsView.swift` - Navigation fix
3. `GraphSettingsView.swift` - Navigation fix
4. `AlarmSettingsView.swift` - Navigation fix
5. `CalendarSettingsView.swift` - Navigation fix
6. `ContactSettingsView.swift` - Navigation fix + API modernization
7. `DexcomSettingsView.swift` - Navigation fix + API modernization
8. `NightscoutSettingsView.swift` - Navigation fix
9. `AdvancedSettingsView.swift` - Navigation fix
10. `InfoDisplaySettingsView.swift` - Navigation fix
11. `BackgroundRefreshSettingsView.swift` - Navigation fix
12. `ImportExportSettingsView.swift` - Navigation fix

**Additional change:** Updated deployment target from iOS 16.6 to iOS 17.0
- Enables use of `ContentUnavailableView` and other modern APIs
- Updated `SettingsMenuView.swift` macOS placeholder to use `ContentUnavailableView`

### Session 2 - macOS UI Fixes
**Date:** 2025-01-20

Fixed three macOS-specific issues reported during testing:

1. **Blue tick at top right** ✅
   - Root cause: UIKit navigation bar was overlaid on top of SwiftUI navigation
   - Fix: On macOS, hide UIKit navigation bar and let SwiftUI handle navigation
   - Added `isModal` parameter to `SettingsMenuView` to show Done button only when presented modally
   - `SettingsViewController`: Added `navigationController?.setNavigationBarHidden(true)` for macOS
   - `MoreMenuViewController`: Present without `UINavigationController` wrapper on macOS

2. **Sidebar collapsible** ✅
   - Root cause: `NavigationSplitView` defaults to allowing sidebar collapse
   - Fix: Added `.navigationSplitViewStyle(.balanced)` to prevent sidebar from being hidden

3. **Card sliding from bottom** ✅
   - Root cause: Modal presentation on macOS shows as sheet by default
   - Fix: Changed to `.overFullScreen` with `.crossDissolve` transition for smoother appearance

**Files changed:**
- `SettingsMenuView.swift` - Added `isModal` parameter, conditional toolbar, balanced split view style
- `MoreMenuViewController.swift` - Platform-conditional presentation logic, cross-dissolve transition
- `SettingsViewController.swift` - Hide UIKit nav bar on macOS

---

## Phase 2: macOS NavigationSplitView Architecture

### Goal
Replace the iOS-style tab bar on macOS with a native `NavigationSplitView` sidebar layout, similar to System Settings on macOS.

### Current Architecture
```
iOS & macOS (current):
┌─────────────────────────────────────────────────┐
│  UITabBarController (Bottom tabs)               │
├─────────────────────────────────────────────────┤
│ Tab 0: Home (MainViewController)                │
│ Tab 1: Dynamic (Alarms/Remote/Nightscout)       │
│ Tab 2: Snoozer (fixed)                          │
│ Tab 3: Dynamic (Alarms/Remote/Nightscout)       │
│ Tab 4: More/Settings                            │
└─────────────────────────────────────────────────┘
```

### Target Architecture
```
iOS (unchanged):
┌─────────────────────────────────────────────────┐
│  UITabBarController (Bottom tabs)               │
│  [Same as current]                              │
└─────────────────────────────────────────────────┘

macOS (new):
┌─────────────────────────────────────────────────┐
│  NavigationSplitView                            │
├──────────────┬──────────────────────────────────┤
│  Sidebar     │  Detail Pane                     │
│  ──────────  │                                  │
│  🏠 Home     │  [Selected content]              │
│  😴 Snoozer  │                                  │
│  🔔 Alarms   │                                  │
│  📡 Remote   │                                  │
│  🌐 Nightscout│                                 │
│  ⚙️ Settings │                                  │
└──────────────┴──────────────────────────────────┘
```

### Implementation Plan

#### Step 1: Create macOS Root View
**File:** `LoopFollow/Application/MacAppView.swift` (new)

```swift
struct MacAppView: View {
    @State private var selectedSection: AppSection? = .home

    enum AppSection: String, CaseIterable, Identifiable {
        case home = "Home"
        case snoozer = "Snoozer"
        case alarms = "Alarms"
        case remote = "Remote"
        case nightscout = "Nightscout"
        case settings = "Settings"

        var id: String { rawValue }
        var icon: String { ... }
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("LoopFollow")
        } detail: {
            switch selectedSection {
            case .home: HomeViewRepresentable()
            case .snoozer: SnoozerView()
            case .alarms: AlarmsContainerView()
            case .remote: RemoteViewRepresentable()
            case .nightscout: NightscoutViewRepresentable()
            case .settings: SettingsMenuView()
            case nil: Text("Select a section")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

#### Step 2: Create UIViewControllerRepresentable Wrappers
**Purpose:** Wrap existing UIKit view controllers for use in SwiftUI

**Files to create:**
- `HomeViewRepresentable.swift` - Wraps MainViewController
- `NightscoutViewRepresentable.swift` - Wraps NightscoutViewController
- `RemoteViewRepresentable.swift` - Wraps RemoteViewController

Note: Snoozer, Alarms, and Settings are already SwiftUI views.

#### Step 3: Update SceneDelegate
**File:** `LoopFollow/Application/SceneDelegate.swift`

Add platform-conditional root view:
```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: ...) {
    #if targetEnvironment(macCatalyst)
    // macOS: Use SwiftUI NavigationSplitView
    let macAppView = MacAppView()
    window?.rootViewController = UIHostingController(rootView: macAppView)
    #else
    // iOS: Keep existing storyboard-based tab bar
    // (storyboard already sets this up)
    #endif
}
```

#### Step 4: Handle Dark Mode & Other Settings
- Apply `forceDarkMode` to the hosting controller
- Ensure all wrapped views respect settings

#### Step 5: Remove macOS-specific Modal Hacks
- Remove the modal presentation code for Settings on macOS
- Settings is now just another sidebar item

### Files Created ✅
- [x] `LoopFollow/Application/MacAppView.swift` - Main macOS navigation with NavigationSplitView
- [x] `LoopFollow/Helpers/Views/ViewControllerRepresentables.swift` - UIViewControllerRepresentable wrappers for:
  - `HomeViewRepresentable` - Wraps MainViewController
  - `NightscoutViewRepresentable` - Wraps NightscoutViewController
  - `RemoteViewRepresentable` - Wraps RemoteViewController
  - `SnoozerViewRepresentable` - Wraps SnoozerViewController

### Files Modified ✅
- [x] `LoopFollow/Application/SceneDelegate.swift` - Platform-conditional root view setup
  - macOS: Uses `UIHostingController` with `MacAppView`
  - iOS: Uses storyboard-based tab bar (unchanged)
  - Added window size constraints for macOS (min 900x600)
  - Hides macOS title bar
- [x] `LoopFollow/Settings/SettingsMenuView.swift` - Simplified for iOS-only usage
  - Removed macOS `NavigationSplitView` code (now in MacAppView)
  - Moved `Sheet` enum to file scope (fixes type inference issues)
  - Kept `isModal` for iOS modal presentation from More menu
- [x] `LoopFollow/ViewControllers/MoreMenuViewController.swift` - Removed macOS-specific code
- [x] `LoopFollow/ViewControllers/SettingsViewController.swift` - Removed macOS-specific code

### Implementation Details

#### MacAppView Architecture
```swift
MacAppView
├── NavigationSplitView
│   ├── Sidebar (List with selection)
│   │   ├── Home
│   │   ├── Alarms
│   │   ├── Remote
│   │   ├── Nightscout
│   │   └── Settings
│   └── Detail Pane
│       └── [Selected content view]
```

#### Sidebar Visibility
- Items are shown/hidden based on Storage settings:
  - Alarms: `Storage.shared.alarmsPosition.value != .disabled`
  - Remote: `Storage.shared.remotePosition.value != .disabled`
  - Nightscout: `Storage.shared.nightscoutPosition.value != .disabled && !url.isEmpty`
- Home and Settings are always visible

#### Settings in MacAppView
- Nested NavigationSplitView within Settings detail view
- Provides sidebar + detail for settings categories
- Consistent with macOS System Settings pattern

### Benefits
1. **Native macOS feel** - Sidebar navigation like System Settings
2. **No modal overlays** - Settings integrated into main navigation
3. **Persistent sidebar** - Always visible, easy to switch sections
4. **Clean separation** - iOS keeps tab bar, macOS gets proper sidebar
5. **Simplified code** - Removed modal presentation hacks

### Testing Checklist
- [ ] macOS: Sidebar shows all sections
- [ ] macOS: Clicking section shows correct content
- [ ] macOS: Home view displays BG data correctly
- [ ] macOS: Settings work within sidebar navigation
- [ ] macOS: Dark mode applies correctly
- [ ] iOS: Tab bar still works as before
- [ ] iOS: No regressions in navigation

### Session 3 - Phase 2 Complete
**Date:** 2025-01-20

Implemented complete macOS NavigationSplitView architecture:

1. **Created MacAppView.swift**
   - Main macOS app view with NavigationSplitView
   - Sidebar items: Home, Alarms, Remote, Nightscout, Settings
   - Dynamic visibility based on Storage settings
   - Nested settings NavigationSplitView for settings detail

2. **Created ViewControllerRepresentables.swift**
   - UIViewControllerRepresentable wrappers for UIKit view controllers
   - Enables embedding MainViewController, NightscoutViewController, etc. in SwiftUI

3. **Updated SceneDelegate.swift**
   - Platform-conditional root view setup
   - macOS uses MacAppView, iOS uses storyboard tab bar
   - Added window size constraints for macOS

4. **Cleaned up SettingsMenuView.swift**
   - Removed macOS-specific code (now handled by MacAppView)
   - Simplified to iOS-only NavigationStack
   - Fixed Sheet enum type inference issues

5. **Cleaned up MoreMenuViewController.swift & SettingsViewController.swift**
   - Removed macOS-specific modal presentation code
   - Simplified to iOS-only patterns

**Build Status:** ✅ BUILD SUCCEEDED

---

**Future enhancements (after Phase 2):**
- Phase 3: Create shared `.settingsStyle()` view modifier
- Phase 4: Standardize section syntax to modern format
- Phase 5: Continue modernizing deprecated APIs across all views
- Phase 6: Add visual hierarchy enhancements
- Phase 7: Add help text to unclear settings

---

## Design Decisions

### Platform-Conditional Navigation
- **iOS**: Uses `NavigationStack` for standard push/pop navigation
- **macOS/Catalyst**: Uses `NavigationSplitView` for sidebar + detail layout
- This provides the best UX for each platform without code duplication

### Why Form over List for settings?
`Form` provides automatic styling for settings-style content with proper grouping and native iOS Settings app appearance. The main menu can remain a `List` for the more custom appearance with icons.

### Binding pattern choice
For simple settings screens with direct storage binding, the `@ObservedObject var prop = Storage.shared.prop` pattern is acceptable and reduces boilerplate. For complex screens with validation or transformation logic, ViewModels are preferred.

### NavigationView in Sheets
Sheets presented via `.sheet()` modifier should have their own `NavigationView` wrapper because they create a separate presentation context. Only views pushed via `NavigationStack`/`NavigationSplitView` should NOT have NavigationView.

### iOS Version Compatibility
The app now targets iOS 17.0, enabling use of modern SwiftUI APIs:
- `ContentUnavailableView` for empty states
- Modern `onChange(of:)` syntax
- Improved navigation APIs
