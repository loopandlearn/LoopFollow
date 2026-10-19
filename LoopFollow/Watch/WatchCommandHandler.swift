// LoopFollow
// WatchCommandHandler.swift

import Foundation
import HealthKit

/// Executes commands from the watch with the same checks and send paths as the
/// phone's Remote screens. Runs on the main queue.
final class WatchCommandHandler {
    static let shared = WatchCommandHandler()

    /// Loop rejects carb entries outside this window; same limits as LoopAPNSCarbsView.
    private let loopMaxPastHours: Double = 12
    private let loopMaxFutureHours: Double = 1
    /// Loop's default absorption time for a remote carb entry, in hours.
    private let loopAbsorptionHours = 3.0

    private var handledIDs: [UUID] = []

    private init() {}

    func handle(_ command: WatchCommand, reply: @escaping (WatchCommandReply) -> Void) {
        let finish: (Bool, String) -> Void = { success, message in
            LogManager.shared.log(category: .apns, message: "Watch command \(Self.name(of: command.action)) finished: success=\(success) \(message)")
            reply(WatchCommandReply(success: success, message: message))
        }

        guard !handledIDs.contains(command.id) else {
            finish(false, "This command was already handled.")
            return
        }
        handledIDs.append(command.id)
        if handledIDs.count > 50 { handledIDs.removeFirst() }

        guard abs(Date().timeIntervalSince(command.createdAt)) <= WatchCommand.maxAge else {
            finish(false, "The command arrived too late and was not sent. Try again.")
            return
        }

        LogManager.shared.log(category: .apns, message: "Watch command received: \(Self.name(of: command.action))")

        if case .snoozeAlarm = command.action {
            guard Observable.shared.currentAlarm.value != nil else {
                finish(false, "No alarm is active.")
                return
            }
            AlarmManager.shared.performSnooze()
            finish(true, "Alarm snoozed.")
            return
        }

        guard Storage.shared.watchRemoteCommands.value else {
            finish(false, "Commands from Apple Watch are turned off in LoopFollow's Remote settings.")
            return
        }

        switch WatchStateBuilder.remoteKind() {
        case .loop:
            handleLoop(command.action, finish: finish)
        case .trio:
            handleTrio(command.action, finish: finish)
        case nil:
            finish(false, "Remote control is not set up in LoopFollow.")
        }
    }

    // MARK: - Loop

    private func handleLoop(_ action: WatchCommand.Action, finish: @escaping (Bool, String) -> Void) {
        let service = LoopAPNSService()
        let sent: (Bool, String?) -> Void = { success, error in
            DispatchQueue.main.async {
                finish(success, success ? RemoteCommandMessage.sent : (error ?? "Failed to send the command."))
            }
        }

        switch action {
        case let .bolus(units):
            guard units > 0 else { return finish(false, "Enter an amount above zero.") }
            guard units <= maxBolus else { return finish(false, exceedsMaxBolus(units)) }
            guard service.validateSetup() else { return finish(false, loopSetupIncomplete) }
            guard let otp = loopOTP(finish: finish) else { return }
            service.sendBolusViaAPNS(payload: LoopAPNSPayload(type: .bolus, bolusAmount: units, otp: otp)) { success, error in
                DispatchQueue.main.async {
                    if success {
                        TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                        QuickPickBolusesManager.shared.recordBolus(units: units)
                    }
                }
                sent(success, error)
            }

        case let .meal(carbs, fat, protein, bolus, consumedAt):
            guard fat == 0, protein == 0, bolus == 0 else { return finish(false, "Loop accepts carbs only from the watch.") }
            guard carbs > 0 else { return finish(false, "Enter an amount above zero.") }
            guard carbs <= maxCarbs else { return finish(false, exceeds("Carbs", carbs, maxCarbs)) }
            let now = Date()
            guard consumedAt >= now.addingTimeInterval(-loopMaxPastHours * 3600) else {
                return finish(false, "Time must be within the prior \(Int(loopMaxPastHours)) hours.")
            }
            guard consumedAt <= now.addingTimeInterval(loopMaxFutureHours * 3600) else {
                return finish(false, "Time must be within the next \(Int(loopMaxFutureHours)) hour.")
            }
            guard service.validateSetup() else { return finish(false, loopSetupIncomplete) }
            guard let otp = loopOTP(finish: finish) else { return }
            let payload = LoopAPNSPayload(
                type: .carbs,
                carbsAmount: carbs,
                absorptionTime: loopAbsorptionHours,
                consumedDate: consumedAt.dateUsingCurrentSeconds(),
                otp: otp
            )
            service.sendCarbsViaAPNS(payload: payload) { success, error in
                DispatchQueue.main.async {
                    if success {
                        TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                        QuickPickMealsManager.shared.recordMeal(carbs: carbs)
                    }
                }
                sent(success, error)
            }

        case let .startOverride(presetID):
            guard let preset = ProfileManager.shared.loopOverrides.first(where: { $0.name == presetID }) else {
                return finish(false, "The override preset was not found.")
            }
            let duration = TimeInterval(preset.duration ?? 0)
            service.sendOverrideNotification(presetName: preset.name, duration: duration > 0 ? duration : nil, completion: sent)

        case .cancelOverride:
            service.sendCancelOverrideNotification(completion: sent)

        case .startTempTarget, .cancelTempTarget:
            finish(false, "Temp targets are not available for Loop.")

        case .snoozeAlarm:
            break
        }
    }

