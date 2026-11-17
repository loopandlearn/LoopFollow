// LoopFollow
// WatchCredentialsBuilder.swift

import Foundation

/// Collects what the watch needs to fetch data and send commands on its own.
enum WatchCredentialsBuilder {
    static func build() -> WatchCredentials {
        WatchCredentials(
            nightscoutURL: Storage.shared.url.value,
            nightscoutToken: Storage.shared.token.value,
            dexcomUsername: Storage.shared.shareUserName.value,
            dexcomPassword: Storage.shared.sharePassword.value,
            dexcomServer: Storage.shared.shareServer.value,
            remote: remote(),
            phoneSleeps: BackgroundRefreshType.inEffect == .hub
        )
    }

    private static func remote() -> WatchCredentials.Remote? {
        guard Storage.shared.watchRemoteCommands.value, let kind = WatchStateBuilder.remoteKind() else { return nil }
        let signing = RemoteSigningKey.resolve(
            lfTeamID: BuildDetails.default.teamID ?? "",
            remoteTeamID: Storage.shared.teamId.value ?? "",
            lfKey: (Storage.shared.lfApnsKey.value, Storage.shared.lfKeyId.value),
            remoteKey: (Storage.shared.remoteApnsKey.value, Storage.shared.remoteKeyId.value)
        )
        return WatchCredentials.Remote(
            kind: kind,
            deviceToken: Storage.shared.deviceToken.value,
            bundleID: Storage.shared.bundleId.value,
            production: Storage.shared.productionEnvironment.value,
            apnsKey: signing.key,
            keyID: signing.keyID,
            teamID: signing.teamID,
            user: Storage.shared.user.value,
            sharedSecret: Storage.shared.sharedSecret.value,
            loopQRCodeURL: Storage.shared.loopAPNSQrCodeURL.value,
            returnNotification: ReturnNotificationInfo.loopFollow()
        )
    }
}
