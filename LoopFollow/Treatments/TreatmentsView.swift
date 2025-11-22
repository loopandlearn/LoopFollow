// LoopFollow
// TreatmentsView.swift

import SwiftUI

struct TreatmentsView: View {
    @StateObject private var viewModel = TreatmentsViewModel()

    var body: some View {
        List {
            if viewModel.groupedTreatments.isEmpty {
                Text("No recent treatments")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.groupedTreatments.keys.sorted(by: >), id: \.self) { hourKey in
                    Section(header: Text(formatHourHeader(hourKey))) {
                        ForEach(viewModel.groupedTreatments[hourKey] ?? []) { treatment in
                            TreatmentRow(treatment: treatment)
                        }
                    }
                }
            }
        }
        .navigationTitle("Treatments")
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .refreshable {
            viewModel.loadTreatments()
        }
        .onAppear {
            viewModel.loadTreatments()
        }
    }

    private func formatHourHeader(_ hourKey: String) -> String {
        let components = hourKey.split(separator: "-")
        guard components.count == 4,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              let hour = Int(components[3])
        else {
            return hourKey
        }

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour

        guard let date = Calendar.current.date(from: dateComponents) else {
            return hourKey
        }

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.current
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short // Respects user's 12/24-hour preference

        let timeString = timeFormatter.string(from: date)

        // Create the full header string based on the day
        if Calendar.current.isDateInToday(date) {
            return "Today \(timeString)"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            dateFormatter.dateFormat = "MMM d"
            let dateString = dateFormatter.string(from: date)
            return "\(dateString), \(timeString)"
        }
    }
}

struct TreatmentDetailView: View {
    let treatment: Treatment
    @StateObject private var viewModel = TreatmentDetailViewModel()

