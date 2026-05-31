// LoopFollow
// DashboardViewModel.swift

import Combine
import Foundation
import SwiftUI

// This makes the class observable by SwiftUI
class DashboardViewModel: ObservableObject {
    // Primary Metrics
    @Published var currentGlucose: String = "---"
    @Published var trendArrow: String = "arrow.right"
    @Published var deltaAndRate: String = "-- mg/dL·min"
    @Published var lastUpdatedText: String = "Just now"
    @Published var loopStatus: String = "Loop closed"
    @Published var loopStatusColor: Color = .green

    // Grid Metrics
    @Published var iob: String = "0.0"
    @Published var cob: String = "0"
    @Published var basalRate: String = "0.00"
    @Published var pumpUnits: String = "0+"
    @Published var target: String = "100"
    @Published var isf: String = "0"
    @Published var carbRatio: String = "0"
    @Published var autosens: String = "100%"

    // Secondary Metrics
    @Published var minMaxToday: String = "--- / ---"
    @Published var carbsToday: String = "0"
    @Published var tdd: String = "0"

    init() {
        // Load initial data when the view is created
        fetchLatestLoopData()
    }

    func fetchLatestLoopData() {
        // TODO: Map these to LoopFollow's actual CoreData / UserDefaults fetchers.
        // For example: self.currentGlucose = String(LoopFollowData.shared.latestGlucose)

        // Simulating a successful data fetch for the UI:
        currentGlucose = "206"
        trendArrow = "arrow.right"
        deltaAndRate = "-3 mg/dL·min"
        lastUpdatedText = "4:38 min ago"

        iob = "2.3"
        cob = "0"
        basalRate = "0.35"
        pumpUnits = "50+"
        target = "100"
        isf = "75"
        carbRatio = "15"
        autosens = "109%"

        minMaxToday = "118 / 206"
        carbsToday = "71"
        tdd = "21"
    }
}
