// LoopFollow
// DeviceStatusHistory.swift

import Combine
import Foundation

/// History of the values the looping app reports in Nightscout devicestatus
/// records (IOB, COB, smoothed BG, sensitivity ratio, forecasts and the info
/// table values), shared by the history graphs and the scrubbed-time displays.
///
/// Devicestatus records never change once written, so the extracted fields are
/// cached on disk and only missing spans are fetched: the Show Days Back window
/// once, then gaps after the app was suspended. The regular device status poll
/// hands each record it reads to `ingestLatest`, which extends the history
/// without a request. Changing the Nightscout address drops the cache.
///
/// Main-thread confined.
final class DeviceStatusHistory {
    static let shared = DeviceStatusHistory()

    private(set) var state = DeviceStatusHistoryState()

    /// Called on the main thread whenever the history changes.
    var onChange: (() -> Void)?

    private enum LoadState {
        case notLoaded, loading, loaded
    }

    private struct CacheFile: Codable {
        static let currentVersion = 2
        let version: Int
        let url: String
        let state: DeviceStatusHistoryState
    }

    /// Trio records carry four forecast curves (a few KB each), so a page stays
    /// around half a megabyte; small Nightscout hosts fail on much larger responses.
    private static let pageSize = 100
    private static let saveDelay: TimeInterval = 5

    private var loadState = LoadState.notLoaded
    /// Bumped whenever the history is dropped; work started under an older
    /// generation is discarded when it completes.
    private var generation = 0
    private var isFetching = false
    private var consecutiveFailures = 0
    private var retryAfter = Date.distantPast
    /// Where a range that failed part-way resumes, so pages already merged are
    /// not downloaded again.
    private var resumePoint: ResumePoint?

    private struct ResumePoint {
        let range: DeviceStatusHistoryState.FetchRange
        let upperBound: String
        let pagesFetched: Int
    }

    private var saveScheduled = false
    private var cancellables = Set<AnyCancellable>()
    private let ioQueue = DispatchQueue(label: "com.loopfollow.devicestatushistory", qos: .utility)

