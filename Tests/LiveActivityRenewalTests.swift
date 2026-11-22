// LoopFollow
// LiveActivityRenewalTests.swift

#if !targetEnvironment(macCatalyst)

    @testable import LoopFollow
    import Testing

    struct LiveActivityRenewalTests {
        private let now: Double = 1_800_000_000

        private func needsReplacing(renewBy: Double, renewalFailed: Bool = false) -> Bool {
            LiveActivityManager.existingActivityNeedsReplacing(renewBy: renewBy, renewalFailed: renewalFailed, now: now)
        }

        @Test("A healthy activity outside the renewal window is reused")
        func healthyIsReused() {
            #expect(!needsReplacing(renewBy: now + LiveActivityManager.renewalWarning + 1))
        }

        @Test("An activity is replaced from the start of the renewal window onward")
        func renewalWindow() {
            #expect(needsReplacing(renewBy: now + LiveActivityManager.renewalWarning))
            #expect(needsReplacing(renewBy: now))
            #expect(needsReplacing(renewBy: now - 3600))
        }

        @Test("A failed renewal forces replacement even with time left")
        func failedRenewal() {
            #expect(needsReplacing(renewBy: now + 4 * 3600, renewalFailed: true))
        }

        @Test("An activity with no stored deadline is replaced, since it could never renew")
        func missingDeadline() {
            #expect(needsReplacing(renewBy: 0))
        }
    }

#endif
