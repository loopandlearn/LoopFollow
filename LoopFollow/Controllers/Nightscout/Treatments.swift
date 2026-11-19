// LoopFollow
// Treatments.swift

import Foundation

extension MainViewController {
    private struct TreatmentOccurrence: Hashable {
        let id: String
        let eventType: String?
        let date: Date?
    }

    /// Nightscout duplicates can have different MongoDB `_id` values. Trio FPU siblings share an `id` but have distinct
    /// times, so deduplicate by logical occurrence rather than `id`.
    static func deduplicatedTreatmentEntries(_ entries: [[String: AnyObject]]) -> [[String: AnyObject]] {
        var seenOccurrences = Set<TreatmentOccurrence>()
        return entries.filter { entry in
            guard let id = entry["id"] as? String, !id.isEmpty else { return true }
            let eventType = entry["eventType"] as? String
            let occurrence = TreatmentOccurrence(
                id: id,
                eventType: eventType,
                date: treatmentOccurrenceDate(entry, eventType: eventType)
            )
            return seenOccurrences.insert(occurrence).inserted
        }
    }

    private static func treatmentOccurrenceDate(_ entry: [String: AnyObject], eventType: String?) -> Date? {
        let rawDate: String?
        switch eventType {
        case "Pump Site Change", "Site Change", "Sensor Start", "Insulin Change":
            rawDate = entry["created_at"] as? String
        default:
            rawDate = (entry["timestamp"] as? String) ?? (entry["created_at"] as? String)
        }
        return rawDate.flatMap(NightscoutUtils.parseDate)
    }

    /// The greatest 24-hex-digit `_id` among the entries. Nightscout `_id`s are Mongo ObjectIds, which sort by server insert time
    /// (first 8 hex digits, seconds); ids dated more than 5 minutes after `now` are skipped.
    static func knownThroughID(_ entries: [[String: AnyObject]], now: Date = Date()) -> String? {
        let latest = now.addingTimeInterval(5 * 60).timeIntervalSince1970
        return entries
            .compactMap { $0["_id"] as? String }
            .filter { $0.count == 24 && $0.allSatisfy { $0.isASCII && $0.isHexDigit } }
            .filter { UInt32($0.prefix(8), radix: 16).map { TimeInterval($0) <= latest } ?? false }
            .map { $0.lowercased() }
            .max()
    }

    /// The Nightscout site and hub a treatments download reads from; the marker is cleared when any of them changes.
    struct TreatmentsSite: Equatable {
        let url: String
        let token: String
        let hubURL: String
        var hubMode = false
        var deviceKey = ""

        static var current: TreatmentsSite {
            TreatmentsSite(
                url: Storage.shared.url.value,
                token: Storage.shared.token.value,
                hubURL: Storage.shared.hubURL.value,
                hubMode: HubClient.shared.isHubMode,
                deviceKey: HubClient.shared.deviceKey.value
            )
        }
    }

    /// Stores the marker of a download that started at `site`, provided the site is still `current` and treatments are still downloaded.
    static func storeKnownThroughID(
        _ entries: [[String: AnyObject]],
        fetchedFrom site: TreatmentsSite,
        current: TreatmentsSite = .current,
        downloadsTreatments: Bool = Storage.shared.downloadTreatments.value,
        now: Date = Date()
    ) {
        guard site == current, downloadsTreatments else {
            LogManager.shared.log(category: .nightscout, message: "Treatments marker skipped: the site or the treatment download changed during the download")
            return
        }
        Observable.shared.treatmentsKnownThroughID.value = knownThroughID(entries, now: now)
    }