    private static var cacheFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("DeviceStatusHistory.json")
    }

    private init() {}

    /// Subscribes to the settings the history depends on. Idempotent.
    func start() {
        guard cancellables.isEmpty else { return }

        Storage.shared.url.$value
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reset() }
            .store(in: &cancellables)

        let s = Storage.shared
        Publishers.MergeMany(
            s.showIOBGraph.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            s.showCOBGraph.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            s.showSensitivityRatioGraph.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            s.showSmoothedBG.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            s.historyCurvePlacement.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            s.downloadDays.$value.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.settingsChanged() }
        .store(in: &cancellables)

        loadIfNeeded()
    }

    /// Takes the record the regular device status poll just read. Extends the
    /// history directly when it continues it, otherwise fetches what is missing.
    func ingestLatest(_ record: [String: Any]?) {
        guard let record else { return }
        guard loadState == .loaded else {
            loadIfNeeded()
            return
        }
        guard let parsed = DeviceStatusHistoryParser.parse(record) else {
            // Uploader-only records (for example from a CGM app) still show that
            // newer records exist.
            let createdAt = (record["created_at"] as? String).flatMap(DeviceStatusHistoryParser.parseDate)
            refreshIfNeeded(latest: createdAt?.timeIntervalSince1970)
            return
        }

        let createdAtTime = parsed.createdAt.timeIntervalSince1970
        let previous = state
        if state.appendLatest(parsed.sample, createdAt: createdAtTime), state != previous {
            state.prune(before: windowStart())
            scheduleSave()
            onChange?()
        }
        refreshIfNeeded(latest: createdAtTime)
    }

    /// The sample of the loop cycle nearest `date`, within `tolerance`.
    func sample(near date: Date, tolerance: TimeInterval = 5 * 60) -> DeviceStatusHistorySample? {
        state.sample(near: date.timeIntervalSince1970, tolerance: tolerance)
    }

    /// The loop cycle that ran on the BG reading at `date`.
    func cycle(forReadingAt date: Date) -> DeviceStatusHistorySample? {
        state.cycle(forReadingAt: date.timeIntervalSince1970)
    }

    // MARK: - Settings

    private func settingsChanged() {
        if loadState == .loaded {
            state.prune(before: windowStart())
            refreshIfNeeded(latest: nil)
        }
        onChange?()
    }

    /// Drops the history (memory and disk) after the Nightscout address changed.
    private func reset() {
        generation &+= 1
        state = DeviceStatusHistoryState()
        isFetching = false
        consecutiveFailures = 0
        retryAfter = .distantPast
        resumePoint = nil
        loadState = .loaded
        ioQueue.async {
            if let url = Self.cacheFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        onChange?()
    }

    private func windowStart(now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince1970 - TimeInterval(Storage.shared.downloadDays.value) * 24 * 3600
    }

    // MARK: - Fetching

    /// Fetches the spans the history is missing. `latest` is the `created_at` of
    /// the newest record known to exist; nil assumes one exists up to now.
    private func refreshIfNeeded(latest: TimeInterval?) {
        guard loadState == .loaded, !isFetching,
              IsNightscoutEnabled(), Date() >= retryAfter
        else { return }

        let now = Date().timeIntervalSince1970
        let resume = resumePoint
        resumePoint = nil
        // A resumed range runs on its own; the next poll plans what is still missing.
        let ranges = resume.map { [$0.range] }
            ?? state.missingRanges(windowStart: windowStart(), latest: latest ?? now, now: now)
        guard !ranges.isEmpty else { return }

        isFetching = true
        fetch(ranges, resume: resume, generation: generation)
    }

    /// Fetches `ranges` in order; the first continues from `resume` when set.
    private func fetch(_ ranges: [DeviceStatusHistoryState.FetchRange], resume: ResumePoint? = nil, generation: Int) {
        guard let range = ranges.first else {
            isFetching = false
            return
        }
        LogManager.shared.log(
            category: .deviceStatus,
            message: "Device status history fetch \(DeviceStatusHistoryParser.formatDate(Date(timeIntervalSince1970: range.from))) – \(DeviceStatusHistoryParser.formatDate(Date(timeIntervalSince1970: range.to)))",
            isDebug: true
        )
        fetchPages(
            range: range,
            upperBound: resume?.upperBound,
            pagesFetched: resume?.pagesFetched ?? 0,
            generation: generation
        ) { [weak self] outcome in
            guard let self, self.generation == generation else { return }
            switch outcome {
            case .completed:
                self.consecutiveFailures = 0
                self.state.markCovered(from: range.from, to: range.to)
                self.state.prune(before: self.windowStart())
                self.scheduleSave()
                self.fetch(Array(ranges.dropFirst()), generation: generation)
            case let .failed(reason, upperBound, pagesFetched):
                if let upperBound {
                    self.resumePoint = ResumePoint(range: range, upperBound: upperBound, pagesFetched: pagesFetched)
                }
                self.consecutiveFailures += 1
                let backoff = min(30 * pow(2, Double(self.consecutiveFailures - 1)), 600)
                self.retryAfter = Date().addingTimeInterval(backoff)
                self.isFetching = false
                LogManager.shared.log(
                    category: .deviceStatus,
                    message: "Device status history fetch failed (\(reason)), retrying in \(Int(backoff)) s",
                    limitIdentifier: "Device status history fetch failed"
                )
            }
        }
    }

    private enum PageOutcome {
        case completed
        /// `upperBound` is the cursor of the page that failed; nil for the first page.
        case failed(reason: String, upperBound: String?, pagesFetched: Int)
    }

    /// Reads one range newest-first, a page at a time. Each page is merged as
    /// it arrives so the graphs fill in progressively.
    private func fetchPages(
        range: DeviceStatusHistoryState.FetchRange,
        upperBound: String?,
        pagesFetched: Int,
        generation: Int,
        completion: @escaping (PageOutcome) -> Void
    ) {
        var parameters = [
            "count": String(Self.pageSize),
            "find[created_at][$gte]": DeviceStatusHistoryParser.formatDate(Date(timeIntervalSince1970: range.from)),
        ]
        if let upperBound {
            parameters["find[created_at][$lt]"] = upperBound
        } else {
            parameters["find[created_at][$lte]"] = DeviceStatusHistoryParser.formatDate(Date(timeIntervalSince1970: range.to))
        }

        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { [weak self] result in
            let records: [Any]
            switch result {
            case let .success(json):
                guard let array = json as? [Any] else {
                    DispatchQueue.main.async {
                        completion(.failed(reason: "unexpected response", upperBound: upperBound, pagesFetched: pagesFetched))
                    }
                    return
                }
                records = array
            case let .failure(error):
                DispatchQueue.main.async {
                    completion(.failed(reason: error.localizedDescription, upperBound: upperBound, pagesFetched: pagesFetched))
                }
                return
            }
            DispatchQueue.global(qos: .utility).async {
                var samples: [DeviceStatusHistorySample] = []
                var oldestCreatedAt: String?
                var oldestDate = Date.distantFuture
                for case let record as [String: Any] in records {
                    if let raw = record["created_at"] as? String,
                       let date = DeviceStatusHistoryParser.parseDate(raw), date < oldestDate
                    {
                        oldestDate = date
                        oldestCreatedAt = raw
                    }
                    if let parsed = DeviceStatusHistoryParser.parse(record) {
                        samples.append(parsed.sample)
                    }
                }

                DispatchQueue.main.async {
                    guard let self, self.generation == generation else { return }
                    self.state.merge(samples)
                    self.onChange?()

                    let pages = pagesFetched + 1
                    let isFull = records.count >= Self.pageSize && oldestCreatedAt != nil
                    if isFull, pages < Self.maxPages(for: range), let oldestCreatedAt {
                        self.fetchPages(range: range, upperBound: oldestCreatedAt, pagesFetched: pages, generation: generation, completion: completion)
                    } else {
                        if isFull {
                            LogManager.shared.log(category: .deviceStatus, message: "Device status history page limit reached; older records in the range are skipped")
                        }
                        completion(.completed)
                    }
                }
            }
        }
    }

    /// Room for one record per minute across the range, several times the
    /// loop cycle rate, so only a runaway uploader hits the limit.
    private static func maxPages(for range: DeviceStatusHistoryState.FetchRange) -> Int {
        Int(((range.to - range.from) / 60 / Double(pageSize)).rounded(.up)) + 1
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard loadState == .notLoaded else { return }
        loadState = .loading
        let generation = generation
        let expectedURL = Storage.shared.url.value

        ioQueue.async {
            var loaded: DeviceStatusHistoryState?
            if let fileURL = Self.cacheFileURL,
               let data = try? Data(contentsOf: fileURL),
               let file = try? JSONDecoder().decode(CacheFile.self, from: data),
               file.version == CacheFile.currentVersion, file.url == expectedURL
            {
                loaded = file.state
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                if let loaded {
                    self.state = loaded
                    self.state.prune(before: self.windowStart())
                }
                self.loadState = .loaded
                self.onChange?()
                self.refreshIfNeeded(latest: nil)
            }
        }
    }

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDelay) { [weak self] in
            guard let self else { return }
            self.saveScheduled = false
            let file = CacheFile(version: CacheFile.currentVersion, url: Storage.shared.url.value, state: self.state)
            self.ioQueue.async {
                guard let fileURL = Self.cacheFileURL,
                      let data = try? JSONEncoder().encode(file)
                else { return }
                do {
                    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                } catch {
                    LogManager.shared.log(category: .deviceStatus, message: "Device status history save failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
