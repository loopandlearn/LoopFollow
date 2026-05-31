// LoopFollow
// RemoteDiagnostics.swift

import Foundation

struct RemoteDiagnostics {
    enum Status: Equatable {
        case unknown
        case running
        case ok
        case failed(String)
    }

    var status: Status = .unknown
    var bundleMismatch: BundleMismatch?
    var bouncingTokens: BouncingTokens?
    var futureStartDate: FutureStartDate?

    var hasAnyWarning: Bool {
        bundleMismatch != nil || bouncingTokens != nil || futureStartDate != nil
    }

    struct BundleMismatch: Equatable {
        let expectedDevice: String
        let observedBundleId: String
    }

    struct BouncingTokens: Equatable {
        let distinctCount: Int
        let recordsScanned: Int
        let shifts: [TokenShift]
    }

    struct TokenShift: Equatable {
        let when: Date
        let fromToken: String
        let toToken: String
        let bundleIdentifier: String?
    }

    struct FutureStartDate: Equatable {
        let startDate: Date
    }
}
