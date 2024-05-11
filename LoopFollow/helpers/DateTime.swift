//
//  DateTime.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


class dateTimeUtils {
    
    static func getTimeIntervalMidnightToday() -> TimeInterval {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayString = formatter.string(from: now)
        var midnight = dayString + " 00:00:00"
        let newFormatter = DateFormatter()
        newFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        newFormatter.locale = Locale(identifier: "en_US")
        let newDate = newFormatter.date(from: midnight)
        guard let midnightTimeInterval = newDate?.timeIntervalSince1970 else { return 0 }
        return midnightTimeInterval
    }
    
    static func getTimeIntervalMidnightYesterday() -> TimeInterval {
        let now = Date().addingTimeInterval(-86400)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayString = formatter.string(from: now)
        var midnight = dayString + " 00:00:00"
        let newFormatter = DateFormatter()
        newFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        newFormatter.locale = Locale(identifier: "en_US")
        let newDate = newFormatter.date(from: midnight)
        guard let midnightTimeInterval = newDate?.timeIntervalSince1970 else { return 0 }
        return midnightTimeInterval
    }
    
    static func getTimeIntervalNHoursAgo(N: Int) -> TimeInterval {
        let today = Date()
        let nHoursAgo = Calendar.current.date(byAdding: .hour, value: -N, to: today)!
        return nHoursAgo.timeIntervalSince1970
    }
    
    static func getNowTimeIntervalUTC() -> TimeInterval {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let utc = formatter.string(from: now)
        let day = formatter.date(from: utc)
        guard let utcTime = day?.timeIntervalSince1970 else { return 0 }
        return utcTime
    }
    
    static func getDateTimeString(addingHours hours: Int? = nil, addingDays days: Int? = nil) -> String {
        let currentDate = Date()
        var date = currentDate
        
        if let hoursToAdd = hours {
            date = Calendar.current.date(byAdding: .hour, value: hoursToAdd, to: currentDate)!
        }
        
        if let daysToAdd = days {
            date = Calendar.current.date(byAdding: .day, value: daysToAdd, to: currentDate)!
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return dateFormatter.string(from: date)
    }

    static func printNow() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    static func is24Hour() -> Bool {
        let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)!

        return dateFormat.firstIndex(of: "a") == nil
    }

    static func formattedDate(from date: Date?) -> String {
        guard let date = date else {
            return "Unknown"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        return dateFormatter.string(from: date)
    }
}
