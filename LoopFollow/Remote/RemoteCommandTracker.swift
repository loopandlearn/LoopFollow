// LoopFollow
// RemoteCommandTracker.swift

import Foundation

extension Notification.Name {
    /// Posted when a remote meal edit/delete reaches a terminal state, so treatment lists can refresh.
    static let remoteMealCommandDidComplete = Notification.Name("LoopFollow.remoteMealCommandDidComplete")
}

/// Tracks one in-flight remote command per key (Trio meal id or Loop sync identifier) until the
/// AID app's return push resolves it or the timeout fires. All state changes happen on the main queue.
final class RemoteCommandTracker: ObservableObject {
    static let shared = RemoteCommandTracker()
    static let timeoutMessage = "No confirmation received. Refresh the list to check whether the change was applied."

    enum State: Equatable {
        case pending(since: Date)
        case done(success: Bool, message: String)
    }

    struct Resolution: Equatable {
        let key: String
        let success: Bool
        let message: String
    }

    @Published private(set) var states: [String: State] = [:]

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

    func begin(key: String) {
        onMain {
            self.timeouts[key]?.cancel()
            self.states[key] = .pending(since: Date())
            let work = DispatchWorkItem { [weak self] in
                self?.resolve(key: key, success: false, message: Self.timeoutMessage)
            }
            self.timeouts[key] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout, execute: work)
        }
    }

    func resolve(key: String, success: Bool, message: String) {
        onMain {
            guard case .pending = self.states[key] else { return }
            self.timeouts[key]?.cancel()
            self.timeouts[key] = nil
            self.states[key] = .done(success: success, message: message)
            LogManager.shared.log(category: .apns, message: "Remote command for \(LogRedactor.tail(key)) finished: success=\(success) \(message)")
            NotificationCenter.default.post(name: .remoteMealCommandDidComplete, object: nil, userInfo: ["key": key])
        }
    }

    /// Clears a terminal state once the UI has acted on it.
    func consume(key: String) {
        onMain {
            if case .done = self.states[key] { self.states[key] = nil }
        }
    }

    /// Returns true when the push resolved a pending command.
    @discardableResult
    func handleNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let resolution = trioAcks.resolution(for: userInfo) ?? LoopCarbAckAdapter.resolution(for: userInfo) else { return false }
        guard isBusy(key: resolution.key) else {
            LogManager.shared.log(category: .apns, message: "Ack for \(LogRedactor.tail(resolution.key)) matched no pending command")
            return false
        }
        resolve(key: resolution.key, success: resolution.success, message: resolution.message)
        return true
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

/// Correlates Trio's return push with the meal a command was sent for via the per-send command id.
final class TRCMealAckAdapter {
    private var keys: [String: String] = [:]

    func register(commandID: String, key: String) {
        keys[commandID] = key
    }

    func unregister(commandID: String) {
        keys[commandID] = nil
    }

    func resolution(for userInfo: [AnyHashable: Any]) -> RemoteCommandTracker.Resolution? {
        guard let status = userInfo["command_status"] as? String,
              let commandID = userInfo["command_id"] as? String,
              let key = keys[commandID]
        else { return nil }
        keys[commandID] = nil
        let success = status == "success"
        let result = userInfo["result"] as? String
        LogManager.shared.log(category: .apns, message: "TRC ack: status=\(status) result=\(result ?? "-") command_id=\(commandID)")
        return RemoteCommandTracker.Resolution(
            key: key,
            success: success,
            message: alertBody(userInfo) ?? Self.defaultMessage(result: result, success: success)
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
                LogManager.shared.log(category: .apns, message: "Meal command sent command_id=\(commandID) meal_id=\(key)")
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
                LogManager.shared.log(category: .apns, message: "Carb command sent for syncIdentifier=\(LogRedactor.tail(key))")
            } else {
                self.resolve(key: key, success: false, message: error ?? "The command could not be sent.")
            }
            completion(success, error)
        }
    }
}
