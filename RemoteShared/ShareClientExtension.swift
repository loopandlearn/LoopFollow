// LoopFollow
// ShareClientExtension.swift

import Foundation
#if canImport(ShareClient)
    import ShareClient
#endif

public struct ShareGlucoseData: Decodable {
    var sgv: Int
    var date: TimeInterval
    var direction: String?

    enum CodingKeys: String, CodingKey {
        case sgv // Sensor Blood Glucose
        case mbg // Manual Blood Glucose
        case glucose // Other type of entry
        case date
        case direction
    }

    // Decoder initializer for handling JSON data
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let glucoseValue = try? container.decode(Double.self, forKey: .sgv) {
            sgv = Int(glucoseValue.rounded())
        } else if let mbgValue = try? container.decode(Double.self, forKey: .mbg) {
            sgv = Int(mbgValue.rounded())
        } else if let mbgValue = try? container.decode(Double.self, forKey: .glucose) {
            sgv = Int(mbgValue.rounded())
        } else {
            throw DecodingError.dataCorruptedError(forKey: .sgv, in: container, debugDescription: "Expected to decode Double for sgv, mbg or glucose.")
        }

        // Decode the date and optional direction
        date = try container.decode(TimeInterval.self, forKey: .date)
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
    }

    public init(sgv: Int, date: TimeInterval, direction: String?) {
        self.sgv = sgv
        self.date = date
        self.direction = direction
    }
}

private var TrendTable: [String] = [
    "NONE", // 0
    "DoubleUp", // 1
    "SingleUp", // 2
    "FortyFiveUp", // 3
    "Flat", // 4
    "FortyFiveDown", // 5
    "SingleDown", // 6
    "DoubleDown", // 7
    "NOT COMPUTABLE", // 8
    "RATE OUT OF RANGE", // 9
]

/// Share locks an account after repeated bad logins, so a login it rejects for the account or
/// password blocks further logins with the same credentials on the same Share server for
/// `interval`. Other failures are tried again at the next fetch.
enum ShareLoginBackoff {
    static let interval: TimeInterval = 15 * 60

    private static let lock = NSLock()
    private static var blocks: [String: (until: Date, code: String)] = [:]

    private static func key(_ server: String, _ username: String, _ password: String) -> String {
        "\(server)\n\(username)\n\(password)"
    }

    /// The rejection code while logins with these credentials are blocked, else nil.
    static func blockedCode(server: String, username: String, password: String, now: Date = Date()) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let block = blocks[key(server, username, password)], now < block.until else { return nil }
        return block.code
    }

    static func block(server: String, username: String, password: String, code: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        blocks[key(server, username, password)] = (now.addingTimeInterval(interval), code)
    }

    /// Share's codes for an unknown account, a wrong password or too many attempts.
    static func rejectsCredentials(_ code: String) -> Bool {
        [
            "AccountPasswordInvalid", "AccountNotFound", "SSO_AuthenticatePasswordInvalid",
            "SSO_AuthenticateAccountNotFound", "SSO_AuthenticateMaxAttemptsExceeed", "SSO_AuthenticateMaxAttemptsExceeded",
        ].contains(code)
    }
}

public extension ShareClient {
    /// The Share server URL this client logs in to. ShareClient keeps it private.
    private var serverURL: String {
        Mirror(reflecting: self).children.first { $0.label == "shareServer" }?.value as? String ?? ""
    }

    func fetchData(_ entries: Int, callback: @escaping (ShareError?, [ShareGlucoseData]?) -> Void) {
        let server = serverURL
        if let code = ShareLoginBackoff.blockedCode(server: server, username: username, password: password) {
            return callback(.loginError(errorCode: code), nil)
        }
        fetchLast(entries) { [username, password] error, result in
            if case let .loginError(code)? = error, ShareLoginBackoff.rejectsCredentials(code) {
                ShareLoginBackoff.block(server: server, username: username, password: password, code: code)
            }
            guard error == nil, let result = result else {
                return callback(error ?? .fetchError, nil)
            }

            // parse data to conanical form
            var shareData = [ShareGlucoseData]()
            for item in result {
                var trend = Int(item.trend)
                if trend < 0 || trend >= TrendTable.count {
                    trend = 0
                }

                let newShareData = ShareGlucoseData(
                    sgv: Int(item.glucose),
                    date: item.timestamp.timeIntervalSince1970,
                    direction: TrendTable[trend]
                )
                shareData.append(newShareData)
            }
            callback(nil, shareData)
        }
    }
}
