// LoopFollow
// WatchCommandHandler.swift

import Foundation
import HealthKit

/// Executes commands from the watch with the same checks and send paths as the
/// phone's Remote screens. Runs on the main queue.
final class WatchCommandHandler {
    static let shared = WatchCommandHandler()

    private var handledIDs: [UUID] = []

    private init() {}

    /// The guardrails from the phone's Remote settings.
    static func limits() -> WatchCommandValidator.Limits {
        WatchCommandValidator.Limits(
            maxBolus: Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit()),
            bolusIncrement: Storage.shared.bolusIncrement.value.doubleValue(for: .internationalUnit()),
            maxCarbs: Storage.shared.maxCarbs.value.doubleValue(for: .gram()),
            maxFat: Storage.shared.maxFat.value.doubleValue(for: .gram()),
            maxProtein: Storage.shared.maxProtein.value.doubleValue(for: .gram()),
            mealWithBolus: Storage.shared.mealWithBolus.value,
            mealWithFatProtein: Storage.shared.mealWithFatProtein.value
        )
    }

    func handle(_ command: WatchCommand, reply: @escaping (WatchCommandReply) -> Void) {
        let finish: (Bool, String) -> Void = { success, message in
            LogManager.shared.log(category: .apns, message: "Watch command \(command.action.name) finished: success=\(success) \(message)")
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

        LogManager.shared.log(category: .apns, message: "Watch command received: \(command.action.name)")

        if case .snoozeAlarm = command.action {
            guard Observable.shared.currentAlarm.value != nil else {
                finish(false, "No alarm is active.")
                return
            }
            AlarmManager.shared.performSnooze()
            finish(true, "Alarm snoozed.")
            return
        }

        // Snoozing ahead needs no remote control: it changes LoopFollow's own alarms, like the
        // Snoozer's "Snooze all".
        if case let .snoozeAll(until) = command.action {
            var configuration = Storage.shared.alarmConfiguration.value
            if let until {
                guard until > Date(), until <= Date().addingTimeInterval(24 * 3600) else {
                    finish(false, "Choose a snooze of up to 24 hours.")
                    return
                }
                // As on the phone: an alarm sounding now is snoozed as well.
                if Observable.shared.currentAlarm.value != nil {
                    AlarmManager.shared.performSnooze()
                }
                configuration.snoozeUntil = until
                Storage.shared.alarmConfiguration.value = configuration
                finish(true, "All alarms snoozed until \(until.formatted(date: .omitted, time: .shortened)).")
            } else {
                configuration.snoozeUntil = nil
                Storage.shared.alarmConfiguration.value = configuration
                finish(true, "Snooze ended. Alarms are active.")
            }
            return
        }

        guard Storage.shared.watchRemoteCommands.value else {
            finish(false, "Commands from Apple Watch are turned off in LoopFollow's Remote settings.")
            return
        }
        guard let kind = WatchStateBuilder.remoteKind() else {
            finish(false, "Remote control is not set up in LoopFollow.")
            return
        }

        switch WatchCommandValidator.validate(command.action, kind: kind, limits: Self.limits()) {
        case let .failure(error):
            finish(false, error.message)
        case let .success(action):
            switch kind {
            case .loop: sendLoop(action, finish: finish)
            case .trio: sendTrio(action, finish: finish)
            }
        }
    }

    // MARK: - Loop

    private func sendLoop(_ action: WatchCommand.Action, finish: @escaping (Bool, String) -> Void) {
        let service = LoopAPNSService()
        let sent: (Bool, String?) -> Void = { success, error in
            DispatchQueue.main.async {
                finish(success, success ? RemoteCommandMessage.sent : (error ?? "Failed to send the command."))
            }
        }

        switch action {
        case let .bolus(units):
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

        case let .meal(carbs, _, _, _, consumedAt):
            guard service.validateSetup() else { return finish(false, loopSetupIncomplete) }
            guard let otp = loopOTP(finish: finish) else { return }
            let payload = LoopAPNSPayload(
                type: .carbs,
                carbsAmount: carbs,
                absorptionTime: WatchCommandValidator.loopAbsorptionHours,
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

        case .startTempTarget, .cancelTempTarget, .snoozeAlarm, .snoozeAll:
            finish(false, "This command is not available for Loop.")
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

    private func sendTrio(_ action: WatchCommand.Action, finish: @escaping (Bool, String) -> Void) {
        let manager = PushNotificationManager()
        let sent: (Bool, String?) -> Void = { success, error in
            DispatchQueue.main.async {
                finish(success, success ? RemoteCommandMessage.sent : (error ?? "Failed to send the command."))
            }
        }

        switch action {
        case let .bolus(units):
            manager.sendBolusPushNotification(bolusAmount: HKQuantity(unit: .internationalUnit(), doubleValue: units)) { success, error in
                if success {
                    DispatchQueue.main.async { QuickPickBolusesManager.shared.recordBolus(units: units) }
                }
                sent(success, error)
            }

        case let .meal(carbs, fat, protein, bolus, consumedAt):
            manager.sendMealPushNotification(
                carbs: HKQuantity(unit: .gram(), doubleValue: carbs),
                protein: HKQuantity(unit: .gram(), doubleValue: protein),
                fat: HKQuantity(unit: .gram(), doubleValue: fat),
                bolusAmount: HKQuantity(unit: .internationalUnit(), doubleValue: bolus),
                scheduledTime: WatchCommand.trioScheduledTime(consumedAt)
            ) { success, error in
                if success, carbs > 0 {
                    DispatchQueue.main.async {
                        QuickPickMealsManager.shared.recordMeal(carbs: carbs, fat: fat, protein: protein, bolus: bolus)
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

        case .snoozeAlarm, .snoozeAll:
            finish(false, "Unknown request.")
        }
    }
}
