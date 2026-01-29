// LoopFollow
// TreatmentsView.swift

import SwiftUI

struct TreatmentsView: View {
    @StateObject private var viewModel = TreatmentsViewModel()

    var body: some View {
        List {
            if viewModel.isInitialLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.groupedTreatments.isEmpty {
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

                Section {
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else {
                        Button(action: {
                            viewModel.loadMoreIfNeeded()
                        }) {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("Load More")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Text("Tap to load older treatments")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .navigationTitle("Treatments")
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .refreshable {
            viewModel.refreshTreatments()
        }
        .onAppear {
            if viewModel.groupedTreatments.isEmpty {
                viewModel.loadInitialTreatments()
            }
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
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
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
    let id: String
    let type: TreatmentType
    let date: TimeInterval
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let bgValue: Int

    init(id: String? = nil, type: TreatmentType, date: TimeInterval, title: String, subtitle: String?, icon: String, color: Color, bgValue: Int) {
        self.id = id ?? "\(type)-\(date)-\(title)"
        self.type = type
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.bgValue = bgValue
    }

    var hourKey: String {
        let date = Date(timeIntervalSince1970: self.date)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return "\(components.year!)-\(components.month!)-\(components.day!)-\(components.hour!)"
    }
}

class TreatmentsViewModel: ObservableObject {
    @Published var groupedTreatments: [String: [Treatment]] = [:]
    @Published var isInitialLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true

    private var allTreatments: [Treatment] = []
    private var processedNightscoutIds = Set<String>() // Track which NS entries we've already processed
    private var oldestFetchedDate: Date? // Track the oldest treatment date we've fetched
    private let pageSize = 100
    private var isFetching = false

    func loadInitialTreatments() {
        guard !isInitialLoading, !isFetching else {
            return
        }

        isInitialLoading = true
        isFetching = true
        allTreatments.removeAll()
        processedNightscoutIds.removeAll()
        oldestFetchedDate = nil
        hasMoreData = true

        // Start from now and go backwards
        fetchTreatments(endDate: Date()) { [weak self] treatments, rawCount in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.allTreatments = treatments
                self.regroupTreatments()

                // Update oldest date from the last (oldest) treatment
                if let oldest = treatments.last {
                    self.oldestFetchedDate = Date(timeIntervalSince1970: oldest.date)
                }

                // Has more data if we got a full page from Nightscout
                self.hasMoreData = rawCount >= self.pageSize
                self.isInitialLoading = false
                self.isFetching = false
            }
        }
    }

    func refreshTreatments() {
        allTreatments.removeAll()
        processedNightscoutIds.removeAll()
        oldestFetchedDate = nil
        hasMoreData = true
        isFetching = false
        loadInitialTreatments()
    }

    func loadMoreIfNeeded() {
        guard !isLoadingMore, !isFetching, hasMoreData, let oldestDate = oldestFetchedDate else {
            return
        }

        isLoadingMore = true
        isFetching = true

        // Fetch treatments older than the oldest we have
        fetchTreatments(endDate: oldestDate) { [weak self] treatments, rawCount in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.allTreatments.append(contentsOf: treatments)
                self.regroupTreatments()

                // Update oldest date from the last (oldest) treatment in the new batch
                if let oldest = treatments.last {
                    self.oldestFetchedDate = Date(timeIntervalSince1970: oldest.date)
                }

                // Has more data if we got a full page from Nightscout
                self.hasMoreData = rawCount >= self.pageSize
                self.isLoadingMore = false
                self.isFetching = false
            }
        }
    }

    private func fetchTreatments(endDate: Date, completion: @escaping ([Treatment], Int) -> Void) {
        guard IsNightscoutEnabled() else {
            completion([], 0)
            return
        }

        let baseURL = Storage.shared.url.value
        let token = Storage.shared.token.value

        guard !baseURL.isEmpty else {
            completion([], 0)
            return
        }

        // Format dates for the query
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        // For pagination: fetch treatments with created_at < endDate
        // Go back up to 365 days from endDate to ensure we get enough data
        let startDate = Calendar.current.date(byAdding: .day, value: -365, to: endDate)!
        let endDateString = formatter.string(from: endDate)
        let startDateString = formatter.string(from: startDate)

        // Build parameters with date filtering
        let parameters: [String: String] = [
            "find[created_at][$gte]": startDateString,
            "find[created_at][$lt]": endDateString,
            "count": "\(pageSize)",
        ]

        // Construct URL
        guard let url = NightscoutUtils.constructURL(
            baseURL: baseURL,
            token: token,
            endpoint: "/api/v1/treatments.json",
            parameters: parameters
        ) else {
            completion([], 0)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                LogManager.shared.log(category: .nightscout, message: "Failed to fetch treatments: \(error.localizedDescription)")
                completion([], 0)
                return
            }

            guard let data = data else {
                completion([], 0)
                return
            }

            do {
                guard let entries = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: AnyObject]] else {
                    completion([], 0)
                    return
                }

                // Parse treatments
                let rawCount = entries.count
                let treatments = self.parseTreatments(from: entries)

                completion(treatments, rawCount)

            } catch {
                LogManager.shared.log(category: .nightscout, message: "Failed to parse treatments: \(error.localizedDescription)")
                completion([], 0)
            }
        }

        task.resume()
    }

    private func parseTreatments(from entries: [[String: AnyObject]]) -> [Treatment] {
        var treatments: [Treatment] = []
        guard let mainVC = getMainViewController() else { return [] }

        for entry in entries {
            guard let eventType = entry["eventType"] as? String,
                  let createdAt = entry["created_at"] as? String,
                  let date = NightscoutUtils.parseDate(createdAt)
            else {
                continue
            }

            let timestamp = date.timeIntervalSince1970
            let nsId = entry["_id"] as? String ?? "unknown-\(timestamp)"

            // Skip if we've already processed this Nightscout entry
            if processedNightscoutIds.contains(nsId) {
                continue
            }

            // Mark this entry as processed
            processedNightscoutIds.insert(nsId)

            switch eventType {
            case "Carb Correction", "Meal Bolus":
                if let carbs = entry["carbs"] as? Double, carbs > 0 {
                    let actualBG = findNearestBG(at: timestamp, in: mainVC.bgData)
                    let treatment = Treatment(
                        id: "\(nsId)-carb",
                        type: .carb,
                        date: timestamp,
                        title: "\(Int(carbs))g",
                        subtitle: "Carbs",
                        icon: "circle.fill",
                        color: .orange,
                        bgValue: actualBG
                    )
                    treatments.append(treatment)
                }

                // Also process bolus from Meal Bolus
                if eventType == "Meal Bolus",
                   let insulin = entry["insulin"] as? Double, insulin > 0
                {
                    let actualBG = findNearestBG(at: timestamp, in: mainVC.bgData)
                    let treatment = Treatment(
                        id: "\(nsId)-bolus",
                        type: .bolus,
                        date: timestamp,
                        title: String(format: "%.2f U", insulin),
                        subtitle: "Bolus",
                        icon: "circle.fill",
                        color: .blue,
                        bgValue: actualBG
                    )
                    treatments.append(treatment)
                }

            case "Correction Bolus", "Bolus", "External Insulin":
                if let insulin = entry["insulin"] as? Double, insulin > 0 {
                    let isAutomatic = entry["automatic"] as? Bool ?? false
                    let actualBG = findNearestBG(at: timestamp, in: mainVC.bgData)

                    if isAutomatic {
                        let treatment = Treatment(
                            id: "\(nsId)-smb",
                            type: .smb,
                            date: timestamp,
                            title: String(format: "%.2f U", insulin),
                            subtitle: "Automatic Bolus",
                            icon: "arrowtriangle.down.fill",
                            color: .blue,
                            bgValue: actualBG
                        )
                        treatments.append(treatment)
                    } else {
                        let treatment = Treatment(
                            id: "\(nsId)-bolus",
                            type: .bolus,
                            date: timestamp,
                            title: String(format: "%.2f U", insulin),
                            subtitle: "Bolus",
                            icon: "circle.fill",
                            color: .blue,
                            bgValue: actualBG
                        )
                        treatments.append(treatment)
                    }
                }

            case "SMB":
                if let insulin = entry["insulin"] as? Double, insulin > 0 {
                    let actualBG = findNearestBG(at: timestamp, in: mainVC.bgData)
                    let treatment = Treatment(
                        id: "\(nsId)-smb",
                        type: .smb,
                        date: timestamp,
                        title: String(format: "%.2f U", insulin),
                        subtitle: "Automatic Bolus",
                        icon: "arrowtriangle.down.fill",
                        color: .blue,
                        bgValue: actualBG
                    )
                    treatments.append(treatment)
                }

            case "Temp Basal":
                if let rate = entry["rate"] as? Double {
                    let treatment = Treatment(
                        id: "\(nsId)-basal",
                        type: .tempBasal,
                        date: timestamp,
                        title: String(format: "%.2f U/hr", rate),
                        subtitle: "Temp Basal",
                        icon: "chart.xyaxis.line",
                        color: .blue,
                        bgValue: 0
                    )
                    treatments.append(treatment)
                }

            default:
                break
            }
        }

        // Sort by date descending (most recent first)
        return treatments.sorted { $0.date > $1.date }
    }

    private func regroupTreatments() {
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

        groupedTreatments = grouped
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