    // NS Treatments Web Call
    // Downloads Basal, Bolus, Carbs, BG Check, Notes, Overrides
    func WebLoadNSTreatments() {
        if !Storage.shared.downloadTreatments.value { return }

        let startTimeString = dateTimeUtils.getDateTimeString(addingDays: -1 * Storage.shared.downloadDays.value)
        let endTimeString = dateTimeUtils.getDateTimeString(addingHours: 6)
        let estimatedCount = max(Storage.shared.downloadDays.value * 100, 5000)
        let parameters: [String: String] = [
            "find[created_at][$gte]": startTimeString,
            "find[created_at][$lte]": endTimeString,
            "count": "\(estimatedCount)",
        ]
        let site = TreatmentsSite.current
        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: parameters, hubPart: .treatments) { (result: Result<Any, Error>) in
            switch result {
            case let .success(data):
                if let entries = data as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.updateTreatments(entries: entries, site: site)
                    }
                } else {
                    LogManager.shared.log(category: .nightscout, message: "WebLoadNSTreatments, Unexpected data structure")
                }
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "WebLoadNSTreatments, error \(error.localizedDescription)")
            }
        }
    }

    // Process and split out treatments to individual tasks
    func updateTreatments(entries: [[String: AnyObject]], site: TreatmentsSite) {
        Self.storeKnownThroughID(entries, fetchedFrom: site)
        let uniqueEntries = Self.deduplicatedTreatmentEntries(entries)

        var tempBasal: [[String: AnyObject]] = []
        var bolus: [[String: AnyObject]] = []
        var smb: [[String: AnyObject]] = []
        var carbs: [[String: AnyObject]] = []
        var temporaryOverride: [[String: AnyObject]] = []
        var temporaryTarget: [[String: AnyObject]] = []
        var note: [[String: AnyObject]] = []
        var bgCheck: [[String: AnyObject]] = []
        var suspendPump: [[String: AnyObject]] = []
        var resumePump: [[String: AnyObject]] = []
        var pumpSiteChange: [cageData] = []
        var cgmSensorStart: [sageData] = []
        var insulinCartridge: [iageData] = []

        for entry in uniqueEntries {
            guard let eventType = entry["eventType"] as? String else {
                continue
            }

            switch eventType {
            case "Temp Basal":
                tempBasal.append(entry)
            case "Correction Bolus", "Bolus", "External Insulin":
                if let automatic = entry["automatic"] as? Bool, automatic {
                    smb.append(entry)
                } else {
                    bolus.append(entry)
                }
            case "SMB":
                smb.append(entry)
            case "Meal Bolus":
                carbs.append(entry)
                bolus.append(entry)
            case "Carb Correction":
                carbs.append(entry)
            case "Temporary Override", "Exercise":
                temporaryOverride.append(entry)
            case "Temporary Target":
                temporaryTarget.append(entry)
            case "Note":
                note.append(entry)
            case "BG Check":
                bgCheck.append(entry)
            case "Suspend Pump":
                suspendPump.append(entry)
            case "Resume Pump":
                resumePump.append(entry)
            case "Pump Site Change", "Site Change":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = cageData(created_at: createdAt)
                    pumpSiteChange.append(newEntry)
                }
            case "Sensor Start":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = sageData(created_at: createdAt)
                    cgmSensorStart.append(newEntry)
                }
            case "Insulin Change":
                if let createdAt = entry["created_at"] as? String {
                    let newEntry = iageData(created_at: createdAt)
                    insulinCartridge.append(newEntry)
                }
            default:
                print("No Match: \(String(describing: entry))")
            }
        }

        if tempBasal.count > 0 {
            let suspensions = PumpSuspension.intervals(
                notes: note.compactMap { entry in
                    guard let date = NightscoutUtils.treatmentDate(from: entry), let text = entry["notes"] as? String else { return nil }
                    return (date, text)
                },
                tempBasalStarts: tempBasal.compactMap { NightscoutUtils.treatmentDate(from: $0) }
            )
            processNSBasals(entries: tempBasal, suspensions: suspensions)
        } else {
            if basalData.count > 0 {
                clearOldTempBasal()
            }
            if let profileBasal = profileManager.currentBasal() {
                infoManager.updateInfoData(type: .basal, value: profileBasal)
                Storage.shared.lastBasal.value = profileBasal
            }
        }
        if bolus.count > 0 {
            processNSBolus(entries: bolus)
        } else {
            if bolusData.count > 0 {
                clearOldBolus()
            }
        }
        if smb.count > 0 {
            processNSSmb(entries: smb)
        } else {
            if smbData.count > 0 {
                clearOldSmb()
            }
        }
        updateTodaysCarbsFromEntries(entries: carbs)
        if carbs.count > 0 {
            processNSCarbs(entries: carbs)
        } else {
            if carbData.count > 0 {
                clearOldCarb()
            }
        }
        if bgCheck.count > 0 {
            processNSBGCheck(entries: bgCheck)
        } else {
            if bgCheckData.count > 0 {
                clearOldBGCheck()
            }
        }
        if temporaryOverride.count == 0, overrideGraphData.count > 0 {
            clearOldOverride()
        }
        if temporaryOverride.count > 0 {
            processNSOverrides(entries: temporaryOverride)
        }

        if temporaryTarget.count == 0, tempTargetGraphData.count > 0 {
            clearOldTempTarget()
        }
        if temporaryTarget.count > 0 {
            processNSTemporaryTarget(entries: temporaryTarget)
        }
        if suspendPump.count > 0 {
            processSuspendPump(entries: suspendPump)
        } else {
            if suspendGraphData.count > 0 {
                clearOldSuspend()
            }
        }
        if resumePump.count > 0 {
            processResumePump(entries: resumePump)
        } else {
            if resumeGraphData.count > 0 {
                clearOldResume()
            }
        }
        processSage(entries: cgmSensorStart)
        if cgmSensorStart.count > 0 {
            processSensorStart(entries: cgmSensorStart)
        } else {
            if sensorStartGraphData.count > 0 {
                clearOldSensor()
            }
        }

        processIage(entries: insulinCartridge)

        if note.count > 0 {
            processNotes(entries: note)
        } else {
            if noteGraphData.count > 0 || cgmSensorStates.count > 0 {
                clearOldNotes()
            }
        }
        processCage(entries: pumpSiteChange)
    }
}
