// LoopFollow
// HubBundle.swift

import Foundation

/// In LoopFollow Hub mode the app reads its Nightscout and Dexcom data from the
/// hub's bundle: the latest response of every endpoint LoopFollow polls, kept
/// fresh by the hub. The app's own parsers take each part exactly as they take
/// a Nightscout response, so a cold start shows everything after one request.
/// While the app is open it long-polls the hub and reruns the tasks whose parts
/// changed, so new data shows at once. Without a current part (part not fetched
/// yet, or no answer from the hub for `staleAfter`) a request goes to Nightscout
/// or Dexcom as in every other mode.
final class HubBundle {
    static let shared = HubBundle()

    private let activeCheck: () -> Bool

    /// Instances other than `shared` exist for tests, with their own idea of Hub mode.
    init(isActive: @escaping () -> Bool = { HubClient.shared.isHubMode }) {
        activeCheck = isActive
    }

    enum Part: String, CaseIterable {
        case entries, profile, devicestatus, treatments, sage, cage, iage, dbsize

        /// The task whose fetch reads this part.
        var task: TaskID? {
            switch self {
            case .entries: return .fetchBG
            case .profile: return .profile
            case .devicestatus: return .deviceStatus
            case .treatments, .sage, .cage, .iage: return .treatments
            case .dbsize: return .dbSize
            }
        }
    }

    private let lock = NSLock()
    private var parts: [Part: Data] = [:]
    private(set) var version: Int64 = 0
    /// When the hub last answered a bundle request.
    private var lastContact: Date?
    private var loading: Task<Void, Never>?
    private var loadingID: UUID?
    private var listening: Task<Void, Never>?

    /// How long a first fetch may wait for the bundle before going to Nightscout.
    private static let firstLoadWait: UInt64 = 3_000_000_000
    private static let longPollSeconds = 25
    /// How often the open app runs the watchdog's check, which also refreshes the
    /// hub's confirmation.
    private static let watchdogInterval: TimeInterval = 60
    /// Parts older than this without an answer from the hub are not used.
    static let staleAfter: TimeInterval = 3 * 60

    var isActive: Bool { activeCheck() }

    /// Whether the bundle holds a current copy of the part in Hub mode.
    func hasCurrent(_ part: Part, now: Date = Date()) -> Bool {
        isActive && current(part, now: now) != nil
    }

    /// The part for the app's own parser. A part that is not current is fetched first,
    /// waiting up to `firstLoadWait`; nil sends the caller to Nightscout or Dexcom.
    func data(for part: Part) async -> Data? {
        guard isActive else { return nil }
        if let cached = current(part) { return cached }
        let load = loadOnce()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await load.value }
            group.addTask { try? await Task.sleep(nanoseconds: Self.firstLoadWait) }
            await group.next()
            group.cancelAll()
        }
        return current(part)
    }

    /// Long-polls the hub while the app is open; each new version reruns the tasks
    /// that read a changed part.
    func startListening() {
        guard isActive, listening == nil else { return }
        listening = Task { [weak self] in
            // Coming to the foreground runs a check of its own.
            var lastCheck = Date()
            while !Task.isCancelled, let self, self.isActive {
                let changed = await self.fetch(wait: Self.longPollSeconds)
                if Task.isCancelled { break }
                if Date().timeIntervalSince(lastCheck) >= Self.watchdogInterval {
                    lastCheck = Date()
                    await HubWatchdog.check()
                }
                // Without an answer, or without a version the hub can hold the request
                // for, the next request waits.
                if changed == nil || self.lock.withLock({ self.version }) == 0 {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                }
            }
        }
    }

    func stopListening() {
        listening?.cancel()
        listening = nil
    }

    // MARK: - Loading

    /// The stored part, whatever the mode.
    func stored(_ part: Part) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return parts[part]
    }

    /// The stored part while the hub answered within `staleAfter` of `now`.
    func current(_ part: Part, now: Date = Date()) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let lastContact, now.timeIntervalSince(lastContact) < Self.staleAfter else { return nil }
        return parts[part]
    }

    private func markContact(_ at: Date) {
        lock.withLock { lastContact = at }
    }

    /// The load in progress, or a new one. The load clears itself when done.
    private func loadOnce() -> Task<Void, Never> {
        lock.lock()
        defer { lock.unlock() }
        if let loading { return loading }
        let id = UUID()
        let task = Task {
            _ = await self.fetch(wait: 0)
            self.lock.withLock { if self.loadingID == id { self.loading = nil } }
        }
        loading = task
        loadingID = id
        return task
    }

    /// Fetches the bundle (holding up to `wait` seconds for a newer one) and applies
    /// it. The parts that changed, empty when nothing did, nil on failure.
    @discardableResult
    private func fetch(wait: Int) async -> Set<Part>? {
        let known = lock.withLock { version }
        do {
            guard let data = try await HubClient.shared.bundle(since: known, wait: wait) else {
                markContact(Date())
                return []
            }
            let changed = apply(data)
            if !changed.isEmpty { rerunTasks(for: changed) }
            return changed
        } catch is CancellationError {
            return nil
        } catch let error as URLError where error.code == .cancelled {
            return nil
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub bundle fetch failed: \(error.localizedDescription)", isDebug: true)
            return nil
        }
    }

    /// Takes a bundle response received at `receivedAt`: stores its parts and version
    /// and returns the parts whose content changed. A response that does not parse
    /// changes nothing.
    func apply(_ data: Data, receivedAt: Date = Date()) -> Set<Part> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newVersion = (root["version"] as? NSNumber)?.int64Value,
              let incoming = root["parts"] as? [String: Any]
        else { return [] }

        var decoded: [Part: Data] = [:]
        for (name, value) in incoming {
            guard let part = Part(rawValue: name),
                  let payload = (value as? [String: Any])?["data"], !(payload is NSNull),
                  let bytes = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
            else { continue }
            decoded[part] = bytes
        }

        lock.lock()
        defer { lock.unlock() }
        let changed = Set(decoded.compactMap { part, bytes in parts[part] == bytes ? nil : part })
        parts.merge(decoded) { _, new in new }
        version = newVersion
        lastContact = receivedAt
        return changed
    }

    private func rerunTasks(for changed: Set<Part>) {
        let tasks = Set(changed.compactMap(\.task))
        LogManager.shared.log(category: .hub, message: "Hub bundle: \(changed.map(\.rawValue).sorted().joined(separator: ", ")) changed", isDebug: true)
        DispatchQueue.main.async {
            for task in tasks {
                TaskScheduler.shared.rescheduleTask(id: task, to: Date())
            }
        }
    }
}
