// LoopFollow
// OnboardingStep.swift

import Foundation

/// The phases of the first-run onboarding wizard.
///
/// Progress is tracked by phase, not by page: the set of phases is stable, while
/// some phases contain a variable number of internal pages (the Nightscout connect
/// phase can be one or two pages; the alarms phase is one page per offered alarm,
/// which differs between Nightscout and Dexcom). Those phases report their
/// within-phase position through `OnboardingViewModel.phaseProgress`, so the
/// overall progress bar stays smooth no matter how many pages a phase has.
///
/// `connect` renders the Nightscout, Dexcom, or import view depending on the data
/// source the user picks in `dataSource`.
enum OnboardingStep: CaseIterable, Hashable {
    case welcome
    case overview
    case dataSource
    case connect
    case units
    case generalAlarms
    case alarms
    case tabOrder
    case notifications
    case telemetry
    case completion

    /// Steps that show the progress bar + phase label + Skip at the top. The
    /// welcome and completion screens are full-bleed and provide their own CTA.
    var showsProgressHeader: Bool {
        switch self {
        case .welcome, .completion:
            return false
        default:
            return true
        }
    }

    /// Steps that use the shared Back / Continue footer. Phases that contain their
    /// own internal pages or custom primary buttons (connect, units, alarms,
    /// notifications, telemetry) supply their own footer instead, as do the
    /// full-bleed welcome and completion screens.
    var usesSharedFooter: Bool {
        switch self {
        case .overview, .dataSource, .generalAlarms, .tabOrder:
            return true
        default:
            return false
        }
    }

    /// Short name shown in the progress header for this phase.
    var phaseTitle: String {
        switch self {
        case .welcome, .completion: return ""
        case .overview: return "Overview"
        case .dataSource: return "Data source"
        case .connect: return "Connect"
        case .units: return "Units & metrics"
        case .generalAlarms: return "Alarm basics"
        case .alarms: return "Alarms"
        case .tabOrder: return "Tabs"
        case .notifications: return "Notifications"
        case .telemetry: return "Privacy"
        }
    }
}
