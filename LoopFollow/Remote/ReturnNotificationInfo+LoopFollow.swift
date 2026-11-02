// LoopFollow
// ReturnNotificationInfo+LoopFollow.swift

import Foundation

extension ReturnNotificationInfo {
    /// How Loop or Trio reaches this LoopFollow app to confirm a command, or nil
    /// when LoopFollow's own APNs credentials or device token are missing.
    static func loopFollow() -> ReturnNotificationInfo? {
        let loopFollowDeviceToken = Observable.shared.loopFollowDeviceToken.value
        guard !loopFollowDeviceToken.isEmpty else { return nil }

        guard let loopFollowTeamID = BuildDetails.default.teamID, !loopFollowTeamID.isEmpty else {
            LogManager.shared.log(category: .apns, message: "LoopFollow Team ID not found in BuildDetails.plist. Cannot create return notification info.")
            return nil
        }

        let lfKeyId = Storage.shared.lfKeyId.value
        let lfApnsKey = Storage.shared.lfApnsKey.value

        guard !lfKeyId.isEmpty, !lfApnsKey.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Missing LoopFollow APNS credentials. Configure them in App Settings → APN.")
            return nil
        }

        return ReturnNotificationInfo(
            productionEnvironment: BuildDetails.default.isTestFlightBuild(),
            deviceToken: loopFollowDeviceToken,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            teamId: loopFollowTeamID,
            keyId: lfKeyId,
            apnsKey: lfApnsKey
        )
    }
}
