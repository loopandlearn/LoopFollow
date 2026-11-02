// LoopFollow
// PumpSuspension.swift

import Foundation

/// Periods when the pump delivers no basal, from Trio's `PumpSuspend` and `PumpResume` notes.
enum PumpSuspension {
    static let suspendNote = "PumpSuspend"
    static let resumeNote = "PumpResume"

    /// Pairs each suspend with the next resume. A suspend without a resume lasts until the next
    /// temp basal starts, as Trio sets no temp basal while the pump is suspended. Without either it
    /// is still ongoing and ends at `.distantFuture`.
    static func intervals(notes: [(date: Date, note: String)], tempBasalStarts: [Date]) -> [DateInterval] {
        let events = notes
            .filter { $0.note == suspendNote || $0.note == resumeNote }
            .sorted { $0.date < $1.date }
        let tempStarts = tempBasalStarts.sorted()

        var result: [DateInterval] = []
        var suspendStart: Date?

        func close(at resume: Date?) {
            guard let start = suspendStart else { return }
            let nextTemp = tempStarts.first { $0 > start }
            let end = [resume, nextTemp].compactMap { $0 }.min() ?? .distantFuture
            if end > start {
                result.append(DateInterval(start: start, end: end))
            }
            suspendStart = nil
        }

        for event in events {
            if event.note == suspendNote {
                if let start = suspendStart, let nextTemp = tempStarts.first(where: { $0 > start }), nextTemp <= event.date {
                    close(at: nil)
                }
                if suspendStart == nil {
                    suspendStart = event.date
                }
            } else {
                close(at: event.date)
            }
        }
        close(at: nil)
        return result
    }

    /// The basal steps with the rate set to 0 inside the intervals. Each point's rate holds until
    /// the next point, as the chart draws them.
    static func applying(_ intervals: [DateInterval], to basal: [MainViewController.basalGraphStruct]) -> [MainViewController.basalGraphStruct] {
        guard !intervals.isEmpty else { return basal }
        let points = basal.sorted { $0.date < $1.date }
        let suspensions = intervals.sorted { $0.start < $1.start }
        var result: [MainViewController.basalGraphStruct] = []

        for (index, point) in points.enumerated() where index + 1 < points.count {
            let end = points[index + 1].date
            guard end > point.date else { continue }

            var cursor = point.date
            for suspension in suspensions {
                let suspendStart = max(suspension.start.timeIntervalSince1970, cursor)
                let suspendEnd = min(suspension.end.timeIntervalSince1970, end)
                guard suspendStart < suspendEnd else { continue }
                if cursor < suspendStart {
                    result.append(.init(basalRate: point.basalRate, date: cursor))
                    result.append(.init(basalRate: point.basalRate, date: suspendStart))
                }
                result.append(.init(basalRate: 0, date: suspendStart))
                result.append(.init(basalRate: 0, date: suspendEnd))
                cursor = suspendEnd
            }
            if cursor < end {
                result.append(.init(basalRate: point.basalRate, date: cursor))
                result.append(.init(basalRate: point.basalRate, date: end))
            }
        }
        if let last = points.last {
            let lastDate = Date(timeIntervalSince1970: last.date)
            let suspended = suspensions.contains { $0.start <= lastDate && lastDate < $0.end }
            result.append(.init(basalRate: suspended ? 0 : last.basalRate, date: last.date))
        }
        return result
    }
}
