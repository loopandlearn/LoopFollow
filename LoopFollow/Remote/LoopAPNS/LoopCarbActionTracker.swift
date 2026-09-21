// LoopFollow
// LoopCarbActionTracker.swift

import Foundation

/// Sends carb delete/edit commands to Loop and tracks their outcome.
///
/// Loop's return push (`command_type` `carbs_delete`/`carbs_edit`, `sync_identifier`,
/// `command_status`) is the primary confirmation. Nightscout is polled by `syncIdentifier`
/// as a fallback: a delete is confirmed when the entry disappears, an edit when the new
/// values are published, and a failure Note from Loop reports the error.
final class LoopCarbActionTracker: ObservableObject {
    static let ackCommandTypes: Set<String> = ["carbs_delete", "carbs_edit"]
    static let shared = LoopCarbActionTracker()
    static let pollInterval: TimeInterval = 10
    static let timeout: TimeInterval = 120

    enum State: Equatable {
        case idle
        case sending
        case awaitingConfirmation(since: Date)
        case confirmed
        case failed(String)
        case timedOut

        var isTerminal: Bool {
            switch self {
            case .confirmed, .failed, .timedOut: return true
            default: return false
            }
        }

        var message: String? {
            switch self {
            case .idle: return nil
            case .sending: return "Sending…"
            case .awaitingConfirmation: return "Sent, waiting for Nightscout to reflect the change…"
            case .confirmed: return "Confirmed."
            case let .failed(message): return message
            case .timedOut: return "Loop may have applied the change but Nightscout was not updated. Refresh the list to check."
            }
        }
    }

    private enum Expectation {
        case deleted
        case edited(carbs: Double, absorptionMinutes: Double)
    }

    private struct Operation {
        let syncIdentifier: String
        let actionName: String
        let sentAt: Date
        let expectation: Expectation
    }

    @Published private(set) var states: [String: State] = [:]

    private var operations: [String: Operation] = [:]
    private var timers: [String: Timer] = [:]

    func state(forSyncIdentifier syncIdentifier: String) -> State {
        states[syncIdentifier] ?? .idle
    }

    func isBusy(syncIdentifier: String) -> Bool {
        switch state(forSyncIdentifier: syncIdentifier) {
        case .sending, .awaitingConfirmation: return true
        default: return false
        }
    }

    func sendDelete(carb: LoopCarbTreatment, completion: @escaping (Bool, String?) -> Void) {
        guard let otp = currentOTP(completion: completion) else { return }
        setState(.sending, for: carb.syncIdentifier)
        LoopAPNSService().sendCarbsDelete(syncIdentifier: carb.syncIdentifier, otp: otp) { [weak self] success, error in
            self?.handleSendResult(
                Operation(syncIdentifier: carb.syncIdentifier, actionName: "Delete Carbs", sentAt: Date(), expectation: .deleted),
                success: success,
                error: error,
                completion: completion
            )
        }
    }

    func sendEdit(carb: LoopCarbTreatment, carbsAmount: Double, absorptionHours: Double, foodType: String?, consumedDate: Date?, completion: @escaping (Bool, String?) -> Void) {
        guard let otp = currentOTP(completion: completion) else { return }
        setState(.sending, for: carb.syncIdentifier)
        LoopAPNSService().sendCarbsEdit(
            syncIdentifier: carb.syncIdentifier,
            carbsAmount: carbsAmount,
            absorptionTimeHours: absorptionHours,
            foodType: foodType,
            consumedDate: consumedDate,
            otp: otp
        ) { [weak self] success, error in
            self?.handleSendResult(
                Operation(
                    syncIdentifier: carb.syncIdentifier,
                    actionName: "Edit Carbs",
                    sentAt: Date(),
                    expectation: .edited(carbs: carbsAmount, absorptionMinutes: absorptionHours * 60)
                ),
                success: success,
                error: error,
                completion: completion
            )
        }
    }

    /// Returns true when the notification is a Loop carb command ack (matched or not).
    @discardableResult
    func handleNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let commandType = userInfo["command_type"] as? String,
              Self.ackCommandTypes.contains(commandType),
              let status = userInfo["command_status"] as? String
        else { return false }
        let syncIdentifier = userInfo["sync_identifier"] as? String
        let alert = (userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
        let message = alert?["body"] as? String
        LogManager.shared.log(
            category: .apns,
            message: "Loop ack: type=\(commandType) status=\(status) sync_identifier=\(syncIdentifier.map { LogRedactor.tail($0) } ?? "-")"
        )
        guard let syncIdentifier, operations[syncIdentifier] != nil else { return true }
        let state: State = status == "success" ? .confirmed : .failed(message ?? "Loop reported a failure.")
        DispatchQueue.main.async { self.finish(syncIdentifier, state: state) }
        return true
    }