    private var loopSetupIncomplete: String {
        "Loop APNS setup is incomplete. Configure it in LoopFollow's Remote settings."
    }

    /// Mirrors the one-time code checks in the phone's Loop bolus and carbs screens.
    private func loopOTP(finish: (Bool, String) -> Void) -> String? {
        let url = Storage.shared.loopAPNSQrCodeURL.value
        guard let otp = TOTPGenerator.extractOTPFromURL(url) else {
            finish(false, "Invalid QR code URL. Re-scan the QR code in LoopFollow's Remote settings.")
            return nil
        }
        guard !TOTPService.shared.isTOTPBlocked(qrCodeURL: url) else {
            finish(false, "The current one-time code was already used. Wait for the next code (up to 30 seconds) and try again.")
            return nil
        }
        return otp
    }

    // MARK: - Trio

    private func handleTrio(_ action: WatchCommand.Action, finish: @escaping (Bool, String) -> Void) {
        let manager = PushNotificationManager()
        let sent: (Bool, String?) -> Void = { success, error in
            DispatchQueue.main.async {
                finish(success, success ? RemoteCommandMessage.sent : (error ?? "Failed to send the command."))
            }
        }

        switch action {
        case let .bolus(units):
            let stepped = roundedToBolusStep(units)
            guard stepped > 0 else { return finish(false, "Enter an amount above zero.") }
            guard stepped <= maxBolus else { return finish(false, exceedsMaxBolus(stepped)) }
            manager.sendBolusPushNotification(bolusAmount: HKQuantity(unit: .internationalUnit(), doubleValue: stepped)) { success, error in
                if success {
                    DispatchQueue.main.async { QuickPickBolusesManager.shared.recordBolus(units: stepped) }
                }
                sent(success, error)
            }

        case let .meal(carbs, fat, protein, bolus, consumedAt):
            let withFatProtein = Storage.shared.mealWithFatProtein.value
            let withBolus = Storage.shared.mealWithBolus.value
            guard withFatProtein || (fat == 0 && protein == 0) else { return finish(false, "Meal with Fat/Protein is turned off in LoopFollow's Remote settings.") }
            guard withBolus || bolus == 0 else { return finish(false, "Meal with Bolus is turned off in LoopFollow's Remote settings.") }
            guard carbs >= 0, fat >= 0, protein >= 0, carbs > 0 || fat > 0 || protein > 0 else {
                return finish(false, "Enter carbs, fat or protein.")
            }
            guard carbs <= maxCarbs else { return finish(false, exceeds("Carbs", carbs, maxCarbs)) }
            guard fat <= Storage.shared.maxFat.value.doubleValue(for: .gram()) else {
                return finish(false, exceeds("Fat", fat, Storage.shared.maxFat.value.doubleValue(for: .gram())))
            }
            guard protein <= Storage.shared.maxProtein.value.doubleValue(for: .gram()) else {
                return finish(false, exceeds("Protein", protein, Storage.shared.maxProtein.value.doubleValue(for: .gram())))
            }
            let steppedBolus = roundedToBolusStep(bolus)
            guard steppedBolus <= maxBolus else { return finish(false, exceedsMaxBolus(steppedBolus)) }

            // Within a minute of now counts as "now", as in the phone's meal screen.
            let scheduledTime: Date? = abs(consumedAt.timeIntervalSinceNow) < 60 ? nil : consumedAt.dateUsingCurrentSeconds()
            manager.sendMealPushNotification(
                carbs: HKQuantity(unit: .gram(), doubleValue: carbs),
                protein: HKQuantity(unit: .gram(), doubleValue: protein),
                fat: HKQuantity(unit: .gram(), doubleValue: fat),
                bolusAmount: HKQuantity(unit: .internationalUnit(), doubleValue: steppedBolus),
                scheduledTime: scheduledTime
            ) { success, error in
                if success, carbs > 0 {
                    DispatchQueue.main.async {
                        QuickPickMealsManager.shared.recordMeal(carbs: carbs, fat: fat, protein: protein, bolus: steppedBolus)
                    }
                }
                sent(success, error)
            }

        case let .startOverride(presetID):
            guard let override = ProfileManager.shared.trioOverrides.first(where: { $0.name == presetID }) else {
                return finish(false, "The override preset was not found.")
            }
            manager.sendOverridePushNotification(override: override, completion: sent)

        case .cancelOverride:
            manager.sendCancelOverridePushNotification(completion: sent)

        case let .startTempTarget(presetID):
            guard let preset = TempTargetPresetManager.shared.presets.first(where: { $0.id.uuidString == presetID }) else {
                return finish(false, "The temp target preset was not found.")
            }
            manager.sendTempTargetPushNotification(target: preset.target, duration: preset.duration, completion: sent)

        case .cancelTempTarget:
            manager.sendCancelTempTargetPushNotification(completion: sent)

        case .snoozeAlarm:
            break
        }
    }

