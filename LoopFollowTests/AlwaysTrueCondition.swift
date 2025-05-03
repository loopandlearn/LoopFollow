//
//  AlwaysTrueCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-20.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import XCTest
@testable import LoopFollow
/*
struct AlwaysTrueCondition: AlarmCondition {
    static let type: AlarmType = .low
    init() {}
    func evaluate(alarm: Alarm, data: AlarmData) -> Bool { true }
}

final class CommonAlarmGuardsTests: XCTestCase {
    var now: Date!
    var config: AlarmConfiguration!
    var context: AlarmContext!
    var alarm: Alarm!
    var data: AlarmData!
    var cond: AlwaysTrueCondition!

    override func setUp() {
        super.setUp()
        now = Date()
        config = .default
        context = AlarmContext(now: now, config: config)

        alarm = Alarm(type: .low)
        alarm.name = "test"
        alarm.isEnabled = true
        alarm.snoozedUntil = nil
        alarm.playSoundOption = .always
        alarm.activeOption = .always
        alarm.snoozeDuration = 0

        data = AlarmData(expireDate: nil)
        cond = AlwaysTrueCondition()
    }

    func testMuteUntil() {
        config.muteUntil = now.addingTimeInterval(60)
        context = AlarmContext(now: now, config: config)
        XCTAssertFalse(cond.shouldFire(alarm: alarm, data: data, context: context))
    }

    func testDisabledAlarm() {
        alarm.isEnabled = false
        XCTAssertFalse(cond.shouldFire(alarm: alarm, data: data, context: context))
    }

    func testSnoozedAlarm() {
        alarm.snoozedUntil = now.addingTimeInterval(60)
        XCTAssertFalse(cond.shouldFire(alarm: alarm, data: data, context: context))
    }

    func testRespectsNightFlag() {
        let night = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        alarm.activeOption = .day // alarm should be inactive at night
        context = AlarmContext(now: night, config: config)
        XCTAssertFalse(cond.shouldFire(alarm: alarm, data: data, context: context))
    }

    func testRespectsDayFlag() {
        let day = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        alarm.activeOption = .night // alarm should be inactive during day
        context = AlarmContext(now: day, config: config)
        XCTAssertFalse(cond.shouldFire(alarm: alarm, data: data, context: context))
    }

    func testAllGuardsPass() {
        XCTAssertTrue(cond.shouldFire(alarm: alarm, data: data, context: context))
    }
}
*/
