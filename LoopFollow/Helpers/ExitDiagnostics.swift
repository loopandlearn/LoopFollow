// LoopFollow
// ExitDiagnostics.swift

import Foundation
import MetricKit
import os

/// Logs MetricKit app exit counts and crash diagnostics. iOS delivers these
/// at most once a day, so a log shared the day after a termination shows why
/// the process ended.
final class ExitDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = ExitDiagnostics()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let exits = payload.applicationExitMetrics else { continue }
            let range = "\(payload.timeStampBegin) – \(payload.timeStampEnd)"

            let bg = exits.backgroundExitData
            let background = Self.describe([
                ("normal", bg.cumulativeNormalAppExitCount),
                ("memoryLimit", bg.cumulativeMemoryResourceLimitExitCount),
                ("memoryPressure", bg.cumulativeMemoryPressureExitCount),
                ("cpuLimit", bg.cumulativeCPUResourceLimitExitCount),
                ("badAccess", bg.cumulativeBadAccessExitCount),
                ("illegalInstruction", bg.cumulativeIllegalInstructionExitCount),
                ("abnormal", bg.cumulativeAbnormalExitCount),
                ("watchdog", bg.cumulativeAppWatchdogExitCount),
                ("lockedFile", bg.cumulativeSuspendedWithLockedFileExitCount),
                ("taskAssertionTimeout", bg.cumulativeBackgroundTaskAssertionTimeoutExitCount),
            ])

            let fg = exits.foregroundExitData
            let foreground = Self.describe([
                ("normal", fg.cumulativeNormalAppExitCount),
                ("memoryLimit", fg.cumulativeMemoryResourceLimitExitCount),
                ("badAccess", fg.cumulativeBadAccessExitCount),
                ("illegalInstruction", fg.cumulativeIllegalInstructionExitCount),
                ("abnormal", fg.cumulativeAbnormalExitCount),
                ("watchdog", fg.cumulativeAppWatchdogExitCount),
            ])

            LogManager.shared.log(category: .general, message: "App exits \(range): background [\(background)], foreground [\(foreground)]")
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let signal = crash.signal.map { "\($0)" } ?? "-"
                let exceptionType = crash.exceptionType.map { "\($0)" } ?? "-"
                let exceptionCode = crash.exceptionCode.map { "\($0)" } ?? "-"
                let reason = crash.terminationReason ?? "-"
                LogManager.shared.log(
                    category: .general,
                    message: "Crash reported for \(payload.timeStampBegin) – \(payload.timeStampEnd): version=\(crash.applicationVersion), signal=\(signal), exceptionType=\(exceptionType), exceptionCode=\(exceptionCode), terminationReason=\(reason)"
                )
            }
        }
    }

    /// Current memory footprint and the headroom left before iOS terminates the
    /// process for exceeding its memory limit.
    static func memoryDescription() -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let footprint = result == KERN_SUCCESS ? "\(info.phys_footprint / 1_048_576) MB" : "unknown"
        #if targetEnvironment(macCatalyst)
            return "memoryFootprint=\(footprint)"
        #else
            let available = os_proc_available_memory() / 1_048_576
            return "memoryFootprint=\(footprint), memoryAvailable=\(available) MB"
        #endif
    }

    private static func describe(_ counts: [(String, Int)]) -> String {
        let nonZero = counts.filter { $0.1 > 0 }
        return nonZero.isEmpty ? "none" : nonZero.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
    }
}