    // MARK: - Helpers

    private var maxBolus: Double {
        Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit())
    }

    private var maxCarbs: Double {
        Storage.shared.maxCarbs.value.doubleValue(for: .gram())
    }

    /// Rounds down to the bolus increment, as the phone's Trio bolus screen does.
    private func roundedToBolusStep(_ value: Double) -> Double {
        let step = max(0.001, Storage.shared.bolusIncrement.value.doubleValue(for: .internationalUnit()))
        let stepped = ((value / step) + 1e-10).rounded(.down) * step
        return (stepped * 1000).rounded() / 1000
    }

    private func exceedsMaxBolus(_ units: Double) -> String {
        "\(InsulinFormatter.shared.string(units)) U exceeds the maximum bolus of \(InsulinFormatter.shared.string(maxBolus)) U set in LoopFollow."
    }

    private func exceeds(_ what: String, _ grams: Double, _ max: Double) -> String {
        "\(what) (\(Int(grams)) g) exceeds the maximum of \(Int(max)) g set in LoopFollow."
    }

    private static func name(of action: WatchCommand.Action) -> String {
        switch action {
        case .bolus: "bolus"
        case .meal: "meal"
        case .startOverride: "startOverride"
        case .cancelOverride: "cancelOverride"
        case .startTempTarget: "startTempTarget"
        case .cancelTempTarget: "cancelTempTarget"
        case .snoozeAlarm: "snoozeAlarm"
        }
    }
}
