// LoopFollow
// HomeContentView.swift

import SwiftUI
import UIKit

/// A SwiftUI wrapper around MainViewController that displays the full Home screen.
/// This can be used both in the tab bar and as a modal from the Menu.
struct HomeContentView: UIViewControllerRepresentable {
    let isModal: Bool

    init(isModal: Bool = false) {
        self.isModal = isModal
    }

    func makeUIViewController(context _: Context) -> UIViewController {
        let mainVC = MainViewController()
        mainVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        mainVC.isPresentedAsModal = isModal
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
        NavigationView {
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
