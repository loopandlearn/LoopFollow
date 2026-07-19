// LoopFollow
// StorageReadiness.swift

import Combine
import Foundation
import UIKit

/// A cached value that can re-read itself from disk after a BFU launch.
protocol BFUReloadable: AnyObject {
    func reload()
}

/// Before-First-Unlock (BFU) storage recovery + the app-wide readiness gate.
///
/// On a launch before the device's first unlock since boot, `UserDefaults` is
/// encrypted, so every `StorageValue`/`SecureStorageValue` initialises to its
/// default. This distinguishes true BFU from an ordinary locked launch (where the
/// store reads fine), gates the UI until storage is trustworthy, hydrates every
/// registered value once readable, and suppresses writes meanwhile so poisoned
/// defaults can't be flushed over real settings on unlock.
///
/// All mutators run on the main thread (launch + the protected-data/foreground
/// notifications); `register(_:)` runs during `Storage` init. So no locking.
enum StorageReadiness {
    /// Published gate; `false` until storage is known-good. The root shows a
    /// storage-free loading view until `true`.
    static let ready = ObservableValue<Bool>(default: false)

    /// True for the duration of a suspected true-BFU launch, until hydration runs.
    private(set) static var suspectBFU = false

    /// While true, storage values keep writes in memory only (hydration reconciles
    /// from disk). Off-main reads see a benign eventually-consistent Bool snapshot.
    static var isSuppressingWrites: Bool { suspectBFU && !ready.value }

    /// Debug surface for any writer active during the suspect window — such a write
    /// is memory-only and lost if it was needed on disk. None exist today.
    static func noteSuppressedWrite(key: String) {
        #if DEBUG
            LogManager.shared.log(category: .general, message: "Storage write to '\(key)' suppressed during BFU window")
        #endif
    }

    // MARK: - Sentinel

    private static let markerKey = "storageReadinessMarker"

    /// Present once storage has been confirmed readable. Absent in true BFU (store
    /// encrypted) — presence, not a value, so it can't drift.
    static var markerExists: Bool {
        UserDefaults.standard.object(forKey: markerKey) != nil
    }

    // MARK: - Registry

    private struct WeakReloadable {
        weak var ref: BFUReloadable?
    }

    private static var registry: [WeakReloadable] = []

    /// Called by every storage value at init, so hydration covers all by construction.
    static func register(_ reloadable: BFUReloadable) {
        registry.append(WeakReloadable(ref: reloadable))
    }

    // MARK: - Deferred work

    private static var pending: [() -> Void] = []

    /// Run `block` now if ready, else once ready. For launch work that reads real
    /// config or mutates persisted history (telemetry, network).
    static func whenReady(_ block: @escaping () -> Void) {
        if ready.value {
            block()
        } else {
            pending.append(block)
        }
    }

    // MARK: - Lifecycle

    /// Call once at launch. A non-suspect launch is marked ready synchronously (the
    /// common path); a suspect launch stays gated until `recover()`.
    static func configure(suspectBFU: Bool) {
        self.suspectBFU = suspectBFU
        if !suspectBFU {
            markReady()
        }
    }

    /// Hydrate every registered value and open the gate. Idempotent; returns `true`
    /// only on the transition that did the work.
    @discardableResult
    static func recover() -> Bool {
        guard suspectBFU, !ready.value else { return false }
        registry.removeAll { $0.ref == nil } // drop dead weak slots
        for entry in registry {
            entry.ref?.reload()
        }
        markReady()
        return true
    }

    private static func markReady() {
        guard !ready.value else { return }

        // Clear suspect BEFORE publishing: @Published emits in willSet, so a
        // ready.$value subscriber (BLEManager reconnect) runs while ready is still
        // false — clearing first lets its persists land.
        suspectBFU = false

        // Store is readable here (proven by the probes, or by protected data
        // becoming available), and class-C UserDefaults is writable while readable.
        if !markerExists {
            UserDefaults.standard.set(true, forKey: markerKey)
        }

        ready.value = true

        let blocks = pending
        pending.removeAll()
        blocks.forEach { $0() }
    }
}