    // MARK: - Internal

    private func currentOTP(completion: (Bool, String?) -> Void) -> String? {
        let qrCodeURL = Storage.shared.loopAPNSQrCodeURL.value
        guard let otp = TOTPGenerator.extractOTPFromURL(qrCodeURL) else {
            completion(false, "Invalid QR code URL. Please re-scan the QR code in settings.")
            return nil
        }
        guard !TOTPService.shared.isTOTPBlocked(qrCodeURL: qrCodeURL) else {
            completion(false, "The current one-time code was already used. Wait for the next code and try again.")
            return nil
        }
        return otp
    }

    private func handleSendResult(_ operation: Operation, success: Bool, error: String?, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            guard success else {
                self.finish(operation.syncIdentifier, state: .failed(error ?? "The command could not be sent."))
                completion(false, error)
                return
            }
            TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
            LogManager.shared.log(category: .apns, message: "\(operation.actionName) sent for syncIdentifier=\(LogRedactor.tail(operation.syncIdentifier))")
            self.operations[operation.syncIdentifier] = operation
            self.setState(.awaitingConfirmation(since: operation.sentAt), for: operation.syncIdentifier)
            let timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                self?.poll(operation.syncIdentifier)
            }
            self.timers[operation.syncIdentifier] = timer
            completion(true, nil)
        }
    }

    private func poll(_ syncIdentifier: String) {
        guard let operation = operations[syncIdentifier] else { return }
        if Date().timeIntervalSince(operation.sentAt) > Self.timeout {
            finish(syncIdentifier, state: .timedOut)
            return
        }

        fetchTreatments(parameters: ["find[syncIdentifier]": syncIdentifier, "count": "1"]) { [weak self] entries in
            guard let self, let entries else { return }
            let confirmed: Bool
            switch operation.expectation {
            case .deleted:
                confirmed = entries.isEmpty
            case let .edited(carbs, absorptionMinutes):
                confirmed = entries.contains { entry in
                    let entryCarbs = (entry["carbs"] as? NSNumber)?.doubleValue ?? -1
                    let entryAbsorption = (entry["absorptionTime"] as? NSNumber)?.doubleValue ?? -1
                    return abs(entryCarbs - carbs.rounded()) < 0.5 && abs(entryAbsorption - absorptionMinutes) < 1
                }
            }
            if confirmed {
                DispatchQueue.main.async { self.finish(syncIdentifier, state: .confirmed) }
                return
            }
            self.checkFailureNote(for: operation)
        }
    }

    private func checkFailureNote(for operation: Operation) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let since = formatter.string(from: operation.sentAt.addingTimeInterval(-60))
        fetchTreatments(parameters: ["find[eventType]": "Note", "find[created_at][$gte]": since, "count": "10"]) { [weak self] entries in
            guard let self, let entries else { return }
            let failure = entries.first { entry in
                (entry["enteredBy"] as? String)?.hasPrefix(operation.actionName) == true
            }
            guard let failure else { return }
            let notes = (failure["notes"] as? String) ?? ""
            let firstLine = notes.split(separator: "\n").first.map(String.init) ?? "Loop rejected the command."
            DispatchQueue.main.async { self.finish(operation.syncIdentifier, state: .failed(firstLine)) }
        }
    }

    private func fetchTreatments(parameters: [String: String], completion: @escaping ([[String: AnyObject]]?) -> Void) {
        guard let url = NightscoutUtils.constructURL(
            baseURL: Storage.shared.url.value,
            token: Storage.shared.token.value,
            endpoint: "/api/v1/treatments.json",
            parameters: parameters
        ) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data,
                  let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: AnyObject]]
            else {
                completion(nil)
                return
            }
            completion(entries)
        }.resume()
    }

    private func setState(_ state: State, for syncIdentifier: String) {
        DispatchQueue.main.async { self.states[syncIdentifier] = state }
    }

    private func finish(_ syncIdentifier: String, state: State) {
        timers[syncIdentifier]?.invalidate()
        timers[syncIdentifier] = nil
        operations[syncIdentifier] = nil
        states[syncIdentifier] = state
        LogManager.shared.log(category: .apns, message: "Loop carb command for syncIdentifier=\(LogRedactor.tail(syncIdentifier)) finished: \(state)")
        NotificationCenter.default.post(name: .remoteMealCommandDidComplete, object: nil, userInfo: ["syncIdentifier": syncIdentifier])
    }
}
