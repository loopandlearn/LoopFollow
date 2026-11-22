// LoopFollow
// ShareLoginBackoffTests.swift

import Foundation
@testable import LoopFollow
import ShareClient
import Testing

struct ShareLoginBackoffTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let us = KnownShareServers.US.rawValue
    private let nonUS = KnownShareServers.NON_US.rawValue

    @Test("a rejected login blocks the same credentials for fifteen minutes")
    func blocksSameCredentials() {
        ShareLoginBackoff.block(server: us, username: "user-a", password: "wrong", code: "AccountPasswordInvalid", now: start)
        #expect(ShareLoginBackoff.blockedCode(server: us, username: "user-a", password: "wrong", now: start.addingTimeInterval(899)) == "AccountPasswordInvalid")
        #expect(ShareLoginBackoff.blockedCode(server: us, username: "user-a", password: "wrong", now: start.addingTimeInterval(900)) == nil)
    }

    @Test("other credentials are not blocked")
    func otherCredentials() {
        ShareLoginBackoff.block(server: us, username: "user-b", password: "wrong", code: "AccountPasswordInvalid", now: start)
        #expect(ShareLoginBackoff.blockedCode(server: us, username: "user-b", password: "corrected", now: start.addingTimeInterval(1)) == nil)
        #expect(ShareLoginBackoff.blockedCode(server: us, username: "user-c", password: "wrong", now: start.addingTimeInterval(1)) == nil)
    }

    @Test("the same credentials on another Share server are not blocked")
    func otherServer() {
        ShareLoginBackoff.block(server: us, username: "user-d", password: "secret", code: "AccountPasswordInvalid", now: start)
        #expect(ShareLoginBackoff.blockedCode(server: nonUS, username: "user-d", password: "secret", now: start.addingTimeInterval(1)) == nil)
    }

    @Test("a blocked client answers with the rejection without contacting Share")
    func blockedClientUsesServer() async {
        let client = ShareClient(username: "user-e", password: "wrong", shareServer: nonUS)
        ShareLoginBackoff.block(server: nonUS, username: "user-e", password: "wrong", code: "AccountPasswordInvalid")
        let error: ShareError? = await withCheckedContinuation { continuation in
            client.fetchData(1) { error, _ in continuation.resume(returning: error) }
        }
        guard case let .loginError(code)? = error else {
            Issue.record("expected a login error, got \(String(describing: error))")
            return
        }
        #expect(code == "AccountPasswordInvalid")
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
