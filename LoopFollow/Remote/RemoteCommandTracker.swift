// LoopFollow
// RemoteCommandTracker.swift

import Foundation

extension Notification.Name {
    /// Posted when a tracked remote command reaches a terminal state, with its key in `userInfo["key"]` and its outcome in `userInfo["success"]`, so lists can refresh.
    static let remoteMealCommandDidComplete = Notification.Name("LoopFollow.remoteMealCommandDidComplete")
}

/// Tracks one in-flight remote command per key (Trio meal id or Loop sync identifier) until the
/// AID app's return push resolves it or the timeout fires. All state changes happen on the main queue.
final class RemoteCommandTracker: ObservableObject {
    static let shared = RemoteCommandTracker()
    static let timeoutMessage = "No confirmation received. Refresh the list to check whether the change was applied."

    enum State: Equatable {
        case pending(since: Date)
        /// `outdated` marks a refusal because the target changed or no longer exists on the phone.
        case done(success: Bool, message: String, outdated: Bool = false)
    }

    struct Resolution: Equatable {
        let key: String
        let success: Bool
        let message: String
        var outdated = false
    }

    @Published private(set) var states: [String: State] = [:]
    /// The last profile command sent under each key.
    private(set) var profileCommands: [String: ProfileCommand] = [:]

    let trioAcks = TRCMealAckAdapter()
    private let timeout: TimeInterval
    private var timeouts: [String: DispatchWorkItem] = [:]

    init(timeout: TimeInterval = 60) {
        self.timeout = timeout
    }

    func isBusy(key: String) -> Bool {
        if case .pending = states[key] { return true }
        return false
    }

