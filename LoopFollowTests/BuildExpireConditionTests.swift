//
//  BuildExpireConditionTests.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-20.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

@testable import LoopFollow
import XCTest

final class BuildExpireConditionTests: XCTestCase {
    let cond = BuildExpireCondition()
    var alarm: Alarm!

    override func setUp() {
        super.setUp()
        alarm = Alarm(type: .buildExpire)
        alarm.threshold = 7 // 7 days before expiration
    }

    func testEvaluateWhenWithinThreshold() {
        let now = Date()
        // Build expires in 6 days → within threshold (7 days)
        let expiryDate = Calendar.current.date(byAdding: .day, value: 6, to: now)!
        let data = AlarmData(expireDate: expiryDate)
        XCTAssertTrue(cond.evaluate(alarm: alarm, data: data))
    }

    func testEvaluateWhenOutsideThreshold() {
        let now = Date()
        // Build expires in 10 days → outside threshold (7 days)
        let expiryDate = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        let data = AlarmData(expireDate: expiryDate)
        XCTAssertFalse(cond.evaluate(alarm: alarm, data: data))
    }

    func testEvaluateWhenNoExpireDate() {
        let data = AlarmData(expireDate: nil)
        XCTAssertFalse(cond.evaluate(alarm: alarm, data: data))
    }

    func testEvaluateWhenNoThreshold() {
        // Clear threshold
        alarm.threshold = nil
        let now = Date()
        let expiryDate = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        let data = AlarmData(expireDate: expiryDate)
        XCTAssertFalse(cond.evaluate(alarm: alarm, data: data))
    }
}
