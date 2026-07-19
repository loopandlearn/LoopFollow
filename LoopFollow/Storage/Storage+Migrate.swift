// LoopFollow
// Storage+Migrate.swift

import Foundation
import UserNotifications

extension Storage {
    func migrateStep5() {
        // Users upgrading from main had snoozer hardcoded at position 3, but that
        // key never existed in UserDefaults. On dev the default for snoozerPosition
        // is .menu, so an unstored value silently becomes .menu and snoozer
        // disappears from the tab bar.
        //
        // Detect this by checking .exists: if snoozerPosition was never stored,
        // the user expects snoozer at position 3 (where it always was on main).
        guard !snoozerPosition.exists else { return }

        LogManager.shared.log(category: .general, message: "migrateStep5: snoozerPosition not stored, restoring snoozer to position 3")

        // If position 3 is occupied by another item whose position also wasn't
        // stored (e.g. nightscout landing there from a changed default), move
        // that item out first.
        for item in TabItem.allCases where item != .snoozer {
            if position(for: item).normalized == .position3,
               !migratePositionExists(for: item)
            {
                setPosition(.menu, for: item)
            }
        }

        if tabItem(at: .position3) == nil {
            snoozerPosition.value = .position3
        }
    }

    func migrateStep8() {
        // Migrate showTITR bool + custom lowLine/highLine into timeInRangeModeRaw.
        LogManager.shared.log(category: .general, message: "Running migrateStep8 — timeInRangeMode migration")

        if showTITR.value {
            timeInRangeModeRaw.value = TimeInRangeDisplayMode.titr.rawValue
        } else if lowLine.value != 70.0 || highLine.value != 180.0 {
            timeInRangeModeRaw.value = TimeInRangeDisplayMode.custom.rawValue
        }
        // else: default "TIR" is already set
    }

