// LoopFollow
// HubChecklist.swift

import SwiftUI
import UserNotifications

/// What LF Hub needs on this phone and at the hub to send the alarms, each item with
/// what fixes it. Built from the hub's last status and what the phone knows itself.
enum HubChecklist {
    enum Permission {
        case allowed
        case notAsked
        case denied
    }

    enum Fix: Equatable {
        case retry
        case useHubMode
        case askNotifications
        case askAlarmKit
        case openNotificationSettings
        case openSettings
        case turnOnLiveActivity
        case goToAPN
        case registerAgain
        case dataSource(dexcom: Bool)
        case sendSources
        case askAdmin
    }

    struct Item: Identifiable, Equatable {
        enum ID {
            case hub, version, mode, notifications, alarmKit, liveActivity, apnKey, push, source, confirmed
        }

        let id: ID
        let title: String
        /// What is missing; nil while the item is in place.
        var problem: String?
        var fix: Fix?

        var isReady: Bool { problem == nil }
    }

    /// What the phone knows itself.
    struct Facts {
        var hubMode = true
        var hubLooksHealthy = true
        /// Nil until read.
        var notifications: Permission?
        var alarmKit = Permission.allowed
        var liveActivityOn = true
        var ownApnKey = true
        /// This phone may send its own APN key; a phone that joined with an invite does not.
        var ownKeyAllowed = true
        var isAdmin = true
        var hubSharesKeys = false
        /// This app's data source settings are not the hub's sources.
        var sourcesDiffer = false
        var drivesAlarms = true
        var hubProblems: [String] = []
    }

    /// The checklist for the hub's status; only the hub item when it did not answer, and
    /// none before its first answer.
    static func items(status: HubClient.Status?, error: String?, facts: Facts, now: Date) -> [Item] {
        var hub = Item(id: .hub, title: "LF Hub answers")
        if let error {
            hub.problem = error
            hub.fix = .retry
            return [hub]
        }
        guard let status else { return [] }
        // Pushes that do not arrive show on their own item.
        if facts.hubMode, !facts.hubLooksHealthy, HubClient.unhealthiness(of: status, now: now) == nil {
            hub.problem = "LF Hub has not answered properly for several minutes."
            hub.fix = .retry
        }
        var items = [hub]

        if !HubClient.supports(status.hub) {
            items.append(Item(id: .version, title: "LF Hub is up to date", problem: HubClient.Problem.hubOutdated))
        }

        items.append(Item(id: .mode, title: "Background Refresh uses LF Hub",
                          problem: facts.hubMode ? nil : "LoopFollow checks the alarms itself. Choose LF Hub to let the hub send them.",
                          fix: facts.hubMode ? nil : .useHubMode))

        items += permissionItems(facts, liveActivity: facts.hubMode)

        let sharedKey = status.device.apnsKeyShared == true
        if facts.ownApnKey || sharedKey {
            items.append(Item(id: .apnKey, title: sharedKey && !facts.ownApnKey ? "APN key shared by an admin" : "APN key added"))
            items.append(pushItem(status, ownApnKey: facts.ownApnKey, now: now))
        } else {
            if !facts.ownKeyAllowed {
                items.append(Item(id: .apnKey, title: "APN key shared by an admin",
                                  problem: "No admin phone shares an APN key yet. Ask an admin to add theirs.",
                                  fix: .askAdmin))
            } else {
                items.append(Item(id: .apnKey, title: "APN key added",
                                  problem: facts.hubSharesKeys && !facts.isAdmin
                                      ? "No admin phone shares an APN key yet. Ask an admin to add theirs, or add one here."
                                      : "LF Hub needs an APN key to notify this phone.",
                                  fix: .goToAPN))
            }
        }

        items.append(sourceItem(status, facts: facts))

        if facts.hubMode {
            var confirmed = Item(id: .confirmed, title: "LF Hub sends this phone's alarms")
            if !facts.drivesAlarms {
                let covered = [HubClient.Problem.noPush, HubClient.Problem.notFollowed, HubClient.Problem.noPushYet,
                               HubClient.Problem.pushFailing, HubClient.Problem.apnKeyRejected,
                               HubClient.Problem.alarmKitDenied,
                               HubClient.Problem.alarmKitUnavailable, HubClient.Problem.hubOutdated,
                               HubClient.Problem.notificationsOff]
                let remaining = facts.hubProblems.filter { !covered.contains($0) }
                if !remaining.isEmpty {
                    confirmed.problem = remaining.joined(separator: " ")
                } else if items.contains(where: { !$0.isReady }) {
                    confirmed.problem = "LF Hub takes over once the items above are ready. Until then, LoopFollow checks the alarms itself."
                } else {
                    confirmed.problem = "Waiting for LF Hub to confirm."
                }
                confirmed.fix = .retry
            }
            items.append(confirmed)
        }
        return items
    }

