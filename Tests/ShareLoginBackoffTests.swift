// LoopFollow
// ShareLoginBackoffTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct ShareLoginBackoffTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("a rejected login blocks the same credentials for fifteen minutes")
    func blocksSameCredentials() {
        ShareLoginBackoff.block(username: "user-a", password: "wrong", code: "AccountPasswordInvalid", now: start)
        #expect(ShareLoginBackoff.blockedCode(username: "user-a", password: "wrong", now: start.addingTimeInterval(899)) == "AccountPasswordInvalid")
        #expect(ShareLoginBackoff.blockedCode(username: "user-a", password: "wrong", now: start.addingTimeInterval(900)) == nil)
    }

    @Test("other credentials are not blocked")
    func otherCredentials() {
        ShareLoginBackoff.block(username: "user-b", password: "wrong", code: "AccountPasswordInvalid", now: start)
        #expect(ShareLoginBackoff.blockedCode(username: "user-b", password: "corrected", now: start.addingTimeInterval(1)) == nil)
        #expect(ShareLoginBackoff.blockedCode(username: "user-c", password: "wrong", now: start.addingTimeInterval(1)) == nil)
    }

    @Test("only account and password rejections block")
    func onlyRejections() {
        #expect(ShareLoginBackoff.rejectsCredentials("SSO_AuthenticatePasswordInvalid"))
        #expect(ShareLoginBackoff.rejectsCredentials("SSO_AuthenticateMaxAttemptsExceeed"))
        #expect(ShareLoginBackoff.rejectsCredentials("AccountNotFound"))
        #expect(!ShareLoginBackoff.rejectsCredentials("SSO_InternalError"))
        #expect(!ShareLoginBackoff.rejectsCredentials("unknown"))
    }
}
