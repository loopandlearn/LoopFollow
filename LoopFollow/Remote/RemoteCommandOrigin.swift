// LoopFollow
// RemoteCommandOrigin.swift

import Foundation
import SwiftUI
import UIKit

/// Where a bolus or carb command was entered.
enum RemoteCommandOrigin: Equatable {
    /// Entered on a command screen of the phone; `screenOpenedWith` is the treatments marker when that screen appeared,
    /// read from `site`.
    case phone(screenOpenedWith: String?, site: MainViewController.TreatmentsSite)
    /// Relayed from Apple Watch, which may show older data than the phone.
    case watch

    /// A phone command screen that is appearing now: it keeps the treatments marker the user sees while deciding.
    static func phoneScreenAppeared() -> RemoteCommandOrigin {
        .phone(screenOpenedWith: Observable.shared.treatmentsKnownThroughID.value, site: .current)
    }

    /// The treatments marker the command carries.
    var knownThroughID: String? {
        knownThroughID(current: Observable.shared.treatmentsKnownThroughID.value, currentSite: .current)
    }

    /// The older of the marker when the screen appeared and `current`, or whichever of them exists. The marker from
    /// when the screen appeared counts only while its site is `currentSite`. Watch commands carry none.
    func knownThroughID(current: String?, currentSite: MainViewController.TreatmentsSite) -> String? {
        switch self {
        case let .phone(screenOpenedWith, site):
            let opened = site == currentSite ? screenOpenedWith : nil
            return [opened, current].compactMap { $0 }.min()
        case .watch:
            return nil
        }
    }
}

extension View {
    /// Keeps `origin` at the treatments marker the user sees on this phone command screen: the marker when the screen
    /// appears, and after a return to the foreground the marker of the first treatments download that follows.
    func remoteCommandOrigin(_ origin: Binding<RemoteCommandOrigin>) -> some View {
        modifier(RemoteCommandOriginTracker(origin: origin))
    }
}

private struct RemoteCommandOriginTracker: ViewModifier {
    @Binding var origin: RemoteCommandOrigin
    @State private var awaitsDownload = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                origin = .phoneScreenAppeared()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                origin = .phoneScreenAppeared()
                awaitsDownload = true
            }
            .onReceive(Observable.shared.treatmentsKnownThroughID.$value.dropFirst()) { marker in
                guard awaitsDownload, let marker else { return }
                origin = .phone(screenOpenedWith: marker, site: .current)
                awaitsDownload = false
            }
    }
}
