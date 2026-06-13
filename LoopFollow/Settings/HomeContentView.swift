// LoopFollow
// HomeContentView.swift

import SwiftUI
import UIKit

/// A SwiftUI wrapper around MainViewController that displays the full Home screen.
/// This can be used both in the tab bar and as a modal from the Menu.
struct HomeContentView: View {
    let isModal: Bool

    init(isModal: Bool = false) {
        self.isModal = isModal
    }

    var body: some View {
        MainViewControllerRepresentable()
            // Home has no text input, yet iOS sometimes replays a stale keyboard
            // frame when the app returns to the foreground, which squeezes the
            // whole screen up by a keyboard's height until a rotation forces the
            // safe area to recompute. Opting out of keyboard avoidance prevents it.
            .ignoresSafeArea(.keyboard)
    }
}

private struct MainViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> UIViewController {
        // Reuse the single long-lived instance rather than creating a new one,
        // so there is exactly one data pipeline and MainViewController.shared is
        // never displaced. bootstrap() is a no-op if it already exists.
        MainViewController.bootstrap()
        let mainVC = MainViewController.shared!
        // Detach from any previous SwiftUI host (e.g. after a Menu push was
        // popped and is now being re-pushed) before this representable embeds it.
        mainVC.willMove(toParent: nil)
        mainVC.removeFromParent()
        mainVC.view.removeFromSuperview()
        mainVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        return mainVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context _: Context) {
        uiViewController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
    }
}

// MARK: - Modal wrapper with navigation bar

struct HomeModalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HomeContentView(isModal: true)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }
}

// MARK: - Preview

#Preview {
    HomeModalView()
}
