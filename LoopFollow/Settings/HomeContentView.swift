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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        // Get the MainViewController from storyboard
        guard let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController") as? MainViewController else {
            let fallbackVC = UIViewController()
            fallbackVC.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "Unable to load Home screen"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            fallbackVC.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
            ])
            return fallbackVC
        }

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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
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