    var body: some View {
        List {
            // Treatment Info Section (no header)
            Section {
                HStack {
                    Image(systemName: treatment.icon)
                        .foregroundColor(treatment.color)
                        .opacity(treatment.type == .tempBasal ? 0.5 : 1.0)
                        .frame(width: 24)
                    Text(treatment.title)
                        .font(.headline)
                    if let subtitle = treatment.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            // Glucose at time
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if let detail = viewModel.detail, detail.glucose > 0 {
                Section(header: Text("Glucose value")) {
                    HStack {
                        Text(formatBG(detail.glucose))
                        Spacer()
                    }
                }
            }

            if !viewModel.isLoading, let detail = viewModel.detail {
                if detail.iob != nil || detail.cob != nil || detail.eventualBG != nil {
                    Section(header: Text("Loop Data")) {
                        HStack(spacing: 20) {
                            if let iob = detail.iob {
                                VStack(alignment: .leading) {
                                    Text("IOB")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f U", iob))
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let cob = detail.cob {
                                VStack(alignment: .leading) {
                                    Text("COB")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f g", cob))
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let eventualBG = detail.eventualBG, eventualBG > 0 {
                                VStack(alignment: .leading) {
                                    Text("Eventual")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatBG(eventualBG))
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Prediction Range
                if detail.minBG > 0 || detail.maxBG > 0 {
                    Section(header: Text("Prediction")) {
                        if detail.minBG > 0 && detail.maxBG > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatBG(detail.minBG))
                                        .font(.subheadline)
                                }
                                HStack {
                                    Text("Max")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatBG(detail.maxBG))
                                        .font(.subheadline)
                                }
                            }
                        } else if detail.minBG > 0 {
                            HStack {
                                Text("Minimum")
                                Spacer()
                                Text(formatBG(detail.minBG))
                                    .foregroundColor(.secondary)
                            }
                        } else if detail.maxBG > 0 {
                            HStack {
                                Text("Maximum")
                                Spacer()
                                Text(formatBG(detail.maxBG))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Active Override
                if let overrideName = detail.overrideName {
                    Section(header: Text("Active Override")) {
                        HStack {
                            Text(overrideName)
                            Spacer()
                        }
                        if let multiplier = detail.overrideMultiplier {
                            HStack {
                                Text("Sensitivity")
                                Spacer()
                                Text(String(format: "%.0f%%", multiplier * 100))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let targetRange = detail.overrideTargetRange {
                            HStack {
                                Text("Target Range")
                                Spacer()
                                Text("\(formatBG(targetRange.min)) - \(formatBG(targetRange.max))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Recommended Bolus
                if let recommendedBolus = detail.recommendedBolus, recommendedBolus > 0 {
                    Section(header: Text("Recommended Bolus")) {
                        HStack {
                            Text(String(format: "%.2f U", recommendedBolus))
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(formatNavigationTitle(treatment.date))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .onAppear {
            viewModel.loadDetails(for: treatment)
        }
    }

    private func formatNavigationTitle(_ timeInterval: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let fullString = formatter.string(from: date)
        // Remove " at " if it exists (some locales use it)
        return fullString.replacingOccurrences(of: " at ", with: " ")
    }

    private func formatBG(_ mgdlValue: Int) -> String {
        let units = Storage.shared.units.value

        if units == "mg/dL" {
            return "\(mgdlValue) mg/dL"
        } else {
            let mmolValue = Double(mgdlValue) * GlucoseConversion.mgDlToMmolL
            return String(format: "%.1f mmol/L", mmolValue)
        }
    }
}

struct DeviceStatusData {
    let timestamp: TimeInterval
    let iob: Double?
    let cob: Double?
    let eventualBG: Int?
    let minPredictedBG: Int?
    let maxPredictedBG: Int?
    let overrideName: String?
    let overrideMultiplier: Double?
    let overrideTargetRange: (min: Int, max: Int)?
    let recommendedBolus: Double?
}

struct TreatmentDetailData {
    let glucose: Int
    let iob: Double?
    let cob: Double?
    let eventualBG: Int?
    let minBG: Int
    let maxBG: Int
    let loopStatus: String?
    let overrideName: String?
    let overrideMultiplier: Double?
    let overrideTargetRange: (min: Int, max: Int)?
    let recommendedBolus: Double?
}

class TreatmentDetailViewModel: ObservableObject {
    @Published var detail: TreatmentDetailData?
    @Published var isLoading = false

    func loadDetails(for treatment: Treatment) {
        guard let mainVC = getMainViewController() else { return }

        isLoading = true

        // Find closest BG reading
        let glucose = findNearestBG(at: treatment.date, in: mainVC.bgData)

        // Fetch historical device status from Nightscout
        fetchDeviceStatusHistory(around: treatment.date) { [weak self] deviceStatus in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.detail = TreatmentDetailData(
                    glucose: glucose,
                    iob: deviceStatus?.iob,
                    cob: deviceStatus?.cob,
                    eventualBG: deviceStatus?.eventualBG,
                    minBG: deviceStatus?.minPredictedBG ?? 0,
                    maxBG: deviceStatus?.maxPredictedBG ?? 0,
                    loopStatus: nil,
                    overrideName: deviceStatus?.overrideName,
                    overrideMultiplier: deviceStatus?.overrideMultiplier,
                    overrideTargetRange: deviceStatus?.overrideTargetRange,
                    recommendedBolus: deviceStatus?.recommendedBolus
                )
                self.isLoading = false
            }
        }
    }

    private func fetchDeviceStatusHistory(around timestamp: TimeInterval, completion: @escaping (DeviceStatusData?) -> Void) {
        // Fetch device status entries around the treatment time
        // We'll get a range of entries to find the closest one
        let targetDate = Date(timeIntervalSince1970: timestamp)
        let startDate = targetDate.addingTimeInterval(-30 * 60) // 30 minutes before
        let endDate = targetDate.addingTimeInterval(30 * 60) // 30 minutes after

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Build parameters
        let parameters: [String: String] = [
            "find[created_at][$gte]": formatter.string(from: startDate),
            "find[created_at][$lte]": formatter.string(from: endDate),
            "count": "30",
        ]

        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { result in
            switch result {
            case let .success(json):
                if let jsonDeviceStatus = json as? [[String: AnyObject]] {
                    // Find the entry closest to our target timestamp
                    let deviceStatus = self.parseClosestDeviceStatus(from: jsonDeviceStatus, targetTimestamp: timestamp)
                    completion(deviceStatus)
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }

    private func parseClosestDeviceStatus(from jsonArray: [[String: AnyObject]], targetTimestamp: TimeInterval) -> DeviceStatusData? {
        var closestEntry: DeviceStatusData?
        var smallestDiff: TimeInterval = .infinity

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        for entry in jsonArray {
            // Parse timestamp
            var entryTimestamp: TimeInterval = 0

            if let createdAt = entry["created_at"] as? String,
               let date = formatter.date(from: createdAt)
            {
                entryTimestamp = date.timeIntervalSince1970
            } else if let dateString = entry["dateString"] as? String {
                // Try parsing dateString as fallback
                if let date = NightscoutUtils.parseDate(dateString) {
                    entryTimestamp = date.timeIntervalSince1970
                }
            }

            guard entryTimestamp > 0 else { continue }

            let diff = abs(entryTimestamp - targetTimestamp)
            if diff < smallestDiff {
                smallestDiff = diff

                // Extract IOB, COB, and prediction data
                var iob: Double?
                var cob: Double?
                var eventualBG: Int?
                var minPredictedBG: Int?
                var maxPredictedBG: Int?
                var overrideName: String?
                var overrideMultiplier: Double?
                var overrideTargetRange: (min: Int, max: Int)?
                var recommendedBolus: Double?

                // Try Loop format first
                if let loopRecord = entry["loop"] as? [String: AnyObject] {
                    // IOB
                    if let iobDict = loopRecord["iob"] as? [String: AnyObject],
                       let iobValue = iobDict["iob"] as? Double
                    {
                        iob = iobValue
                    }

                    // COB
                    if let cobDict = loopRecord["cob"] as? [String: AnyObject],
                       let cobValue = cobDict["cob"] as? Double
                    {
                        cob = cobValue
                    }

                    // Predictions
                    if let predicted = loopRecord["predicted"] as? [String: AnyObject] {
                        if let values = predicted["values"] as? [Int], !values.isEmpty {
                            eventualBG = values.last
                            minPredictedBG = values.min()
                            maxPredictedBG = values.max()
                        }
                    }

                    // Recommended Bolus
                    if let recBolus = loopRecord["recommendedBolus"] as? Double {
                        recommendedBolus = recBolus
                    }
                }

                // Try OpenAPS format
                if let openapsRecord = entry["openaps"] as? [String: AnyObject] {
                    if let suggested = openapsRecord["suggested"] as? [String: AnyObject] {
                        if let iobValue = suggested["IOB"] as? Double {
                            iob = iobValue
                        }
                        if let cobValue = suggested["COB"] as? Double {
                            cob = cobValue
                        }
                        if let eventualValue = suggested["eventualBG"] as? Int {
                            eventualBG = eventualValue
                        }
                    }

                    if let enacted = openapsRecord["enacted"] as? [String: AnyObject] {
                        if iob == nil, let iobValue = enacted["IOB"] as? Double {
                            iob = iobValue
                        }
                        if cob == nil, let cobValue = enacted["COB"] as? Double {
                            cob = cobValue
                        }
                    }
                }

                // Parse override data
                if let overrideRecord = entry["override"] as? [String: AnyObject],
                   let isActive = overrideRecord["active"] as? Bool,
                   isActive
                {
                    overrideName = overrideRecord["name"] as? String
                    overrideMultiplier = overrideRecord["multiplier"] as? Double

                    if let currentRange = overrideRecord["currentCorrectionRange"] as? [String: AnyObject],
                       let minValue = currentRange["minValue"] as? Double,
                       let maxValue = currentRange["maxValue"] as? Double
                    {
                        overrideTargetRange = (min: Int(minValue), max: Int(maxValue))
                    }
                }

                closestEntry = DeviceStatusData(
                    timestamp: entryTimestamp,
                    iob: iob,
                    cob: cob,
                    eventualBG: eventualBG,
                    minPredictedBG: minPredictedBG,
                    maxPredictedBG: maxPredictedBG,
                    overrideName: overrideName,
                    overrideMultiplier: overrideMultiplier,
                    overrideTargetRange: overrideTargetRange,
                    recommendedBolus: recommendedBolus
                )
            }
        }

        // Only return if we found something within 15 minutes
        if smallestDiff < 15 * 60 {
            return closestEntry
        }

        return nil
    }

    private func findNearestBG(at timestamp: TimeInterval, in bgData: [ShareGlucoseData]) -> Int {
        guard !bgData.isEmpty else { return 0 }

        var closestBG: ShareGlucoseData?
        var smallestDiff: TimeInterval = .infinity

        for bg in bgData {
            let diff = abs(bg.date - timestamp)
            if diff < smallestDiff {
                smallestDiff = diff
                closestBG = bg
            }

            if diff > smallestDiff && smallestDiff < 300 {
                break
            }
        }

        if let bg = closestBG, smallestDiff < 600 {
            return Int(bg.sgv)
        }

        return 0
    }

    private func getMainViewController() -> MainViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController
        else {
            return nil
        }

        for vc in tabBarController.viewControllers ?? [] {
            if let mainVC = vc as? MainViewController {
                return mainVC
            }
            if let navVC = vc as? UINavigationController,
               let mainVC = navVC.viewControllers.first as? MainViewController
            {
                return mainVC
            }
        }

        return nil
    }
}

struct TreatmentRow: View {
    let treatment: Treatment

    var body: some View {
        NavigationLink(destination: TreatmentDetailView(treatment: treatment)) {
            HStack {
                Image(systemName: treatment.icon)
                    .foregroundColor(treatment.color)
                    .opacity(treatment.type == .tempBasal ? 0.5 : 1.0)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(treatment.title)
                            .font(.headline)
                        if let subtitle = treatment.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(formatTime(treatment.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum TreatmentType {
    case carb
    case bolus
    case smb
    case tempBasal
}

struct Treatment: Identifiable {
    let id = UUID()
    let type: TreatmentType
    let date: TimeInterval
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let bgValue: Int

    var hourKey: String {
        let date = Date(timeIntervalSince1970: self.date)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return "\(components.year!)-\(components.month!)-\(components.day!)-\(components.hour!)"
    }
}

class TreatmentsViewModel: ObservableObject {
    @Published var groupedTreatments: [String: [Treatment]] = [:]

    func loadTreatments() {
        // Get the main view controller to access the data
        guard let mainVC = getMainViewController() else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var allTreatments: [Treatment] = []

            // Load carbs - take last 50
            let carbs = mainVC.carbData.suffix(50).map { carbData -> Treatment in
                // Find actual BG at this time (stored sgv has offset for graph positioning)
                let actualBG = self.findNearestBG(at: carbData.date, in: mainVC.bgData)
                return Treatment(
                    type: .carb,
                    date: carbData.date,
                    title: "\(Int(carbData.value))g",
                    subtitle: "Carbs",
                    icon: "circle.fill",
                    color: .orange,
                    bgValue: actualBG
                )
            }
            allTreatments.append(contentsOf: carbs)

            // Load boluses - take last 50
            let boluses = mainVC.bolusData.suffix(50).map { bolusData -> Treatment in
                // Find actual BG at this time (stored sgv has offset for graph positioning)
                let actualBG = self.findNearestBG(at: bolusData.date, in: mainVC.bgData)
                return Treatment(
                    type: .bolus,
                    date: bolusData.date,
                    title: String(format: "%.2f U", bolusData.value),
                    subtitle: "Bolus",
                    icon: "circle.fill",
                    color: .blue,
                    bgValue: actualBG
                )
            }
            allTreatments.append(contentsOf: boluses)

            // Load SMB (automatic boluses) - take last 50
            let smbs = mainVC.smbData.suffix(50).map { smbData -> Treatment in
                // Find actual BG at this time (stored sgv has offset for graph positioning)
                let actualBG = self.findNearestBG(at: smbData.date, in: mainVC.bgData)
                return Treatment(
                    type: .smb,
                    date: smbData.date,
                    title: String(format: "%.2f U", smbData.value),
                    subtitle: "Automatic Bolus",
                    icon: "arrowtriangle.down.fill",
                    color: .blue,
                    bgValue: actualBG
                )
            }
            allTreatments.append(contentsOf: smbs)

            // Load temp basals - filter to show only start times (not end times)
            // basalData contains pairs of start/end dots for graphing
            // Each temp basal has: [start_time, end_time] with same basalRate
            var processedBasals: [Treatment] = []
            let basalArray = Array(mainVC.basalData.suffix(100))

            var i = 0
            while i < basalArray.count {
                let current = basalArray[i]

                // Check if the next entry is the "end" marker (same rate, later time)
                if i + 1 < basalArray.count {
                    let next = basalArray[i + 1]
                    if next.basalRate == current.basalRate, next.date > current.date, (next.date - current.date) < 3600 {
                        // This is a start/end pair - keep the start (current), skip the end (next)
                        processedBasals.append(Treatment(
                            type: .tempBasal,
                            date: current.date,
                            title: String(format: "%.2f U/hr", current.basalRate),
                            subtitle: "Temp Basal",
                            icon: "chart.xyaxis.line",
                            color: .blue,
                            bgValue: 0
                        ))
                        i += 2 // Skip both this and next
                        continue
                    }
                }

                // Not a pair, just add it
                processedBasals.append(Treatment(
                    type: .tempBasal,
                    date: current.date,
                    title: String(format: "%.2f U/hr", current.basalRate),
                    subtitle: "Temp Basal",
                    icon: "chart.xyaxis.line",
                    color: .blue,
                    bgValue: 0
                ))
                i += 1
            }

            // Reverse to get most recent first and take 50
            allTreatments.append(contentsOf: processedBasals.reversed().prefix(50))

            // Sort all treatments by date (most recent first)
            allTreatments.sort { $0.date > $1.date }

            // Group by hour
            var grouped: [String: [Treatment]] = [:]
            for treatment in allTreatments {
                let key = treatment.hourKey
                if grouped[key] == nil {
                    grouped[key] = []
                }
                grouped[key]?.append(treatment)
            }

            // Sort treatments within each hour
            for key in grouped.keys {
                grouped[key]?.sort { $0.date > $1.date }
            }

            self.groupedTreatments = grouped
        }
    }

    private func findNearestBG(at timestamp: TimeInterval, in bgData: [ShareGlucoseData]) -> Int {
        // Find the closest BG reading to the treatment time
        guard !bgData.isEmpty else { return 0 }

        var closestBG: ShareGlucoseData?
        var smallestDiff: TimeInterval = .infinity

        for bg in bgData {
            let diff = abs(bg.date - timestamp)
            if diff < smallestDiff {
                smallestDiff = diff
                closestBG = bg
            }

            // If we're getting further away, we can stop (data is sorted)
            if diff > smallestDiff && smallestDiff < 300 { // Within 5 minutes
                break
            }
        }

        // Only return BG if it's within 10 minutes of the treatment
        if let bg = closestBG, smallestDiff < 600 {
            return Int(bg.sgv)
        }

        return 0
    }

    private func getMainViewController() -> MainViewController? {
        // Try to find MainViewController in the app's window hierarchy
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController
        else {
            return nil
        }

        for vc in tabBarController.viewControllers ?? [] {
            if let mainVC = vc as? MainViewController {
                return mainVC
            }
            if let navVC = vc as? UINavigationController,
               let mainVC = navVC.viewControllers.first as? MainViewController
            {
                return mainVC
            }
        }

        return nil
    }
}

struct TreatmentsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TreatmentsView()
        }
    }
}
