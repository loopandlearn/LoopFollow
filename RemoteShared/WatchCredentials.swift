// LoopFollow
// WatchCredentials.swift

import Foundation

/// What the watch needs to keep working without the phone: read access to the
/// data source and, when commands from the watch are allowed, what the phone
/// itself uses to send them. Sent with `transferUserInfo` only when it changes,
/// and kept in the watch's Keychain.
struct WatchCredentials: Codable, Equatable {
    static let userInfoKey = "watchCredentials"
    /// Watch → phone: asks the phone to send its credentials again.
    static let requestKey = "requestCredentials"

    var nightscoutURL: String
    var nightscoutToken: String
    var dexcomUsername: String
    var dexcomPassword: String
    /// "US" or anything else for outside the US, as in the phone's Dexcom settings.
    var dexcomServer: String
    /// Present only when remote commands from the watch are allowed.
    var remote: Remote?

    struct Remote: Codable, Equatable {
        var kind: WatchRemoteConfig.Kind
        /// Push target: the Loop or Trio app.
        var deviceToken: String
        var bundleID: String
        var production: Bool
        /// The key the phone signs commands with (LoopFollow's own key when both apps share a team).
        var apnsKey: String
        var keyID: String
        var teamID: String
        /// Trio Remote Control.
        var user: String
        var sharedSecret: String
        /// Loop: the one-time-password QR code URL.
        var loopQRCodeURL: String
        /// Lets Loop or Trio confirm a command to the LoopFollow app on the phone.
        var returnNotification: ReturnNotificationInfo?
    }

    var hasDataSource: Bool {
        !nightscoutURL.isEmpty || (!dexcomUsername.isEmpty && !dexcomPassword.isEmpty)
    }
}

/// Picks the key that signs commands to the Loop or Trio app: LoopFollow's own
/// key when both apps belong to the same team or no remote team is set,
/// otherwise the remote app's key.
enum RemoteSigningKey {
    static func resolve(
        lfTeamID: String,
        remoteTeamID: String,
        lfKey: (key: String, keyID: String),
        remoteKey: (key: String, keyID: String)
    ) -> (key: String, keyID: String, teamID: String) {
        let sameTeam = !lfTeamID.isEmpty && !remoteTeamID.isEmpty && lfTeamID == remoteTeamID
        if sameTeam || remoteTeamID.isEmpty {
            return (lfKey.key, lfKey.keyID, lfTeamID)
        }
        return (remoteKey.key, remoteKey.keyID, remoteTeamID)
    }
}