    /// The permissions LF Hub's notifications, alarms and Live Activity need on this phone.
    static func permissionItems(_ facts: Facts, liveActivity: Bool) -> [Item] {
        var items: [Item] = []
        if let notifications = facts.notifications {
            var item = Item(id: .notifications, title: "Notifications allowed")
            switch notifications {
            case .allowed: break
            case .notAsked: (item.problem, item.fix) = ("LoopFollow has not asked to send notifications yet.", .askNotifications)
            case .denied: (item.problem, item.fix) = (HubClient.Problem.notificationsOff, .openNotificationSettings)
            }
            items.append(item)
        }

        var alarmKit = Item(id: .alarmKit, title: "Alarms ring through silent mode")
        if HubClient.alarmKitProblem(authorized: facts.alarmKit == .allowed) != nil {
            alarmKit.problem = "Alarms follow the ringer switch."
            alarmKit.fix = facts.alarmKit == .notAsked ? .askAlarmKit : .openSettings
        }
        items.append(alarmKit)

        if liveActivity {
            items.append(Item(id: .liveActivity, title: "Live Activity on",
                              problem: facts.liveActivityOn ? nil : "Live Activity is off.",
                              fix: facts.liveActivityOn ? nil : .turnOnLiveActivity))
        }
        return items
    }