    func begin(key: String, timeout: TimeInterval? = nil, timeoutMessage: String = RemoteCommandTracker.timeoutMessage) {
        onMain {
            self.timeouts[key]?.cancel()
            self.states[key] = .pending(since: Date())
            let work = DispatchWorkItem { [weak self] in
                self?.resolve(key: key, success: false, message: timeoutMessage)
            }
            self.timeouts[key] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (timeout ?? self.timeout), execute: work)
        }
    }

    /// True while any command whose key starts with `prefix` waits for its reply.
    func isBusy(keyPrefix prefix: String) -> Bool {
        isBusy(keyPrefixes: [prefix])
    }

    func isBusy(keyPrefixes prefixes: [String]) -> Bool {
        states.contains { key, state in
            if case .pending = state { return prefixes.contains { key.hasPrefix($0) } }
            return false
        }
    }

    func resolve(key: String, success: Bool, message: String, outdated: Bool = false) {
        onMain {
            guard case .pending = self.states[key] else { return }
            self.timeouts[key]?.cancel()
            self.timeouts[key] = nil
            self.states[key] = .done(success: success, message: message, outdated: outdated)
            let outcome = ProfileRemote.isProfileCommandKey(key) ? "outdated=\(outdated)" : message
            LogManager.shared.log(category: .apns, message: "Remote command for \(Self.logKey(key)) finished: success=\(success) \(outcome)")
            NotificationCenter.default.post(name: .remoteMealCommandDidComplete, object: nil, userInfo: ["key": key, "success": success])
        }
    }

    /// The key as it may be logged: the command kind for a profile command, whose key holds the profile name.
    static func logKey(_ key: String) -> String {
        guard ProfileRemote.isProfileCommandKey(key), let separator = key.firstIndex(of: ":") else { return LogRedactor.tail(key) }
        return String(key[..<separator])
    }

    /// Clears a terminal state once the UI has acted on it.
    func consume(key: String) {
        onMain {
            if case .done = self.states[key] { self.states[key] = nil }
        }
    }

    private var pendingKeys: [String] {
        states.compactMap { key, state in
            if case .pending = state { return key }
            return nil
        }
    }

    /// Returns true when the push resolved a pending command.
    @discardableResult
    func handleNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let resolution = trioAcks.resolution(for: userInfo)
            ?? LoopCarbAckAdapter.resolution(for: userInfo)
            ?? LoopProfileAckAdapter.resolution(for: userInfo, pendingKeys: pendingKeys)
            ?? LoopScheduledSwitchesAckAdapter.resolution(for: userInfo)
        else { return false }
        guard isBusy(key: resolution.key) else {
            LogManager.shared.log(category: .apns, message: "Ack for \(Self.logKey(resolution.key)) matched no pending command")
            return false
        }
        resolve(key: resolution.key, success: resolution.success, message: resolution.message, outdated: resolution.outdated)
        return true
    }

    /// Resolves the pending profile command `command` as applied once the profiles uploaded to Nightscout show its
    /// change, for when the app's reply push does not arrive.
    func resolveProfileCommandSeen(_ command: ProfileCommand) {
        onMain {
            for remote in [ProfileRemote.loop, .trio] {
                let key = remote.key(for: command)
                guard self.profileCommands[key] == command, self.isBusy(key: key) else { continue }
                LogManager.shared.log(category: .apns, message: "No reply for \(Self.logKey(key)); the change shows in the uploaded profiles")
                self.resolve(key: key, success: true, message: remote.seenMessage(command))
            }
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

/// Correlates Trio's return push with the meal or profile a command was sent for via the per-send command id.
final class TRCMealAckAdapter {
    private struct Entry {
        let key: String
        let successMessage: String?
        let failureMessage: String?
    }

    private var entries: [String: Entry] = [:]

    /// The messages are used when the reply has no alert body.
    func register(commandID: String, key: String, successMessage: String? = nil, failureMessage: String? = nil) {
        entries[commandID] = Entry(key: key, successMessage: successMessage, failureMessage: failureMessage)
    }

    func unregister(commandID: String) {
        entries[commandID] = nil
    }

    func resolution(for userInfo: [AnyHashable: Any]) -> RemoteCommandTracker.Resolution? {
        guard let status = userInfo["command_status"] as? String,
              let commandID = userInfo["command_id"] as? String,
              let entry = entries[commandID]
        else { return nil }
        entries[commandID] = nil
        let success = status == "success"
        let result = userInfo["result"] as? String
        LogManager.shared.log(category: .apns, message: "TRC ack: status=\(status) result=\(result ?? "-") command_id=\(commandID)")
        let registered = success ? entry.successMessage : entry.failureMessage
        return RemoteCommandTracker.Resolution(
            key: entry.key,
            success: success,
            message: alertBody(userInfo) ?? registered ?? Self.defaultMessage(result: result, success: success),
            outdated: !success && ProfileRemote.isProfileCommandKey(entry.key) && (result == "conflict" || result == "not_found")
        )
    }

    private static func defaultMessage(result: String?, success: Bool) -> String {
        switch result {
        case "deleted": return "Meal deleted."
        case "updated": return "Meal updated."
        case "not_found": return "Trio could not find this meal. It may already have been deleted or changed on the phone."
        case "rejected": return "Trio rejected the command."
        default: return success ? "Command confirmed." : "Trio reported a failure."
        }
    }
}

/// Matches Loop's return push for carb delete/edit commands by sync identifier.
enum LoopCarbAckAdapter {
    static let commandTypes: Set<String> = ["carbs_delete", "carbs_edit"]

    static func resolution(for userInfo: [AnyHashable: Any]) -> RemoteCommandTracker.Resolution? {
        guard let commandType = userInfo["command_type"] as? String,
              commandTypes.contains(commandType),
              let status = userInfo["command_status"] as? String,
              let key = userInfo["sync_identifier"] as? String
        else { return nil }
        let success = status == "success"
        LogManager.shared.log(category: .apns, message: "Loop ack: type=\(commandType) status=\(status) sync_identifier=\(LogRedactor.tail(key))")
        let defaultMessage: String
        if !success {
            defaultMessage = "Loop reported a failure."
        } else {
            defaultMessage = commandType == "carbs_delete" ? "Carb entry deleted." : "Carb entry updated."
        }
        return RemoteCommandTracker.Resolution(key: key, success: success, message: alertBody(userInfo) ?? defaultMessage)
    }
}

/// Matches Loop's return push for a profile command by the profile name in its message
/// ("Profile '<name>' activated|saved|deleted" or "... Profile '<name>' not activated|saved|deleted: <reason>").
/// Names may contain apostrophes, so a name of a pending command that fits the message is preferred over parsing.
enum LoopProfileAckAdapter {
    static let commandTypes: [String: ProfileCommandKind] = [
        "profile_switch": .activate,
        "profile_save": .save,
        "profile_delete": .delete,
    ]

    static func resolution(for userInfo: [AnyHashable: Any], pendingKeys: [String] = []) -> RemoteCommandTracker.Resolution? {
        guard let commandType = userInfo["command_type"] as? String,
              let kind = commandTypes[commandType],
              let status = userInfo["command_status"] as? String,
              let body = alertBody(userInfo)
        else { return nil }
        let prefix = ProfileRemote.loop.keyPrefix(kind)
        let pendingNames = pendingKeys.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        // Loop builds the "Profile '<n>' …" frame of the body in English and localizes only the reason. A body
        // without any such frame resolves the only pending command of its type.
        let framed = ProfileCommandKind.allCases.contains { profileName(in: body, kind: $0) != nil }
        let named = profileName(in: body, kind: kind, candidates: pendingNames)
        guard let name = named ?? (!framed && pendingNames.count == 1 ? pendingNames[0] : nil) else { return nil }
        let result = userInfo["result"] as? String
        LogManager.shared.log(category: .apns, message: "Loop ack: type=\(commandType) status=\(status) result=\(result ?? "-")")
        let outcome = outcome(status: status, result: result, body: body)
        return RemoteCommandTracker.Resolution(
            key: ProfileRemote.loop.key(kind, name: name),
            success: outcome.success,
            message: body,
            outdated: outcome.outdated
        )
    }

    static let successResults: Set<String> = ["activated", "saved", "deleted"]
    static let outdatedResults: Set<String> = ["conflict", "not_found"]

    /// Success and outdated from the reply's `result` code; replies without one (older Loop builds) fall back to
    /// `command_status` and the English reason in the alert text.
    static func outcome(status: String, result: String?, body: String) -> (success: Bool, outdated: Bool) {
        if let result, !result.isEmpty {
            let success = successResults.contains(result)
            return (success, !success && outdatedResults.contains(result))
        }
        let success = status == "success"
        return (success, !success && isOutdatedRefusal(body))
    }

    /// Loop's reasons (English) for refusing a command whose profile changed or no longer exists on the phone,
    /// for replies without a `result` code.
    static let outdatedReasons = [
        "changed on the phone after it was uploaded",
        "has changed since it was loaded",
        "No profile named",
    ]

    static func isOutdatedRefusal(_ message: String) -> Bool {
        outdatedReasons.contains { message.localizedCaseInsensitiveContains($0) }
    }

    static func verb(_ kind: ProfileCommandKind) -> String {
        switch kind {
        case .activate: return "activated"
        case .save: return "saved"
        case .delete: return "deleted"
        case .saveScheduledSwitches: return "saved"
        }
    }

    /// The profile named in `message`: the longest candidate the message names, otherwise the name parsed up to
    /// the first "' not <verb>: " or up to a final "' <verb>".
    static func profileName(in message: String, kind: ProfileCommandKind, candidates: [String] = []) -> String? {
        guard kind != .saveScheduledSwitches else { return nil }
        let verb = verb(kind)
        let named = candidates
            .filter { name in
                message.hasSuffix("Profile '\(name)' \(verb)") || message.contains("Profile '\(name)' not \(verb): ")
            }
            .max { $0.count < $1.count }
        if let named { return named }
        let pattern: Regex<(Substring, Substring)>
        switch kind {
        case .activate: pattern = /Profile '(.+?)'(?: not activated: | activated$)/
        case .save: pattern = /Profile '(.+?)'(?: not saved: | saved$)/
        case .delete: pattern = /Profile '(.+?)'(?: not deleted: | deleted$)/
        case .saveScheduledSwitches: return nil
        }
        return message.firstMatch(of: pattern).map { String($0.1) }
    }
}

/// Matches Loop's return push for a scheduled switches save by its command type; only one can be pending.
enum LoopScheduledSwitchesAckAdapter {
    static let commandType = "profile_scheduled_switches_save"

    static func resolution(for userInfo: [AnyHashable: Any]) -> RemoteCommandTracker.Resolution? {
        guard userInfo["command_type"] as? String == commandType,
              let status = userInfo["command_status"] as? String
        else { return nil }
        let result = userInfo["result"] as? String
        LogManager.shared.log(category: .apns, message: "Loop ack: type=\(commandType) status=\(status) result=\(result ?? "-")")
        let success: Bool
        let outdated: Bool
        if let result, !result.isEmpty {
            success = result == "saved"
            outdated = !success && (result == "conflict" || result == "not_found")
        } else {
            success = status == "success"
            outdated = false
        }
        let fallback = success ? "Scheduled switches saved" : "Scheduled switches not saved"
        return RemoteCommandTracker.Resolution(
            key: ProfileRemote.loop.key(.saveScheduledSwitches, name: ProfileCommand.scheduledSwitchesTarget),
            success: success,
            message: alertBody(userInfo) ?? fallback,
            outdated: outdated
        )
    }
}

private func alertBody(_ userInfo: [AnyHashable: Any]) -> String? {
    let alert = (userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
    guard let body = alert?["body"] as? String, !body.isEmpty else { return nil }
    return body
}

// MARK: - Trio meals

extension RemoteCommandTracker {
    func sendTrioMealDelete(mealID: String, completion: @escaping (Bool, String?) -> Void) {
        let commandID = UUID().uuidString
        trioAcks.register(commandID: commandID, key: mealID)
        begin(key: mealID)
        PushNotificationManager().sendDeleteMealPushNotification(mealID: mealID, commandID: commandID) { [weak self] success, error in
            self?.finishTrioSend(key: mealID, commandID: commandID, success: success, error: error, completion: completion)
        }
    }

    func sendTrioMealEdit(mealID: String, carbs: Int, fat: Int, protein: Int, date: Date, completion: @escaping (Bool, String?) -> Void) {
        let commandID = UUID().uuidString
        trioAcks.register(commandID: commandID, key: mealID)
        begin(key: mealID)
        PushNotificationManager().sendEditMealPushNotification(
            mealID: mealID,
            commandID: commandID,
            carbs: carbs,
            fat: fat,
            protein: protein,
            scheduledTime: date
        ) { [weak self] success, error in
            self?.finishTrioSend(key: mealID, commandID: commandID, success: success, error: error, completion: completion)
        }
    }

    private func finishTrioSend(key: String, commandID: String, success: Bool, error: String?, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            if success {
                LogManager.shared.log(category: .apns, message: "TRC command sent command_id=\(commandID) key=\(Self.logKey(key))")
            } else {
                self.trioAcks.unregister(commandID: commandID)
                self.resolve(key: key, success: false, message: error ?? "The command could not be sent.")
            }
            completion(success, error)
        }
    }
}

// MARK: - Loop carb entries

extension RemoteCommandTracker {
    func sendLoopCarbDelete(carb: LoopCarbTreatment, completion: @escaping (Bool, String?) -> Void) {
        let key = carb.syncIdentifier
        begin(key: key)
        guard let otp = loopOTP(key: key, completion: completion) else { return }
        LoopAPNSService().sendCarbsDelete(syncIdentifier: key, otp: otp) { [weak self] success, error in
            self?.finishLoopSend(key: key, success: success, error: error, completion: completion)
        }
    }

    func sendLoopCarbEdit(carb: LoopCarbTreatment, carbsAmount: Double, absorptionHours: Double, foodType: String?, consumedDate: Date, completion: @escaping (Bool, String?) -> Void) {
        let key = carb.syncIdentifier
        begin(key: key)
        guard let otp = loopOTP(key: key, completion: completion) else { return }
        LoopAPNSService().sendCarbsEdit(
            syncIdentifier: key,
            carbsAmount: carbsAmount,
            absorptionTimeHours: absorptionHours,
            foodType: foodType,
            consumedDate: consumedDate,
            otp: otp
        ) { [weak self] success, error in
            self?.finishLoopSend(key: key, success: success, error: error, completion: completion)
        }
    }

    /// Sends a profile command and tracks it under `ProfileRemote.key(for:)` until the reply or the timeout.
    func sendProfileCommand(_ command: ProfileCommand, to remote: ProfileRemote, completion sent: @escaping (Bool, String?) -> Void) {
        let key = beginProfileCommand(command, to: remote)
        let completion = RemoteCommandRefresh.following(.profile(command), sent)
        switch remote {
        case .loop:
            guard let otp = loopOTP(key: key, completion: completion) else { return }
            let finish: (Bool, String?) -> Void = { [weak self] success, error in
                self?.finishLoopSend(key: key, success: success, error: error, completion: completion)
            }
            let service = LoopAPNSService()
            switch command {
            case let .activate(profile):
                service.sendProfileSwitch(name: profile.name, fingerprint: profile.fingerprint, otp: otp, completion: finish)
            case let .save(name, original, values):
                service.sendProfileSave(name: name, originalName: original?.name, baseFingerprint: original?.fingerprint, values: values, otp: otp, completion: finish)
            case let .delete(profile):
                service.sendProfileDelete(name: profile.name, fingerprint: profile.fingerprint, otp: otp, completion: finish)
            case let .saveScheduledSwitches(entries, baseFingerprint):
                service.sendScheduledSwitchesSave(entries: entries, baseFingerprint: baseFingerprint, otp: otp, completion: finish)
            }
        case .trio:
            let commandID = UUID().uuidString
            trioAcks.register(commandID: commandID, key: key, successMessage: remote.successMessage(command), failureMessage: remote.failureMessage(command))
            let finish: (Bool, String?) -> Void = { [weak self] success, error in
                self?.finishTrioSend(key: key, commandID: commandID, success: success, error: error, completion: completion)
            }
            let manager = PushNotificationManager()
            switch command {
            case let .activate(profile):
                manager.sendProfileSwitchPushNotification(name: profile.name, fingerprint: profile.fingerprint, commandID: commandID, completion: finish)
            case let .save(name, original, values):
                manager.sendProfileSavePushNotification(name: name, originalName: original?.name, baseFingerprint: original?.fingerprint, values: values, commandID: commandID, completion: finish)
            case let .delete(profile):
                manager.sendProfileDeletePushNotification(name: profile.name, fingerprint: profile.fingerprint, commandID: commandID, completion: finish)
            case let .saveScheduledSwitches(entries, baseFingerprint):
                manager.sendScheduledSwitchesSavePushNotification(entries: entries, baseFingerprint: baseFingerprint, commandID: commandID, completion: finish)
            }
        }
    }

    /// Marks `command` as pending under its key and returns the key.
    func beginProfileCommand(_ command: ProfileCommand, to remote: ProfileRemote) -> String {
        let key = remote.key(for: command)
        onMain { self.profileCommands[key] = command }
        begin(key: key, timeout: ProfileRemote.timeout, timeoutMessage: remote.timeoutMessage)
        return key
    }

    private func loopOTP(key: String, completion: (Bool, String?) -> Void) -> String? {
        let qrCodeURL = Storage.shared.loopAPNSQrCodeURL.value
        let otp = TOTPGenerator.extractOTPFromURL(qrCodeURL)
        let message: String?
        if otp == nil {
            message = "Invalid QR code URL. Please re-scan the QR code in settings."
        } else if TOTPService.shared.isTOTPBlocked(qrCodeURL: qrCodeURL) {
            message = "The current one-time code was already used. Wait for the next code and try again."
        } else {
            message = nil
        }
        guard let message else { return otp }
        resolve(key: key, success: false, message: message)
        completion(false, message)
        return nil
    }

    private func finishLoopSend(key: String, success: Bool, error: String?, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            if success {
                TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                LogManager.shared.log(category: .apns, message: "Loop command sent for \(Self.logKey(key))")
            } else {
                self.resolve(key: key, success: false, message: error ?? "The command could not be sent.")
            }
            completion(success, error)
        }
    }
}
