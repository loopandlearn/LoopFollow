// LoopFollow
// OnboardingViewModel.swift

import Combine
import SwiftUI
import UserNotifications

/// Drives the onboarding wizard: tracks the current phase, the chosen data
/// source, the seeded alarms, and persists everything when the user finishes.
///
/// The child connection view models are the same ones used by the regular
/// settings screens, so URL/token/credential entry and validation behave
/// identically here and there.
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum DataSource: Hashable {
        case nightscout
        case dexcom
        case copyFromPhone
    }

    /// A single recommended alarm offered on the alarms phase. Display fields are
    /// carried explicitly (rather than derived from `AlarmType`) so two alarms of
    /// the same type — a warning Low and an Urgent Low — can read differently.
    struct SeedAlarm: Identifiable {
        let id = UUID()
        var alarm: Alarm
        var isEnabled: Bool
        var title: String
        var detail: String
        /// Needs Nightscout loop/uploader data, so it's hidden for Dexcom-only.
        var requiresNightscout: Bool

        var type: AlarmType { alarm.type }

        /// Use each alarm type's own icon rather than a bespoke one.
        var icon: String { alarm.type.icon }
    }

    /// Position within a multi-page phase, reported by that phase's view so the
    /// overall progress bar and label can reflect it.
    struct PhaseProgress: Equatable {
        var page: Int
        var count: Int
    }

    @Published var step: OnboardingStep = .welcome
    @Published var dataSource: DataSource?
    @Published var seedAlarms: [SeedAlarm]

    /// Within-phase position for phases that own internal pages (connect, alarms).
    /// Reset to `nil` whenever the phase changes.
    @Published var phaseProgress: PhaseProgress?

    /// Set once a QR settings import on the "copy from another phone" path
    /// succeeds, so the connect phase can be considered complete.
    @Published var didImportSettings = false

    /// Whether the notification permission is still undecided. The notifications
    /// phase is only shown when it is — there's no point prompting someone who has
    /// already granted or denied it (iOS won't show the prompt again anyway).
    /// Defaults to `true`; resolved asynchronously at launch, well before the user
    /// reaches that phase.
    @Published private var notificationsUndecided = true

    let nightscoutViewModel = NightscoutSettingsViewModel()
    let dexcomViewModel = DexcomSettingsViewModel()

    /// Called to dismiss the onboarding cover.
    private let onClose: () -> Void
    private var cancellables = Set<AnyCancellable>()

    /// Whether to show the in-flow telemetry consent phase. Captured once at
    /// launch so the decision the phase records doesn't remove it from under the
    /// navigation while the user is still on it.
    private let includeTelemetryStep: Bool

    /// Alarm types the user already has, captured at launch. Onboarding only
    /// offers recommended alarms whose type the user doesn't already own, so a
    /// returning user is helped to add new ones without touching their existing
    /// (possibly custom-named) alarms.
    private let existingAlarmTypes: Set<AlarmType>

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        includeTelemetryStep = !Storage.shared.telemetryConsentDecisionMade.value
        existingAlarmTypes = Set(Storage.shared.alarms.value.map(\.type))
        seedAlarms = OnboardingViewModel.defaultSeedAlarms()

        // Re-publish child changes so the footer's `canProceed` stays in sync
        // with live connection validation.
        nightscoutViewModel.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        dexcomViewModel.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let undecided = settings.authorizationStatus == .notDetermined
            Task { @MainActor [weak self] in
                self?.notificationsUndecided = undecided
            }
        }
    }

    // MARK: - Derived state

    /// True when the user already has a working data source — used to make
    /// skipping prominent for returning users.
    var isAlreadyConfigured: Bool {
        let nightscout = !Storage.shared.url.value.isEmpty
        let dexcom = !Storage.shared.shareUserName.value.isEmpty
            && !Storage.shared.sharePassword.value.isEmpty
        return nightscout || dexcom
    }

    var canProceed: Bool {
        switch step {
        case .welcome, .overview, .units, .generalAlarms, .alarms,
             .tabOrder, .notifications, .telemetry, .completion:
            return true
        case .dataSource:
            return dataSource != nil
        case .connect:
            switch dataSource {
            case .nightscout: return nightscoutViewModel.isConnected || nightscoutViewModel.provisionedTokenPending
            case .dexcom: return dexcomViewModel.canVerifyProceed
            case .copyFromPhone: return didImportSettings
            case .none: return false
            }
        }
    }

    /// Whether Nightscout loop/uploader data is (or will be) available — used to
    /// gate alarms that depend on it. True for the Nightscout source, or any path
    /// that ends with a Nightscout URL configured (including a QR import).
    private var hasNightscoutData: Bool {
        dataSource == .nightscout || !Storage.shared.url.value.isEmpty
    }

    /// Whether a seeded alarm should be offered: its data source must be available
    /// and the user must not already have an alarm of that type.
    func isOffered(_ seed: SeedAlarm) -> Bool {
        guard !seed.requiresNightscout || hasNightscoutData else { return false }
        return !existingAlarmTypes.contains(seed.type)
    }

    var offeredSeedAlarms: [SeedAlarm] {
        seedAlarms.filter { isOffered($0) }
    }

    private var alarmsOffered: Bool { !offeredSeedAlarms.isEmpty }

    /// True when a returning user already has a working data source and there are
    /// no recommended alarms left to add — nothing essential to configure, so the
    /// overview becomes a short "you're all set" confirmation instead of a plan.
    var hasNothingToSetUp: Bool {
        isAlreadyConfigured && !alarmsOffered
    }

    /// The phases actually shown for the current configuration, in order. Optional
    /// phases are included only when relevant; a returning user skips the phases
    /// they've already completed.
    var activeSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [.welcome, .overview]

        // Already set up and nothing to add — the overview is the last stop, with
        // a "Done" that finishes. Notification/telemetry consent is still handled
        // after dismissal, the same as when skipping.
        if hasNothingToSetUp {
            return steps
        }

        // A returning user with a working data source skips source selection and
        // the connection screen; everyone else sets them up.
        if !isAlreadyConfigured {
            steps.append(contentsOf: [.dataSource, .connect])
        }

        steps.append(.units)
        if alarmsOffered {
            steps.append(contentsOf: [.generalAlarms, .alarms])
        }
        steps.append(.tabOrder)
        if notificationsUndecided {
            steps.append(.notifications)
        }
        if includeTelemetryStep {
            steps.append(.telemetry)
        }
        steps.append(.completion)
        return steps
    }

    /// Phases that show the progress header — the unit over which the bar fills.
    private var chromePhases: [OnboardingStep] {
        activeSteps.filter { $0.showsProgressHeader }
    }

    /// Progress fraction (0...1). Each phase is one slot; a multi-page phase fills
    /// its slot proportionally via `phaseProgress`, so the bar stays smooth no
    /// matter how many pages a phase turns out to have.
    var progress: Double {
        guard !chromePhases.isEmpty else { return 0 }
        guard let index = chromePhases.firstIndex(of: step) else {
            return step == .completion ? 1 : 0
        }
        let within: Double
        if let progress = phaseProgress, progress.count > 1 {
            within = Double(progress.page) / Double(progress.count)
        } else {
            within = 0
        }
        return (Double(index) + within) / Double(chromePhases.count)
    }

    /// The phase name shown in the header, with a local page count for multi-page
    /// phases (e.g. "Alarms · 3 of 13").
    var progressLabel: String {
        let title = step.phaseTitle
        if let progress = phaseProgress, progress.count > 1 {
            return "\(title) · \(min(progress.page + 1, progress.count)) of \(progress.count)"
        }
        return title
    }

    // MARK: - Navigation

    var canGoBack: Bool {
        guard let index = activeSteps.firstIndex(of: step) else { return false }
        return index > 0
    }

    func advance() {
        phaseProgress = nil
        guard let index = activeSteps.firstIndex(of: step),
              index + 1 < activeSteps.count
        else {
            finish()
            return
        }
        step = activeSteps[index + 1]
    }

    func goBack() {
        phaseProgress = nil
        guard let index = activeSteps.firstIndex(of: step), index > 0 else { return }
        step = activeSteps[index - 1]
    }

    /// Skip the rest of setup. Marks onboarding complete without seeding alarms
    /// or touching units, leaving any existing configuration untouched.
    func skip() {
        Storage.shared.hasCompletedOnboarding.value = true
        onClose()
    }

    /// Finish setup: seed selected alarms, mark units/onboarding complete, and
    /// kick a refresh so the home screen loads data immediately.
    func finish() {
        persistSeededAlarms()
        Storage.shared.hasConfiguredUnits.value = true
        Storage.shared.hasCompletedOnboarding.value = true
        onClose()
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }

    // MARK: - Alarm seeding

    private func persistSeededAlarms() {
        var alarms = Storage.shared.alarms.value
        let existingTypes = Set(alarms.map(\.type))

        for seed in offeredSeedAlarms where seed.isEnabled {
            // Don't re-add a type the user already configured. The two seeded Low
            // alarms (warning + urgent) are both added on a fresh install because
            // `existingTypes` is sampled once, before any are appended.
            guard !existingTypes.contains(seed.type) else { continue }
            alarms.append(seed.alarm)
        }

        Storage.shared.alarms.value = alarms
    }

    // MARK: - Default seed set

    /// The recommended alarms, in page order. Glucose and phone alarms are offered
    /// to everyone; loop/pump/insulin alarms require Nightscout data.
    private static func defaultSeedAlarms() -> [SeedAlarm] {
        func seed(
            _ type: AlarmType,
            title: String,
            detail: String,
            requiresNightscout: Bool,
            configure: (inout Alarm) -> Void = { _ in }
        ) -> SeedAlarm {
            var alarm = Alarm(type: type)
            configure(&alarm)
            return SeedAlarm(
                alarm: alarm,
                isEnabled: true,
                title: title,
                detail: detail,
                requiresNightscout: requiresNightscout
            )
        }

        return [
            seed(.low, title: "Low glucose",
                 detail: "Warns when glucose is low, now or soon.",
                 requiresNightscout: false)
            {
                $0.name = "Low glucose"
                $0.belowBG = 70
                $0.predictiveMinutes = 20
            },
            seed(.low, title: "Urgent low",
                 detail: "A separate warning for when glucose is very low.",
                 requiresNightscout: false)
            {
                $0.name = "Urgent low"
                $0.belowBG = 54
                $0.predictiveMinutes = 0
                $0.persistentMinutes = 0
            },
            seed(.high, title: "High glucose",
                 detail: "Warns when glucose is high.",
                 requiresNightscout: false)
            {
                $0.aboveBG = 180
            },
            seed(.fastDrop, title: "Fast drop",
                 detail: "Warns when glucose is falling quickly.",
                 requiresNightscout: false),
            seed(.missedReading, title: "Missed readings",
                 detail: "Warns when glucose stops updating.",
                 requiresNightscout: false),
            seed(.notLooping, title: "Not looping",
                 detail: "Warns when the loop stops running.",
                 requiresNightscout: true),
            seed(.battery, title: "Looping phone battery",
                 detail: "Warns when the battery of the phone running Loop or Trio is low.",
                 requiresNightscout: true),
            seed(.iob, title: "IOB",
                 detail: "Warns when insulin on board is high.",
                 requiresNightscout: true),
            seed(.cob, title: "COB",
                 detail: "Warns when carbs on board are high.",
                 requiresNightscout: true),
            seed(.sensorChange, title: "Sensor change",
                 detail: "Reminds you when the CGM sensor is due.",
                 requiresNightscout: true)
            {
                $0.threshold = 10
                $0.activeOption = .day
            },
            seed(.pumpChange, title: "Pump change",
                 detail: "Reminds you when the pump site is due.",
                 requiresNightscout: true)
            {
                $0.threshold = 3
                $0.activeOption = .day
            },
            seed(.pump, title: "Pump insulin",
                 detail: "Warns when pump reservoir insulin is low.",
                 requiresNightscout: true),
        ]
    }
}
