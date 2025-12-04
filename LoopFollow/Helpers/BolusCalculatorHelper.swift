// LoopFollow
// BolusCalculatorHelper.swift

import Foundation
import HealthKit

/// A helper class for calculating bolus amounts based on carbs and carb ratios
/// Also tracks recent carb remote commands to suggest bolus calculations
final class BolusCalculatorHelper {
    // MARK: - Singleton

    static let shared = BolusCalculatorHelper()

    // MARK: - Properties

    /// Time window (in seconds) for considering a carb entry as "recent"
    /// Default is 15 minutes
    private let recentCarbWindow: TimeInterval = 15 * 60

    // MARK: - Initializer

    private init() {}

    // MARK: - Public Methods

    /// Calculate bolus amount from carbs using the current carb ratio from profile
    /// - Parameter carbs: Amount of carbs in grams
    /// - Returns: Calculated bolus in units rounded to nearest 0.05, or nil if carb ratio is not available
    func calculateBolusFromCarbs(_ carbs: Double) -> Double? {
        guard let carbRatio = ProfileManager.shared.currentCarbRatio() else {
            return nil
        }

        // Bolus = Carbs / Carb Ratio
        // carbRatio is in grams per unit of insulin
        let bolus = carbs / carbRatio

        // Round to nearest 0.05 units (typical insulin pump increment)
        return (bolus / 0.05).rounded() * 0.05
    }

    /// Save a recent carb command that was sent remotely
    /// - Parameters:
    ///   - carbs: Amount of carbs in grams
    ///   - timestamp: When the carbs were sent (defaults to now)
    func saveRecentCarbCommand(carbs: Double, timestamp: Date = Date()) {
        let entry = RecentCarbEntry(carbs: carbs, timestamp: timestamp)
        Storage.shared.recentCarbEntry.value = entry
    }

    /// Get the most recent carb command if it's still within the time window
    /// - Returns: RecentCarbEntry if available and not expired, nil otherwise
    func getRecentCarbEntry() -> RecentCarbEntry? {
        guard let entry = Storage.shared.recentCarbEntry.value else {
            return nil
        }

        let now = Date()
        let timeSinceEntry = now.timeIntervalSince(entry.timestamp)

        // Check if entry is still within the time window
        if timeSinceEntry <= recentCarbWindow {
            return entry
        }

        // Entry is expired, clear it
        Storage.shared.recentCarbEntry.value = nil
        return nil
    }

    /// Calculate suggested bolus from the most recent carb command
    /// - Returns: A tuple containing the carb amount, calculated bolus, and how long ago the entry was made, or nil if no recent entry exists
    func getSuggestedBolusFromRecentCarbs() -> (carbs: Double, bolus: Double, minutesAgo: Int)? {
        guard let entry = getRecentCarbEntry(),
              let calculatedBolus = calculateBolusFromCarbs(entry.carbs)
        else {
            return nil
        }

        let now = Date()
        let timeSinceEntry = now.timeIntervalSince(entry.timestamp)
        let minutesAgo = Int(timeSinceEntry / 60)

        return (carbs: entry.carbs, bolus: calculatedBolus, minutesAgo: minutesAgo)
    }

    /// Clear the recent carb entry
    func clearRecentCarbEntry() {
        Storage.shared.recentCarbEntry.value = nil
    }

    /// Get the current carb ratio from the profile
    /// - Returns: Current carb ratio in grams per unit, or nil if not available
    func getCurrentCarbRatio() -> Double? {
        return ProfileManager.shared.currentCarbRatio()
    }
}

// MARK: - Data Structures

/// Represents a recent carb entry from a remote command
struct RecentCarbEntry: Codable, Equatable {
    let carbs: Double
    let timestamp: Date
}