    func migrateStep7() {
        // Cancel notifications scheduled with old hardcoded identifiers.
        // Replaced with bundle-ID-scoped identifiers for multi-instance support.
        LogManager.shared.log(category: .general, message: "Running migrateStep7 — cancel legacy notification identifiers")

        let legacyNotificationIDs = [
            "loopfollow.background.alert.6min",
            "loopfollow.background.alert.12min",
            "loopfollow.background.alert.18min",
            "loopfollow.la.renewal.failed",
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: legacyNotificationIDs)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: legacyNotificationIDs)
    }

    func migrateStep10() {
        LogManager.shared.log(category: .general, message: "Running migrateStep10 — infoSort/infoVisible → infoDisplayItems")
        migrateInfoDisplayItems()
    }

    /// Converts the legacy parallel `infoSort` / `infoVisible` arrays into the
    /// unified `infoDisplayItems` store, then removes the legacy keys.
    ///
    /// Idempotent — does nothing once the legacy keys are gone. Called from
    /// `migrateStep10()` and, as a safety net, unconditionally from
    /// `synchronizeInfoTypes()`: fresh installs never persist a `migrationStep`,
    /// so a user who customized their info display before this release would
    /// otherwise have the step-10 guard skip their conversion.
    func migrateInfoDisplayItems() {
        let legacySort = StorageValue<[Int]>(key: "infoSort", defaultValue: [])
        let legacyVisible = StorageValue<[Bool]>(key: "infoVisible", defaultValue: [])
        guard legacySort.exists || legacyVisible.exists else { return }

        let sort = legacySort.value
        let visible = legacyVisible.value

        var items: [InfoDisplayItem] = []
        var seen = Set<Int>()
        // Honor the saved order and per-index visibility.
        for index in sort {
            guard let type = InfoType(rawValue: index), seen.insert(index).inserted else { continue }
            let isVisible = index < visible.count ? visible[index] : type.defaultVisible
            items.append(InfoDisplayItem(type: type, isVisible: isVisible, coloring: InfoColoring()))
        }
        // Append any InfoType missing from the saved order (new cases, gaps).
        for type in InfoType.allCases where seen.insert(type.rawValue).inserted {
            items.append(InfoDisplayItem(type: type, isVisible: type.defaultVisible, coloring: InfoColoring()))
        }

        Storage.shared.infoDisplayItems.value = items
        legacySort.remove()
        legacyVisible.remove()
    }

    func migrateStep9() {
        // Default for debugLogLevel changed from false to true so users ship useful
        // logs when they report a problem. Force-enable for existing users.
        LogManager.shared.log(category: .general, message: "Running migrateStep9 — enabling debug log level")
        debugLogLevel.value = true
    }

    func migrateStep6() {
        // APNs credential separation
        LogManager.shared.log(category: .general, message: "Running migrateStep6 — APNs credential separation")

        let legacyReturnApnsKey = StorageValue<String>(key: "returnApnsKey", defaultValue: "")
        let legacyReturnKeyId = StorageValue<String>(key: "returnKeyId", defaultValue: "")
        let legacyApnsKey = StorageValue<String>(key: "apnsKey", defaultValue: "")
        let legacyKeyId = StorageValue<String>(key: "keyId", defaultValue: "")

        // 1. If returnApnsKey had a value, that was LoopFollow's own key (different team scenario)
        if legacyReturnApnsKey.exists, !legacyReturnApnsKey.value.isEmpty {
            lfApnsKey.value = legacyReturnApnsKey.value
            lfKeyId.value = legacyReturnKeyId.value
        }

        // 2. If lfApnsKey is still empty and the old primary key exists,
        //    check if same team — if so, the primary key was used for everything
        if lfApnsKey.value.isEmpty, legacyApnsKey.exists, !legacyApnsKey.value.isEmpty {
            let lfTeamId = BuildDetails.default.teamID ?? ""
            let remoteTeamId = teamId.value ?? ""
            let sameTeam = !lfTeamId.isEmpty && (remoteTeamId.isEmpty || lfTeamId == remoteTeamId)
            if sameTeam {
                lfApnsKey.value = legacyApnsKey.value
                lfKeyId.value = legacyKeyId.value
            }
        }

        // 3. Move old primary credentials to remoteApnsKey/remoteKeyId
        if legacyApnsKey.exists, !legacyApnsKey.value.isEmpty {
            remoteApnsKey.value = legacyApnsKey.value
            remoteKeyId.value = legacyKeyId.value
        }

        // 4. Clean up old keys
        legacyReturnApnsKey.remove()
        legacyReturnKeyId.remove()
        legacyApnsKey.remove()
        legacyKeyId.remove()
    }

    func migrateStep3() {
        LogManager.shared.log(category: .general, message: "Running migrateStep3 - this should only happen once!")
        let legacyForceDarkMode = StorageValue<Bool>(key: "forceDarkMode", defaultValue: true)
        if legacyForceDarkMode.exists {
            Storage.shared.appearanceMode.value = legacyForceDarkMode.value ? .dark : .system
            legacyForceDarkMode.remove()
        }

        if !TabPosition.customizablePositions.contains(homePosition.value.normalized) {
            LogManager.shared.log(category: .general, message: "migrateStep3: Setting home to position1 (was \(homePosition.value.rawValue))")
            homePosition.value = .position1
        }

        if !TabPosition.customizablePositions.contains(snoozerPosition.value.normalized) {
            // Move any unstored occupant at position 3 to menu before placing snoozer,
            // to avoid a collision when dev defaults differ from main.
            for item in TabItem.allCases where item != .snoozer {
                if position(for: item).normalized == .position3,
                   !migratePositionExists(for: item)
                {
                    setPosition(.menu, for: item)
                }
            }

            if tabItem(at: .position3) == nil {
                snoozerPosition.value = .position3
            }
        }

        if alarmsPosition.value == .more {
            alarmsPosition.value = .menu
        }
        if remotePosition.value == .more {
            remotePosition.value = .menu
        }
        if nightscoutPosition.value == .more {
            nightscoutPosition.value = .menu
        }
    }

    func migrateStep2() {
        // Migrate from old system to new position-based system
        if remoteType.value != .none {
            remotePosition.value = .position2
            alarmsPosition.value = .menu
        } else {
            alarmsPosition.value = .position2
            remotePosition.value = .menu
        }
        nightscoutPosition.value = .position4
    }

    // MARK: - Migration helpers (can be removed when step 5 is removed)

    /// Check whether a tab item's position was explicitly stored in UserDefaults
    /// (as opposed to using the StorageValue default).
    private func migratePositionExists(for item: TabItem) -> Bool {
        switch item {
        case .home: return homePosition.exists
        case .alarms: return alarmsPosition.exists
        case .remote: return remotePosition.exists
        case .nightscout: return nightscoutPosition.exists
        case .snoozer: return snoozerPosition.exists
        case .stats: return statisticsPosition.exists
        case .treatments: return treatmentsPosition.exists
        }
    }
}
