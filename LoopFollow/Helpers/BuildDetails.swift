// LoopFollow
// BuildDetails.swift
// Created by Jonas Björkert.

import Foundation

class BuildDetails {
    static var `default` = BuildDetails()

    let dict: [String: Any]

    init() {
        guard let url = Bundle.main.url(forResource: "BuildDetails", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            dict = [:]
            return
        }
        dict = parsed
    }

    var teamID: String? {
        dict["com-LoopFollow-development-team"] as? String
    }

    var buildDateString: String? {
        return dict["com-LoopFollow-build-date"] as? String
    }

    var branch: String? {
        return dict["com-LoopFollow-branch"] as? String
    }

    var branchAndSha: String {
        let branch = branch ?? "Unknown"
        let sha = dict["com-LoopFollow-commit-sha"] as? String ?? "Unknown"
        return "\(branch) \(sha)"
    }

    // Determine if the build is from TestFlight
    func isTestFlightBuild() -> Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            if Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil {
                return false
            }
            guard let receiptName = Bundle.main.appStoreReceiptURL?.lastPathComponent else {
                return false
            }
            return "sandboxReceipt".caseInsensitiveCompare(receiptName) == .orderedSame
        #endif
    }

    // Determine if the build is for Simulator
    func isSimulatorBuild() -> Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    // Determine if the build is for Mac
    func isMacApp() -> Bool {
        #if targetEnvironment(macCatalyst)
            return true
        #else
            return false
        #endif
    }

    // Parse the build date string into a Date object
    func buildDate() -> Date? {
        guard let dateString = dict["com-LoopFollow-build-date"] as? String else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    // Calculate the expiration date based on the build type
    func calculateExpirationDate() -> Date {
        if isTestFlightBuild(), let buildDate = buildDate() {
            // For TestFlight, add 90 days to the build date
            return Calendar.current.date(byAdding: .day, value: 90, to: buildDate)!
        } else {
            // For Xcode builds, use the provisioning profile's expiration date
            if let provision = MobileProvision.read() {
                return provision.expirationDate
            } else {
                return .distantFuture
            }
        }
    }

    // Expiration header based on build type
    var expirationHeaderString: String {
        if isTestFlightBuild() {
            return "TestFlight Expires"
        } else {
            return "App Expires"
        }
    }
}
