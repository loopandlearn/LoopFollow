// LoopFollow
// RemoteType.swift

import Foundation

enum RemoteType: String, Codable {
    case none = "None"
    case nightscout = "Nightscout"
    case trc = "Trio Remote Control"
    case loopAPNS = "Loop APNS"
    case aaps = "AndroidAPS"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case RemoteType.none.rawValue:
            self = .none
        case RemoteType.nightscout.rawValue:
            self = .nightscout
        case RemoteType.trc.rawValue:
            self = .trc
        case RemoteType.loopAPNS.rawValue:
            self = .loopAPNS
        case RemoteType.aaps.rawValue, "Android APS", "Android APS SMS", "aaps", "sms", "SMS":
            self = .aaps
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown remote type: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
