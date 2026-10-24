// LoopFollow
// APNSEnvironment.swift

import Foundation

enum APNSEnvironment {
    /// Base URL of the APNs HTTP/2 endpoint. Debug builds honor `LOOPFOLLOW_APNS_BASE_URL` as a local stand-in.
    static func baseURL(production: Bool) -> String {
        #if DEBUG
            if let override = ProcessInfo.processInfo.environment["LOOPFOLLOW_APNS_BASE_URL"], !override.isEmpty {
                return override
            }
        #endif
        return production ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com"
    }
}
