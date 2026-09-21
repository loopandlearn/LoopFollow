// LoopFollow
// TRCCommandTracker.swift

import Foundation

/// Return notification Trio sends after processing a command.
struct TRCCommandAck: Equatable {
    let commandID: String?
    let commandType: String?
    let status: String
    let result: String?
    let mealID: String?
    let message: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard let status = userInfo["command_status"] as? String else { return nil }
        self.status = status
        commandID = userInfo["command_id"] as? String
        commandType = userInfo["command_type"] as? String
        result = userInfo["result"] as? String
        mealID = userInfo["meal_id"] as? String
        let alert = (userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
        message = alert?["body"] as? String
    }

    var isSuccess: Bool { status == "success" }
}

extension Notification.Name {
    /// Posted when a remote meal edit/delete reaches a terminal state, so treatment lists can refresh.
    static let remoteMealCommandDidComplete = Notification.Name("LoopFollow.remoteMealCommandDidComplete")
}

/// Tracks in-flight meal edit/delete commands to Trio and correlates Trio's acks by command id.
final class TRCCommandTracker: ObservableObject {
    static let shared = TRCCommandTracker()
    static let timeout: TimeInterval = 60

    struct PendingCommand: Identifiable, Equatable {
        let id: String
        let type: TRCCommandType
        let mealID: String
        let sentAt: Date
    }

    enum Outcome: Equatable {
        case deleted
        case updated(newMealID: String?)
        case notFound
        case rejected
        case failed
        case timedOut
        case sendFailed

        var isSuccess: Bool {
            switch self {
            case .deleted, .updated: return true
            default: return false
            }
        }
    }

    struct CompletedCommand: Equatable {
        let command: PendingCommand
        let outcome: Outcome
        let message: String?
        let completedAt: Date

        var isSuccess: Bool { outcome.isSuccess }

        var displayMessage: String {
            if let message, !message.isEmpty { return message }
            switch outcome {
            case .deleted: return "Meal deleted."
            case .updated: return "Meal updated."
            case .notFound: return "Trio could not find this meal. It may already have been deleted or changed on the phone."
            case .rejected: return "Trio rejected the command."
            case .failed: return "Trio reported a failure."
            case .timedOut: return "No confirmation from Trio yet. Refresh the list to check whether the change was applied."
            case .sendFailed: return "The command could not be sent."
            }
        }
    }

    @Published private(set) var pending: [String: PendingCommand] = [:]
    @Published private(set) var lastCompleted: [String: CompletedCommand] = [:]

    private var timeouts: [String: DispatchWorkItem] = [:]

    func pendingCommand(forMealID mealID: String) -> PendingCommand? {
        pending.values.first { $0.mealID == mealID }
    }

    func lastResult(forMealID mealID: String) -> CompletedCommand? {
        lastCompleted[mealID]
    }

    func sendDelete(mealID: String, completion: @escaping (Bool, String?) -> Void) {
        let command = register(type: .deleteMeal, mealID: mealID)
        PushNotificationManager().sendDeleteMealPushNotification(mealID: command.mealID, commandID: command.id) { [weak self] success, error in
            self?.handleSendResult(command, success: success, error: error, completion: completion)
        }
    }

    func sendEdit(mealID: String, carbs: Int, fat: Int, protein: Int, date: Date, completion: @escaping (Bool, String?) -> Void) {
        let command = register(type: .editMeal, mealID: mealID)
        PushNotificationManager().sendEditMealPushNotification(
            mealID: command.mealID,
            commandID: command.id,
            carbs: carbs,
            fat: fat,
            protein: protein,
            scheduledTime: date
        ) { [weak self] success, error in
            self?.handleSendResult(command, success: success, error: error, completion: completion)
        }
    }

    /// Returns true when the notification matched a pending command.
    @discardableResult
    func handleNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let ack = TRCCommandAck(userInfo: userInfo) else { return false }
        LogManager.shared.log(
            category: .apns,
            message: "TRC ack: type=\(ack.commandType ?? "-") status=\(ack.status) result=\(ack.result ?? "-") command_id=\(ack.commandID ?? "-")"
        )
        guard let commandID = ack.commandID, let command = pending[commandID] else { return false }

        let outcome: Outcome
        switch ack.result {
        case "deleted": outcome = .deleted
        case "updated": outcome = .updated(newMealID: ack.mealID)
        case "not_found": outcome = .notFound
        case "rejected": outcome = .rejected
        default:
            if ack.isSuccess {
                outcome = command.type == .deleteMeal ? .deleted : .updated(newMealID: ack.mealID)
            } else {
                outcome = .failed
            }
        }
        complete(command, outcome: outcome, message: ack.message)
        return true
    }

    // MARK: - Internal

    func register(type: TRCCommandType, mealID: String) -> PendingCommand {
        let command = PendingCommand(id: UUID().uuidString, type: type, mealID: mealID, sentAt: Date())
        DispatchQueue.main.async {
            self.pending[command.id] = command
            self.lastCompleted[mealID] = nil
        }
        return command
    }

    private func handleSendResult(_ command: PendingCommand, success: Bool, error: String?, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            guard success else {
                self.complete(command, outcome: .sendFailed, message: error)
                completion(false, error)
                return
            }
            let work = DispatchWorkItem { [weak self] in
                self?.complete(command, outcome: .timedOut, message: nil)
            }
            self.timeouts[command.id] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout, execute: work)
            LogManager.shared.log(category: .apns, message: "\(command.type.rawValue) sent command_id=\(command.id) meal_id=\(command.mealID)")
            completion(true, nil)
        }
    }

    func complete(_ command: PendingCommand, outcome: Outcome, message: String?) {
        DispatchQueue.main.async {
            self.timeouts[command.id]?.cancel()
            self.timeouts[command.id] = nil
            guard self.pending[command.id] != nil else { return }
            self.pending[command.id] = nil
            self.lastCompleted[command.mealID] = CompletedCommand(command: command, outcome: outcome, message: message, completedAt: Date())
            NotificationCenter.default.post(name: .remoteMealCommandDidComplete, object: nil, userInfo: ["mealID": command.mealID])
        }
    }
}