    /// The notification permission as iOS reports it now. Notifications delivered
    /// quietly or without alerts count as denied, as for the hub's confirmation.
    static func notificationPermission() async -> Permission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined { return .notAsked }
        return HubClient.notificationsAllow(settings.authorizationStatus, alertSetting: settings.alertSetting)
            ? .allowed : .denied
    }

    /// AlarmKit's permission as it is now.
    static var alarmKitPermission: Permission {
        #if !targetEnvironment(macCatalyst)
            if #available(iOS 26, *) {
                if HubAlarmKit.isAuthorized { return .allowed }
                return HubAlarmKit.canAsk ? .notAsked : .denied
            }
        #endif
        return .denied
    }

    /// Carries out a fix that needs no navigation: asks for a permission, opens the
    /// Settings app, or redoes a step with the hub.
    @MainActor static func perform(_ fix: Fix) async {
        switch fix {
        case .useHubMode:
            await BackgroundRefreshSettingsViewModel.change(to: .hub)?.value
        case .askNotifications:
            await withCheckedContinuation { continuation in
                NotificationAuthorization.requestIfNeeded { continuation.resume() }
            }
        case .askAlarmKit:
            #if !targetEnvironment(macCatalyst)
                if #available(iOS 26, *) {
                    _ = await HubAlarmKit.requestAuthorization()
                    await HubClient.shared.sync()
                }
            #endif
        case .openNotificationSettings, .openSettings:
            let link = fix == .openSettings ? UIApplication.openSettingsURLString : UIApplication.openNotificationSettingsURLString
            if let url = URL(string: link) { await UIApplication.shared.open(url) }
        case .turnOnLiveActivity:
            #if !targetEnvironment(macCatalyst)
                Storage.shared.laEnabled.value = true
                LiveActivityManager.shared.forceRestart()
            #endif
        case .registerAgain:
            await HubClient.shared.registerAgain()
        case .sendSources:
            await HubSourceSync.shared.retry()
        case .retry, .goToAPN, .dataSource, .askAdmin:
            break
        }
    }

    /// Whether the hub's notifications arrive, and if not, what is wrong: Apple rejecting
    /// the APN key is fixed where the key was added; anything else by registering again.
    private static func pushItem(_ status: HubClient.Status, ownApnKey: Bool, now: Date) -> Item {
        var item = Item(id: .push, title: "Notifications from LF Hub arrive")
        if !status.device.apnsConfigured {
            item.problem = "LF Hub has not registered this phone for notifications yet."
            item.fix = .registerAgain
            return item
        }
        switch HubClient.unhealthiness(of: status, now: now) {
        case nil:
            break
        case .keyRejected:
            if ownApnKey {
                item.problem = HubClient.Problem.apnKeyRejected + " Check the Key ID and key under Settings → APN."
                item.fix = .goToAPN
            } else {
                item.problem = HubClient.Problem.apnKeyRejected + " Ask the admin who added the key to check it under Settings → APN."
                item.fix = .askAdmin
            }
        case .registrationRejected:
            item.problem = HubClient.Problem.pushFailing + " Apple says this phone's registration is out of date."
            item.fix = .registerAgain
        case .pushFailing, .noAnswer:
            item.problem = HubClient.Problem.pushFailing
            item.fix = .registerAgain
        case .noPushYet:
            item.problem = HubClient.Problem.noPushYet
            item.fix = .registerAgain
        }
        return item
    }

    private static func sourceItem(_ status: HubClient.Status, facts: Facts) -> Item {
        let patient = status.patient
        var item = Item(id: .source, title: "LF Hub reads \(patient.name)'s data")
        if patient.nightscoutHost == nil, patient.dexcom != true {
            item.problem = "LF Hub has no data source for \(patient.name)."
        } else if patient.followed != true {
            item.problem = "LF Hub cannot read \(patient.name)'s data with this data source."
        } else if patient.hasData != true {
            item.problem = "LF Hub has not received a reading for \(patient.name) yet."
        }
        if item.problem != nil {
            item.fix = facts.isAdmin ? .dataSource(dexcom: patient.dexcom == true) : .askAdmin
        } else if facts.isAdmin, facts.sourcesDiffer {
            item.problem = "This phone's data source has not reached LF Hub."
            item.fix = .sendSources
        }
        return item
    }
}

/// The checklist's rows: a check for each item in place, otherwise what is missing and
/// a button that fixes it.
struct HubChecklistRows: View {
    let items: [HubChecklist.Item]
    let onFix: (HubChecklist.Fix) -> Void

    var body: some View {
        ForEach(items) { item in
            if item.isReady {
                Label {
                    Text(item.title)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        if let problem = item.problem {
                            Text(problem).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let fix = item.fix { fixButton(fix) }
                }
            }
        }
    }

    @ViewBuilder
    private func fixButton(_ fix: HubChecklist.Fix) -> some View {
        switch fix {
        case .goToAPN:
            NavigationLink("Go to APN", value: SettingsRoute.apn)
                .fixedSize()
        case let .dataSource(dexcom):
            NavigationLink("Data Source", value: dexcom ? SettingsRoute.dexcom : SettingsRoute.nightscout)
                .fixedSize()
        case .askAdmin:
            Text("Ask an admin").font(.caption).foregroundColor(.secondary).fixedSize()
        default:
            Button(title(fix)) { onFix(fix) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
        }
    }

    private func title(_ fix: HubChecklist.Fix) -> String {
        switch fix {
        case .retry: return "Try Again"
        case .useHubMode: return "Use LF Hub"
        case .askNotifications, .askAlarmKit: return "Allow"
        case .openNotificationSettings, .openSettings: return "Open Settings"
        case .turnOnLiveActivity: return "Turn On"
        case .registerAgain: return "Register Again"
        case .sendSources: return "Send"
        case .goToAPN, .dataSource, .askAdmin: return ""
        }
    }
}
